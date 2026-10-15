import 'dart:io';

import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stats/providers/stats_provider.dart';
import '../engine/garba_analyzer.dart';
import 'pose_painter.dart';

const String kAutoStep = 'Auto-detect';

final selectedStepProvider = StateProvider<String>((ref) => kAutoStep);

class _Agg {
  double seconds = 0;
  double accSum = 0;
  final Map<String, int> mistakes = {};
}

class AiTrainerScreen extends ConsumerStatefulWidget {
  const AiTrainerScreen({super.key});

  @override
  ConsumerState<AiTrainerScreen> createState() => _AiTrainerScreenState();
}

class _AiTrainerScreenState extends ConsumerState<AiTrainerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProviderContainer _container;

  CameraController? _camera;
  CameraDescription? _cameraDesc;
  PoseDetector? _detector;
  final GarbaStepAnalyzer _analyzer = GarbaStepAnalyzer();

  bool _running = false;
  bool _starting = false;
  bool _busy = false;
  int _lastProcessMs = 0;
  String? _cameraError;

  FrameFeedback _feedback = FrameFeedback.none();
  Map<Joint, Offset> _paintPoints = {};
  final List<double> _history = [];
  final Map<String, _Agg> _aggs = {};
  Stopwatch _clock = Stopwatch();
  double _lastT = 0;
  UserModel? _user;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_running) {
      // Save what was practised even if the user just left the screen.
      _finishSession(showSummary: false);
    } else {
      _releaseCamera();
    }
    super.dispose();
  }

  // ── camera ──────────────────────────────────────────────────────────────
  Future<void> _start() async {
    if (_starting || _running) return;
    setState(() {
      _starting = true;
      _cameraError = null;
    });
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission is needed for the AI Trainer.');
      }
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('No camera found on this device.');
      final desc = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        desc,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();

      _user = ref.read(currentUserProvider);
      _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );
      _analyzer.reset();
      _aggs.clear();
      _history.clear();
      _feedback = FrameFeedback.none();
      _paintPoints = {};
      _clock = Stopwatch()..start();
      _lastT = 0;
      _camera = ctrl;
      _cameraDesc = desc;
      _running = true;
      await ctrl.startImageStream(_onFrame);
      if (mounted) setState(() => _starting = false);
    } catch (e) {
      await _releaseCamera();
      _running = false;
      if (mounted) {
        setState(() {
          _starting = false;
          _cameraError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _releaseCamera() async {
    final cam = _camera;
    final det = _detector;
    _camera = null;
    _detector = null;
    try {
      if (cam != null && cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}
    try {
      await cam?.dispose();
    } catch (_) {}
    try {
      await det?.close();
    } catch (_) {}
  }

  InputImage? _toInputImage(CameraImage image) {
    final cam = _cameraDesc;
    final ctrl = _camera;
    if (cam == null || ctrl == null) return null;

    final sensor = cam.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _orientations[ctrl.value.deviceOrientation];
      if (comp == null) return null;
      if (cam.lensDirection == CameraLensDirection.front) {
        comp = (sensor + comp) % 360;
      } else {
        comp = (sensor - comp + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_running || _busy || _detector == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastProcessMs < 70) return;
    _lastProcessMs = nowMs;
    _busy = true;

    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await _detector!.processImage(input);
      if (!mounted || !_running) return;

      final rot = input.metadata!.rotation;
      final swap = rot == InputImageRotation.rotation90deg ||
          rot == InputImageRotation.rotation270deg;
      final w = swap ? image.height.toDouble() : image.width.toDouble();
      final h = swap ? image.width.toDouble() : image.height.toDouble();
      final mirror = _cameraDesc?.lensDirection == CameraLensDirection.front;

      PoseFrame? frame;
      final pts = <Joint, Offset>{};
      if (poses.isNotEmpty) {
        final lm = poses.first.landmarks;
        const mapping = {
          Joint.nose: PoseLandmarkType.nose,
          Joint.lShoulder: PoseLandmarkType.leftShoulder,
          Joint.rShoulder: PoseLandmarkType.rightShoulder,
          Joint.lElbow: PoseLandmarkType.leftElbow,
          Joint.rElbow: PoseLandmarkType.rightElbow,
          Joint.lWrist: PoseLandmarkType.leftWrist,
          Joint.rWrist: PoseLandmarkType.rightWrist,
          Joint.lHip: PoseLandmarkType.leftHip,
          Joint.rHip: PoseLandmarkType.rightHip,
          Joint.lKnee: PoseLandmarkType.leftKnee,
          Joint.rKnee: PoseLandmarkType.rightKnee,
          Joint.lAnkle: PoseLandmarkType.leftAnkle,
          Joint.rAnkle: PoseLandmarkType.rightAnkle,
        };
        final joints = <Joint, JointPoint>{};
        mapping.forEach((j, type) {
          final l = lm[type];
          if (l == null) return;
          joints[j] = JointPoint(l.x, l.y, l.likelihood);
          if (l.likelihood >= AnalyzerTuning.minVisibility) {
            final nx = (l.x / w).clamp(0.0, 1.0).toDouble();
            final ny = (l.y / h).clamp(0.0, 1.0).toDouble();
            pts[j] = Offset(mirror ? 1 - nx : nx, ny);
          }
        });
        frame = PoseFrame(joints);
      }

      final t = _clock.elapsedMilliseconds / 1000.0;
      final selected = ref.read(selectedStepProvider);
      final fb = _analyzer.process(frame, t,
          targetStep: selected == kAutoStep ? null : selected);

      // Record for the session report.
      final dt = (t - _lastT).clamp(0.0, 0.5).toDouble();
      _lastT = t;
      if (fb.scoredStep != null && fb.moving) {
        final agg = _aggs.putIfAbsent(fb.scoredStep!, () => _Agg());
        agg.seconds += dt;
        agg.accSum += fb.accuracy * dt;
        for (final i in fb.issues) {
          agg.mistakes[i.message] = (agg.mistakes[i.message] ?? 0) + 1;
        }
      }

      setState(() {
        _feedback = fb;
        _paintPoints = pts;
        if (fb.scoredStep != null && fb.moving) {
          _history.add(fb.accuracy);
          if (_history.length > 30) _history.removeAt(0);
        }
      });
    } catch (e) {
      debugPrint('Pose analysis error: $e');
    } finally {
      _busy = false;
    }
  }

  // ── session end ─────────────────────────────────────────────────────────
  Future<void> _stop() => _finishSession(showSummary: true);

  Future<void> _finishSession({required bool showSummary}) async {
    if (!_running) return;
    _running = false;
    final user = _user;
    final aggs = Map<String, _Agg>.from(_aggs);
    final container = _container;
    await _releaseCamera();
    if (mounted) {
      setState(() {
        _feedback = FrameFeedback.none();
        _paintPoints = {};
      });
    }

    final sessionId = const Uuid().v4();
    final now = DateTime.now();
    final records = <PracticeRecord>[];
    aggs.forEach((step, a) {
      if (a.seconds < 5) return; // too short to be meaningful
      final acc = (a.accSum / a.seconds).clamp(0.0, 100.0).toDouble();
      final score = acc * (a.seconds > 180 ? 180 : a.seconds) / 180;
      final top = a.mistakes.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      records.add(PracticeRecord(
        id: const Uuid().v4(),
        sessionId: sessionId,
        userId: user?.id ?? '',
        stepName: step,
        accuracy: acc,
        score: score,
        grade: gradeForAccuracy(acc),
        durationSec: a.seconds.round(),
        mistakes: top.take(3).map((e) => e.key).toList(),
        suggestions: _suggestionsFor(step, acc),
        createdAt: now,
      ));
    });

    if (records.isEmpty || user == null) {
      if (showSummary && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Practise a little longer (at least 5 seconds of movement) to save a session.')),
        ));
      }
      return;
    }

    String? saveError;
    try {
      await FirebaseService.instance
          .savePracticeSession(user: user, records: records);
      container.read(practiceVersionProvider.notifier).state++;
    } catch (e) {
      saveError = e.toString().replaceFirst('Exception: ', '');
    }

    if (showSummary && mounted) {
      _showSummary(records, saveError);
    }
  }

  List<String> _suggestionsFor(String step, double acc) {
    final tips = <String>[];
    if (acc >= 85) {
      tips.add('Excellent control! Try a faster tempo next time.');
    } else if (acc < 60) {
      tips.add('Slow down and practise this step in front of a mirror first.');
    } else {
      tips.add('Good progress. Focus on the corrections to reach 85%.');
    }
    return tips;
  }

  void _showSummary(List<PracticeRecord> records, String? error) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Session Complete'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                error == null
                    ? context.tr('Saved to your profile')
                    : error,
                style: TextStyle(
                    color: error == null ? AppColors.success : AppColors.error,
                    fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...records.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr(r.stepName),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            Text(
                                '${r.accuracy.toStringAsFixed(0)}%  •  ${r.grade}',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...r.mistakes.map((m) => Text('• ${context.tr(m)}',
                            style: const TextStyle(fontSize: 13))),
                        if (r.mistakes.isEmpty)
                          Text(context.tr('No major mistakes. Great job!'),
                              style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(AppRoutes.reports);
                      },
                      child: Text(context.tr('Performance Reports')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('Done')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('AI Garba Trainer')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
                text: context.tr('Live'),
                icon: const Icon(Icons.videocam_outlined, size: 18)),
            Tab(
                text: context.tr('Steps'),
                icon: const Icon(Icons.format_list_bulleted, size: 18)),
            Tab(
                text: context.tr('Progress'),
                icon: const Icon(Icons.insights, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLive(context),
          _GarbaStepsTab(onPractice: (step) {
            ref.read(selectedStepProvider.notifier).state = step;
            _tabController.animateTo(0);
          }),
          const _ProgressTab(),
        ],
      ),
    );
  }

  Color _accColor(double a) => a >= 85
      ? AppColors.success
      : a >= 65
          ? AppColors.warning
          : AppColors.error;

  Widget _buildCameraBox(BuildContext context) {
    final ctrl = _camera;
    final live = _running && ctrl != null && ctrl.value.isInitialized;
    final fb = _feedback;

    return Container(
      height: 380,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: live ? AppColors.success : Colors.grey.shade800,
          width: 2,
        ),
      ),
      child: live
          ? Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ctrl!.value.previewSize!.height,
                    height: ctrl.value.previewSize!.width,
                    child: CameraPreview(ctrl),
                  ),
                ),
                CustomPaint(
                  painter: PosePainter(
                    points: _paintPoints,
                    problems: {for (final i in fb.issues) ...i.joints},
                    okColor: _accColor(fb.accuracy),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (fb.scoredStep != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(context.tr(fb.scoredStep!),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (fb.scoredStep != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${fb.accuracy.toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: _accColor(fb.accuracy),
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _statusBanner(context, fb),
                ),
              ],
            )
          : Center(
              child: _starting
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_outlined,
                            size: 56, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(context.tr('Camera not active'),
                            style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('Press Start to begin AI analysis'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _statusBanner(BuildContext context, FrameFeedback fb) {
    String text;
    Color color;
    if (!fb.personVisible) {
      text = context.tr('Stand back so your whole body is in the frame');
      color = Colors.orange;
    } else if (fb.wrongStepHint != null) {
      text =
          '${context.tr('This looks like')} ${context.tr(fb.wrongStepHint!)}';
      color = Colors.orange;
    } else if (fb.issues.isNotEmpty) {
      text = context.tr(fb.issues.first.message);
      color = Colors.redAccent;
    } else if (fb.scoredStep == null) {
      text = fb.moving
          ? context.tr('Detecting your step...')
          : context.tr('Start dancing — I will detect your step');
      color = Colors.blueGrey;
    } else if (!fb.moving) {
      text = context.tr('Keep moving to the beat');
      color = Colors.blueGrey;
    } else {
      text = fb.goodPoints.isNotEmpty
          ? context.tr(fb.goodPoints.first)
          : context.tr('Looking good, keep going!');
      color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildLive(BuildContext context) {
    final selected = ref.watch(selectedStepProvider);
    final fb = _feedback;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCameraBox(context),
          if (_cameraError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr(_cameraError!))),
                  if (_cameraError!.contains('permission'))
                    TextButton(
                      onPressed: openAppSettings,
                      child: Text(context.tr('Settings')),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected,
            decoration:
                InputDecoration(labelText: context.tr('Select Garba Step')),
            items: [kAutoStep, ...AppConstants.garbaSteps]
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(context.tr(s))))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              ref.read(selectedStepProvider.notifier).state = v;
              _analyzer.reset();
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _starting ? null : (_running ? _stop : _start),
              icon: Icon(_running ? Icons.stop_circle : Icons.play_circle_fill),
              label: Text(_running
                  ? context.tr('Stop & Save Session')
                  : context.tr('Start Live Analysis')),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _running ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_running && fb.scoredStep != null) ...[
            CircularPercentIndicator(
              radius: 70,
              lineWidth: 10,
              percent: (fb.accuracy / 100).clamp(0.0, 1.0).toDouble(),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${fb.accuracy.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(context.tr('Accuracy'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              progressColor: _accColor(fb.accuracy),
              backgroundColor: Colors.grey.shade200,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetricCard(
                    label: context.tr('Grade'),
                    value: gradeForAccuracy(fb.accuracy)),
                _MetricCard(
                    label: context.tr('Step'),
                    value: context.tr(fb.scoredStep!).split(' ').first),
                _MetricCard(label: context.tr('Claps'), value: '${fb.clapCount}'),
              ],
            ),
            const SizedBox(height: 20),
            if (_history.length > 2) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(context.tr('Accuracy Over Time'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < _history.length; i++)
                            FlSpot(i.toDouble(), _history[i]),
                        ],
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.15)),
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (fb.issues.isNotEmpty)
              _InfoBox(
                color: AppColors.error,
                icon: Icons.warning_amber_rounded,
                title: context.tr('Corrections Needed'),
                lines: fb.issues.map((i) => context.tr(i.message)).toList(),
              ),
            if (fb.issues.isNotEmpty) const SizedBox(height: 12),
            if (fb.goodPoints.isNotEmpty)
              _InfoBox(
                color: AppColors.success,
                icon: Icons.tips_and_updates,
                title: context.tr('Doing well'),
                lines: fb.goodPoints.map((g) => context.tr(g)).toList(),
              ),
          ],
          if (!_running)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.tr('Place your phone about 2-3 metres away so your whole body is visible, then start dancing.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;
  const _InfoBox({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: color, size: 16),
                    Expanded(
                        child: Text(l, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Steps tab ───────────────────────────────────────────────────────────────
class _GarbaStepsTab extends StatelessWidget {
  final void Function(String step) onPractice;
  const _GarbaStepsTab({required this.onPractice});

  static const _stepDescriptions = {
    'Basic Step':
        'The foundational Garba step — a simple left-right-center movement with light hand gestures.',
    'Two Clap':
        'A two-count clap pattern synchronized with footwork. Clap on beats 1 and 3.',
    'Three Clap':
        'Three claps in a circular motion. Arms swing out-in-out with each clap.',
    'Dodhiya':
        'A popular Gujarati folk step with rhythmic sideways movement and graceful arm arcs.',
    'Hinch':
        'Involves a hip-sway with alternating shoulder movements creating a wave-like effect.',
    'Simple Spin':
        'A full clockwise spin on the count of 8, maintaining posture and balance.',
  };

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: AppConstants.garbaSteps.length,
      itemBuilder: (_, i) {
        final step = AppConstants.garbaSteps[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(context.tr(step),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr(_stepDescriptions[step] ?? ''),
                        style:
                            const TextStyle(color: Colors.grey, height: 1.6)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => onPractice(step),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(context.tr('Practice This Step')),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: (i * 50).ms).fade().slideY(begin: 0.15);
      },
    );
  }
}

// ─── Progress tab (real data) ────────────────────────────────────────────────
class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (stats) {
        if (stats.records.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr('No practice sessions yet'),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.festiveGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(context.tr('Overall Performance'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('${stats.avgAccuracy.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold)),
                    Text('${context.tr('Grade')}: ${stats.overallGrade}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr('Performance by Step'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...AppConstants.garbaSteps.map((step) {
                final avg = stats.avgByStep[step] ?? 0;
                final has = (stats.countByStep[step] ?? 0) > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr(step),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                              has
                                  ? '${avg.toStringAsFixed(0)}%'
                                  : context.tr('Not practised yet'),
                              style: TextStyle(
                                  color: has ? AppColors.primary : Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (avg / 100).clamp(0.0, 1.0).toDouble(),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(avg >= 85
                            ? AppColors.success
                            : avg >= 65
                                ? AppColors.warning
                                : AppColors.error),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.secondary, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(context.tr('Practice Streak'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Text('🔥 ${stats.streakDays}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.reports),
                icon: const Icon(Icons.insights_outlined),
                label: Text(context.tr('Performance Reports')),
              ),
            ],
          ),
        );
      },
    );
  }
}
