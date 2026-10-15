// ─────────────────────────────────────────────────────────────────────────────
// garba_analyzer.dart
//
// Pure-Dart movement analysis for the AI Garba Trainer.
//
// The camera screen converts every ML Kit pose into a [PoseFrame] (a map of
// joints -> normalised points). This file then:
//   1. extracts body features (clap distance, shoulder turn, hip travel...),
//   2. keeps a ~3 second sliding window,
//   3. DETECTS which Garba step is being danced
//      (Basic, Two Clap, Three Clap, Dodhiya, Hinch, Simple Spin),
//   4. scores the movement against that step's rules (accuracy 0-100),
//   5. returns CORRECTIONS ("Keep your back straight") with the joints that
//      are wrong so the UI can highlight them on the skeleton.
//
// All thresholds are collected in [AnalyzerTuning] so they can be tuned after
// testing on real dancers.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

enum Joint {
  nose,
  lShoulder,
  rShoulder,
  lElbow,
  rElbow,
  lWrist,
  rWrist,
  lHip,
  rHip,
  lKnee,
  rKnee,
  lAnkle,
  rAnkle,
}

class JointPoint {
  final double x;
  final double y;
  final double visibility; // 0..1 (ML Kit "likelihood")
  const JointPoint(this.x, this.y, this.visibility);
}

class PoseFrame {
  final Map<Joint, JointPoint> joints;
  const PoseFrame(this.joints);
}

class PoseIssue {
  /// English key, translated by the UI with context.tr().
  final String message;
  final List<Joint> joints;
  final double severity;
  const PoseIssue(this.message, this.joints, this.severity);
}

class FrameFeedback {
  final bool personVisible;
  final bool bodyVisible;
  final bool moving;
  final String? detectedStep;
  final double confidence;
  final String? scoredStep;
  final double accuracy; // smoothed 0..100
  final List<PoseIssue> issues;
  final List<String> goodPoints;
  final int clapCount;
  final String? wrongStepHint;

  const FrameFeedback({
    required this.personVisible,
    required this.bodyVisible,
    required this.moving,
    required this.detectedStep,
    required this.confidence,
    required this.scoredStep,
    required this.accuracy,
    required this.issues,
    required this.goodPoints,
    required this.clapCount,
    required this.wrongStepHint,
  });

  factory FrameFeedback.none() => const FrameFeedback(
        personVisible: false,
        bodyVisible: false,
        moving: false,
        detectedStep: null,
        confidence: 0,
        scoredStep: null,
        accuracy: 0,
        issues: [],
        goodPoints: [],
        clapCount: 0,
        wrongStepHint: null,
      );
}

/// All magic numbers in one place (lengths are in "torso lengths").
class AnalyzerTuning {
  static const double minVisibility = 0.5;
  static const double windowSeconds = 3.0;
  static const double clapCloseDist = 0.45;
  static const double clapOpenDist = 0.75;
  static const double movingSpeed = 0.35; // torso lengths / second
  static const int stableFramesToSwitch = 3;
  static const int framesToForgetStep = 8;
  static const double minDetectScore = 0.5;
  static const int issueWindow = 8;
  static const int issueNeeded = 5;
}

const String stepBasic = 'Basic Step';
const String stepTwoClap = 'Two Clap';
const String stepThreeClap = 'Three Clap';
const String stepDodhiya = 'Dodhiya';
const String stepHinch = 'Hinch';
const String stepSpin = 'Simple Spin';

class _F {
  final double t;
  final double hipX;
  final double shoulderRatio;
  final double tilt;
  final double lean;
  final double? wristDist;
  final double? wristMidY;
  final double? rise;
  final double? ankleGap;
  final double? lElbow;
  final double? rElbow;
  final double? kneeAvg;
  final double? lwx;
  final double? lwy;
  final double? rwx;
  final double? rwy;

  const _F({
    required this.t,
    required this.hipX,
    required this.shoulderRatio,
    required this.tilt,
    required this.lean,
    this.wristDist,
    this.wristMidY,
    this.rise,
    this.ankleGap,
    this.lElbow,
    this.rElbow,
    this.kneeAvg,
    this.lwx,
    this.lwy,
    this.rwx,
    this.rwy,
  });
}

class _Check {
  final String message;
  final double score;
  final double weight;
  final List<Joint> joints;
  final String? good;
  const _Check(this.message, this.score, this.weight, this.joints, [this.good]);
}

class GarbaStepAnalyzer {
  final List<_F> _window = [];
  final List<double> _clapTimes = [];
  final List<double> _clapHeights = [];
  bool _clapClosed = false;

  String? _candidate;
  int _candidateCount = 0;
  int _noCandidateCount = 0;
  String? _detected;
  double _detectedConf = 0;

  double? _acc;
  final Map<String, List<bool>> _issueHistory = {};
  final Map<String, List<bool>> _goodHistory = {};

  void reset() {
    _window.clear();
    _clapTimes.clear();
    _clapHeights.clear();
    _clapClosed = false;
    _candidate = null;
    _candidateCount = 0;
    _noCandidateCount = 0;
    _detected = null;
    _detectedConf = 0;
    _acc = null;
    _issueHistory.clear();
    _goodHistory.clear();
  }

  // ── helpers ────────────────────────────────────────────────────────────
  static double _lin(double x, double bad, double good) {
    final t = (x - bad) / (good - bad);
    return math.max(0.0, math.min(1.0, t));
  }

  static double _dist(JointPoint a, JointPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _angle(JointPoint a, JointPoint b, JointPoint c) {
    final v1x = a.x - b.x;
    final v1y = a.y - b.y;
    final v2x = c.x - b.x;
    final v2y = c.y - b.y;
    final n1 = math.sqrt(v1x * v1x + v1y * v1y);
    final n2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (n1 < 1e-6 || n2 < 1e-6) return 180;
    var cosv = (v1x * v2x + v1y * v2y) / (n1 * n2);
    cosv = math.max(-1.0, math.min(1.0, cosv));
    return math.acos(cosv) * 180 / math.pi;
  }

  JointPoint? _p(PoseFrame f, Joint j) {
    final p = f.joints[j];
    if (p == null || p.visibility < AnalyzerTuning.minVisibility) return null;
    return p;
  }

  // ── feature extraction ──────────────────────────────────────────────────
  _F? _extract(PoseFrame f, double t) {
    final ls = _p(f, Joint.lShoulder);
    final rs = _p(f, Joint.rShoulder);
    final lh = _p(f, Joint.lHip);
    final rh = _p(f, Joint.rHip);
    if (ls == null || rs == null || lh == null || rh == null) return null;

    final smx = (ls.x + rs.x) / 2;
    final smy = (ls.y + rs.y) / 2;
    final hmx = (lh.x + rh.x) / 2;
    final hmy = (lh.y + rh.y) / 2;
    final torso = math.sqrt((smx - hmx) * (smx - hmx) + (smy - hmy) * (smy - hmy));
    if (torso < 1e-3) return null;

    final shoulderRatio = _dist(ls, rs) / torso;
    final tilt = math.atan2(rs.y - ls.y, rs.x - ls.x) * 180 / math.pi;
    final lean = math.atan2((smx - hmx).abs(), math.max(1e-6, hmy - smy)) *
        180 /
        math.pi;

    final lw = _p(f, Joint.lWrist);
    final rw = _p(f, Joint.rWrist);
    double? wristDist;
    double? wristMidY;
    double? rise;
    double? lwx;
    double? lwy;
    double? rwx;
    double? rwy;
    if (lw != null && rw != null) {
      wristDist = _dist(lw, rw) / torso;
      wristMidY = ((lw.y + rw.y) / 2 - smy) / torso;
      rise = (smy - math.min(lw.y, rw.y)) / torso;
      lwx = (lw.x - smx) / torso;
      lwy = (lw.y - smy) / torso;
      rwx = (rw.x - smx) / torso;
      rwy = (rw.y - smy) / torso;
    }

    final la = _p(f, Joint.lAnkle);
    final ra = _p(f, Joint.rAnkle);
    final ankleGap = (la != null && ra != null) ? (la.x - ra.x).abs() / torso : null;

    final le = _p(f, Joint.lElbow);
    final re = _p(f, Joint.rElbow);
    final lElbow = (le != null && lw != null) ? _angle(ls, le, lw) : null;
    final rElbow = (re != null && rw != null) ? _angle(rs, re, rw) : null;

    final lk = _p(f, Joint.lKnee);
    final rk = _p(f, Joint.rKnee);
    final ka = <double>[];
    if (lk != null && la != null) ka.add(_angle(lh, lk, la));
    if (rk != null && ra != null) ka.add(_angle(rh, rk, ra));
    final kneeAvg = ka.isEmpty ? null : ka.reduce((a, b) => a + b) / ka.length;

    return _F(
      t: t,
      hipX: hmx / torso,
      shoulderRatio: shoulderRatio,
      tilt: tilt,
      lean: lean,
      wristDist: wristDist,
      wristMidY: wristMidY,
      rise: rise,
      ankleGap: ankleGap,
      lElbow: lElbow,
      rElbow: rElbow,
      kneeAvg: kneeAvg,
      lwx: lwx,
      lwy: lwy,
      rwx: rwx,
      rwy: rwy,
    );
  }

  void _updateClaps(_F f) {
    final d = f.wristDist;
    final y = f.wristMidY;
    if (d == null || y == null) return;
    final inFront = y > -0.3 && y < 1.2;
    if (!_clapClosed && d < AnalyzerTuning.clapCloseDist && inFront) {
      _clapClosed = true;
      _clapTimes.add(f.t);
      _clapHeights.add(y);
    } else if (_clapClosed && d > AnalyzerTuning.clapOpenDist) {
      _clapClosed = false;
    }
    while (_clapTimes.isNotEmpty && f.t - _clapTimes.first > 8.0) {
      _clapTimes.removeAt(0);
      _clapHeights.removeAt(0);
    }
  }

  /// 'two', 'three' or null from the last few seconds of claps.
  String? _clapPattern(double now) {
    final ts = _clapTimes.where((c) => now - c <= 7.0).toList();
    if (ts.length < 2) return null;
    final gaps = <double>[];
    for (var i = 1; i < ts.length; i++) {
      gaps.add(ts[i] - ts[i - 1]);
    }
    if (ts.length == 2) return 'two';
    final sorted = List<double>.from(gaps)..sort();
    final median = sorted[sorted.length ~/ 2];
    // Split into groups at "long" gaps.
    final groups = <int>[];
    var cur = 1;
    for (final g in gaps) {
      if (g > 1.6 * median) {
        groups.add(cur);
        cur = 1;
      } else {
        cur++;
      }
    }
    groups.add(cur);
    // Ignore first/last group (they may be cut by the window).
    final inner = groups.length > 2
        ? groups.sublist(1, groups.length - 1)
        : List<int>.from(groups);
    final threes = inner.where((g) => g >= 3).length;
    final twos = inner.where((g) => g == 2).length;
    if (groups.length >= 2 && threes > twos) return 'three';
    return 'two';
  }

  // ── main entry ──────────────────────────────────────────────────────────
  /// [targetStep] null = auto-detect and score whichever step is detected.
  FrameFeedback process(PoseFrame? pose, double nowSeconds, {String? targetStep}) {
    if (pose == null) return FrameFeedback.none();

    final f = _extract(pose, nowSeconds);
    if (f == null) return FrameFeedback.none();

    final bodyVisible = f.kneeAvg != null && f.ankleGap != null;

    _window.add(f);
    while (_window.isNotEmpty &&
        nowSeconds - _window.first.t > AnalyzerTuning.windowSeconds) {
      _window.removeAt(0);
    }
    _updateClaps(f);

    final stats = _stats(nowSeconds);
    final moving = stats.energy > AnalyzerTuning.movingSpeed || stats.recentClaps >= 2;

    // 1) Detect which step is being danced.
    final scores = _detectionScores(stats, moving);
    String? best;
    var bestScore = 0.0;
    scores.forEach((k, v) {
      if (v > bestScore) {
        bestScore = v;
        best = k;
      }
    });
    if (best != null && bestScore >= AnalyzerTuning.minDetectScore) {
      if (best == _candidate) {
        _candidateCount++;
      } else {
        _candidate = best;
        _candidateCount = 1;
      }
      _noCandidateCount = 0;
      if (_candidateCount >= AnalyzerTuning.stableFramesToSwitch) {
        _detected = _candidate;
        _detectedConf = bestScore;
      }
    } else {
      _noCandidateCount++;
      _candidate = null;
      _candidateCount = 0;
      if (_noCandidateCount >= AnalyzerTuning.framesToForgetStep) {
        _detected = null;
        _detectedConf = 0;
      }
    }

    // 2) Which step do we score against?
    final scored = targetStep ?? _detected;

    String? wrongHint;
    if (targetStep != null &&
        _detected != null &&
        _detected != targetStep &&
        _detectedConf >= 0.7) {
      wrongHint = _detected;
    }

    if (scored == null) {
      return FrameFeedback(
        personVisible: true,
        bodyVisible: bodyVisible,
        moving: moving,
        detectedStep: _detected,
        confidence: _detectedConf,
        scoredStep: null,
        accuracy: _acc ?? 0,
        issues: bodyVisible
            ? const []
            : const [
                PoseIssue('Step back so your full body is visible', [], 0.5)
              ],
        goodPoints: const [],
        clapCount: stats.recentClaps,
        wrongStepHint: null,
      );
    }

    // 3) Score the movement against the step's rules.
    final checks = _checksFor(scored, stats, bodyVisible);
    var wSum = 0.0;
    var sSum = 0.0;
    for (final c in checks) {
      wSum += c.weight;
      sSum += c.weight * c.score;
    }
    final raw = wSum <= 0 ? 0.0 : (sSum / wSum) * 100;
    _acc = _acc == null ? raw : (_acc! * 0.7 + raw * 0.3);

    // 4) Stable corrections (flag must persist over several frames).
    final issues = <PoseIssue>[];
    final good = <String>[];
    final seenKeys = <String>{};
    for (final c in checks) {
      seenKeys.add(c.message);
      final failing = c.score < 0.6;
      final hist = _issueHistory.putIfAbsent(c.message, () => <bool>[]);
      hist.add(failing);
      if (hist.length > AnalyzerTuning.issueWindow) hist.removeAt(0);
      final failCount = hist.where((b) => b).length;
      if (failCount >= AnalyzerTuning.issueNeeded) {
        issues.add(PoseIssue(c.message, c.joints, (1 - c.score) * c.weight));
      }
      if (c.good != null) {
        final gh = _goodHistory.putIfAbsent(c.good!, () => <bool>[]);
        gh.add(c.score >= 0.85);
        if (gh.length > AnalyzerTuning.issueWindow) gh.removeAt(0);
        if (gh.length >= 5 && gh.where((b) => b).length >= 5) good.add(c.good!);
      }
    }
    _issueHistory.removeWhere((k, v) => !seenKeys.contains(k));
    issues.sort((a, b) => b.severity.compareTo(a.severity));

    return FrameFeedback(
      personVisible: true,
      bodyVisible: bodyVisible,
      moving: moving,
      detectedStep: _detected,
      confidence: _detectedConf,
      scoredStep: scored,
      accuracy: (_acc ?? 0).clamp(0.0, 100.0).toDouble(),
      issues: issues.take(3).toList(),
      goodPoints: good.take(2).toList(),
      clapCount: stats.recentClaps,
      wrongStepHint: wrongHint,
    );
  }

  // ── window statistics ───────────────────────────────────────────────────
  _Stats _stats(double now) {
    final w = _window;
    final s = _Stats();
    if (w.length < 2) return s;

    double minHip = w.first.hipX, maxHip = w.first.hipX;
    double minR = w.first.shoulderRatio, maxR = w.first.shoulderRatio;
    double minTilt = w.first.tilt, maxTilt = w.first.tilt;
    double maxRise = -9;
    double riseSum = 0;
    int riseN = 0;
    double maxWristDist = 0;
    double midYSum = 0;
    int midYN = 0;
    double minGap = 99, maxGap = -1;
    double leanSum = 0;
    double kneeSum = 0;
    int kneeN = 0;
    double elbowDiffSum = 0;
    int elbowN = 0;
    double speedSum = 0;
    int speedN = 0;

    for (var i = 0; i < w.length; i++) {
      final f = w[i];
      minHip = math.min(minHip, f.hipX);
      maxHip = math.max(maxHip, f.hipX);
      minR = math.min(minR, f.shoulderRatio);
      maxR = math.max(maxR, f.shoulderRatio);
      minTilt = math.min(minTilt, f.tilt);
      maxTilt = math.max(maxTilt, f.tilt);
      leanSum += f.lean;
      if (f.rise != null) {
        maxRise = math.max(maxRise, f.rise!);
        riseSum += f.rise!;
        riseN++;
      }
      if (f.wristDist != null) maxWristDist = math.max(maxWristDist, f.wristDist!);
      if (f.wristMidY != null) {
        midYSum += f.wristMidY!;
        midYN++;
      }
      if (f.ankleGap != null) {
        minGap = math.min(minGap, f.ankleGap!);
        maxGap = math.max(maxGap, f.ankleGap!);
      }
      if (f.kneeAvg != null) {
        kneeSum += f.kneeAvg!;
        kneeN++;
      }
      if (f.lElbow != null && f.rElbow != null) {
        elbowDiffSum += (f.lElbow! - f.rElbow!).abs();
        elbowN++;
      }
      if (i > 0) {
        final p = w[i - 1];
        final dt = f.t - p.t;
        if (dt > 0.001 && dt < 0.6) {
          double d = (f.hipX - p.hipX).abs();
          if (f.lwx != null && p.lwx != null) {
            d += math.sqrt(math.pow(f.lwx! - p.lwx!, 2) + math.pow(f.lwy! - p.lwy!, 2));
            d += math.sqrt(math.pow(f.rwx! - p.rwx!, 2) + math.pow(f.rwy! - p.rwy!, 2));
          }
          speedSum += d / dt;
          speedN++;
        }
      }
    }

    // Tilt swings: direction reversals larger than 4 degrees.
    var swings = 0;
    if (w.length > 3) {
      var dir = 0;
      var extreme = w.first.tilt;
      for (final f in w) {
        final delta = f.tilt - extreme;
        if (dir >= 0 && delta < -4) {
          if (dir == 1) swings++;
          dir = -1;
          extreme = f.tilt;
        } else if (dir <= 0 && delta > 4) {
          if (dir == -1) swings++;
          dir = 1;
          extreme = f.tilt;
        } else if ((dir == 1 && f.tilt > extreme) || (dir == -1 && f.tilt < extreme)) {
          extreme = f.tilt;
        }
      }
    }

    s.hipRange = maxHip - minHip;
    s.ratioRange = maxR - minR;
    s.ratioMax = maxR;
    s.tiltRange = maxTilt - minTilt;
    s.tiltSwings = swings;
    s.maxRise = riseN == 0 ? 0 : maxRise;
    s.avgRise = riseN == 0 ? 0 : riseSum / riseN;
    s.maxWristDist = maxWristDist;
    s.avgWristMidY = midYN == 0 ? 0.5 : midYSum / midYN;
    s.ankleRange = maxGap < 0 ? null : (maxGap - minGap);
    s.avgLean = leanSum / w.length;
    s.avgKnee = kneeN == 0 ? null : kneeSum / kneeN;
    s.elbowDiff = elbowN == 0 ? 0 : elbowDiffSum / elbowN;
    s.energy = speedN == 0 ? 0 : speedSum / speedN;
    s.recentClaps = _clapTimes.where((c) => now - c <= 3.5).length;
    s.pattern = _clapPattern(now);
    s.clapHeight = _clapHeights.isEmpty
        ? null
        : _clapHeights.sublist(math.max(0, _clapHeights.length - 3)).reduce((a, b) => a + b) /
            math.min(3, _clapHeights.length);
    s.clapCv = _clapCv(now);
    return s;
  }

  double? _clapCv(double now) {
    final ts = _clapTimes.where((c) => now - c <= 6.0).toList();
    if (ts.length < 3) return null;
    final gaps = <double>[];
    for (var i = 1; i < ts.length; i++) {
      gaps.add(ts[i] - ts[i - 1]);
    }
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean <= 0) return null;
    var v = 0.0;
    for (final g in gaps) {
      v += (g - mean) * (g - mean);
    }
    final std = math.sqrt(v / gaps.length);
    return std / mean;
  }

  // ── step detection ──────────────────────────────────────────────────────
  Map<String, double> _detectionScores(_Stats s, bool moving) {
    final out = <String, double>{};

    // Claps
    if (s.recentClaps >= 2) {
      if (s.pattern == 'three') {
        out[stepThreeClap] = 0.9;
        out[stepTwoClap] = 0.2;
      } else {
        out[stepTwoClap] = math.min(1.0, 0.55 + 0.15 * s.recentClaps);
        out[stepThreeClap] = 0.15;
      }
    }

    // Spin: shoulders turn away from / back to the camera.
    if (s.recentClaps < 2 && s.hipRange < 0.8) {
      out[stepSpin] = _lin(s.ratioRange, 0.15, 0.45) * _lin(s.ratioMax, 0.3, 0.55);
    }

    // Dodhiya: sideways travel with arms lifted.
    if (s.recentClaps < 2) {
      out[stepDodhiya] =
          _lin(s.hipRange, 0.25, 0.7) * _lin(s.maxRise, 0.0, 0.4);
    }

    // Hinch: hip sway + alternating shoulders, hands low.
    if (s.recentClaps < 2) {
      final swayOk = s.hipRange >= 0.1 && s.hipRange <= 0.9;
      final swing = s.tiltSwings >= 2 ? 1.0 : 0.5;
      out[stepHinch] = swayOk
          ? _lin(s.tiltRange, 4, 14) *
              _lin(s.hipRange, 0.08, 0.25) *
              swing *
              (s.avgRise < 0.3 ? 1.0 : 0.5)
          : 0.0;
    }

    // Basic step: general rhythmic movement not matching anything stronger.
    if (moving && s.recentClaps < 2) {
      out[stepBasic] = 0.5 * _lin(s.energy, 0.3, 0.9) + 0.05;
    }

    return out;
  }

  // ── rules per step ──────────────────────────────────────────────────────
  List<_Check> _checksFor(String step, _Stats s, bool bodyVisible) {
    final checks = <_Check>[];

    // Common: upright back.
    checks.add(_Check(
      'Keep your back straight',
      _lin(s.avgLean, 25, 8),
      1.0,
      const [Joint.lShoulder, Joint.rShoulder, Joint.lHip, Joint.rHip],
      'Great posture',
    ));

    // Common: soft knees.
    if (s.avgKnee != null) {
      final straight = _lin(s.avgKnee!, 178, 168);
      final deep = _lin(s.avgKnee!, 100, 125);
      if (deep < straight) {
        checks.add(_Check(
          'Do not bend your knees so deep',
          deep,
          0.8,
          const [Joint.lKnee, Joint.rKnee],
        ));
      } else {
        checks.add(_Check(
          'Soften your knees with a slight bend',
          straight,
          0.8,
          const [Joint.lKnee, Joint.rKnee],
          'Nice knee bend',
        ));
      }
    } else if (!bodyVisible) {
      checks.add(const _Check(
        'Step back so your full body is visible',
        0.5,
        0.4,
        [],
      ));
    }

    const arms = [Joint.lElbow, Joint.rElbow, Joint.lWrist, Joint.rWrist];

    switch (step) {
      case stepTwoClap:
        checks.addAll(_clapChecks(s, arms, three: false));
        break;
      case stepThreeClap:
        checks.addAll(_clapChecks(s, arms, three: true));
        break;
      case stepDodhiya:
        checks.add(_Check(
          'Travel more sideways with each beat',
          _lin(s.hipRange, 0.15, 0.5),
          1.3,
          const [Joint.lHip, Joint.rHip, Joint.lAnkle, Joint.rAnkle],
          'Good sideways movement',
        ));
        checks.add(_Check(
          'Lift your arms to shoulder height in a smooth arc',
          _lin(s.maxRise, 0.0, 0.35),
          1.2,
          arms,
          'Graceful arm arcs',
        ));
        break;
      case stepHinch:
        final sway = s.hipRange > 0.8
            ? _lin(s.hipRange, 1.2, 0.8)
            : _lin(s.hipRange, 0.05, 0.2);
        checks.add(_Check(
          s.hipRange > 0.8
              ? 'Reduce the sway, keep it gentle'
              : 'Sway your hips gently from side to side',
          sway,
          1.3,
          const [Joint.lHip, Joint.rHip],
          'Smooth hip sway',
        ));
        checks.add(_Check(
          'Alternate your shoulders with the sway',
          _lin(s.tiltRange, 3, 12),
          1.2,
          const [Joint.lShoulder, Joint.rShoulder],
          'Good shoulder movement',
        ));
        checks.add(_Check(
          'Keep your hands relaxed and low',
          _lin(s.avgRise, 0.7, 0.3),
          0.6,
          arms,
        ));
        break;
      case stepSpin:
        checks.add(_Check(
          'Turn your whole body in a full circle',
          _lin(s.ratioRange, 0.1, 0.4),
          1.5,
          const [Joint.lShoulder, Joint.rShoulder, Joint.lHip, Joint.rHip],
          'Full, even turn',
        ));
        checks.add(_Check(
          'Hold your arms out at shoulder height',
          _lin((s.avgWristMidY - 0.1).abs(), 0.9, 0.35),
          0.8,
          arms,
          'Arms held well',
        ));
        checks.add(_Check(
          'Keep both arms moving together',
          _lin(s.elbowDiff, 55, 20),
          0.6,
          arms,
        ));
        break;
      case stepBasic:
      default:
        final footScore = s.ankleRange != null
            ? _lin(s.ankleRange!, 0.08, 0.4)
            : _lin(s.hipRange, 0.04, 0.25);
        checks.add(_Check(
          'Step left, right, centre with your feet',
          footScore,
          1.2,
          const [Joint.lKnee, Joint.rKnee, Joint.lAnkle, Joint.rAnkle],
          'Steady footwork',
        ));
        final inRange = s.avgWristMidY >= 0.0 && s.avgWristMidY <= 0.9;
        checks.add(_Check(
          'Keep your hands up near your chest with a gentle elbow bend',
          inRange
              ? 1.0
              : (s.avgWristMidY < 0.0
                  ? _lin(s.avgWristMidY, -0.6, 0.0)
                  : _lin(s.avgWristMidY, 1.5, 0.9)),
          0.9,
          arms,
          'Good hand position',
        ));
        break;
    }

    return checks;
  }

  List<_Check> _clapChecks(_Stats s, List<Joint> arms, {required bool three}) {
    final out = <_Check>[];
    if (three) {
      final pat = s.pattern;
      final score = pat == 'three' ? 1.0 : (pat == 'two' ? 0.35 : (s.recentClaps >= 1 ? 0.2 : 0.0));
      out.add(_Check(
        'Make it three claps: out, in, out',
        score,
        1.5,
        arms,
        'Clean three-clap pattern',
      ));
    } else {
      final n = s.recentClaps;
      final score = n >= 3 ? 1.0 : (n == 2 ? 0.8 : (n == 1 ? 0.35 : 0.0));
      out.add(_Check(
        'Clap on the beat and keep clapping steadily',
        score,
        1.5,
        arms,
        'Good clapping rhythm',
      ));
    }

    final h = s.clapHeight;
    if (h != null) {
      double sc;
      String msg;
      if (h < 0.05) {
        sc = _lin(h, -0.4, 0.05);
        msg = 'Clap at chest height, not above your shoulders';
      } else if (h > 0.7) {
        sc = _lin(h, 1.2, 0.7);
        msg = 'Bring your hands up to chest height';
      } else {
        sc = 1.0;
        msg = 'Clap at chest height, not above your shoulders';
      }
      out.add(_Check(msg, sc, 1.0, arms, 'Claps at chest height'));
    }

    if (s.clapCv != null) {
      out.add(_Check(
        'Keep a steady rhythm',
        three ? 0.8 : _lin(s.clapCv!, 0.55, 0.2),
        three ? 0.2 : 1.0,
        arms,
        'Steady rhythm',
      ));
    }

    out.add(_Check(
      three
          ? 'Swing your arms out wide between claps'
          : 'Open your arms wider between claps',
      _lin(s.maxWristDist, three ? 0.6 : 0.5, three ? 1.3 : 1.1),
      0.8,
      arms,
      'Arms opening nicely',
    ));

    out.add(_Check(
      'Keep both arms moving together',
      _lin(s.elbowDiff, 55, 20),
      0.7,
      arms,
    ));
    return out;
  }
}

class _Stats {
  double hipRange = 0;
  double ratioRange = 0;
  double ratioMax = 0;
  double tiltRange = 0;
  int tiltSwings = 0;
  double maxRise = 0;
  double avgRise = 0;
  double maxWristDist = 0;
  double avgWristMidY = 0.5;
  double? ankleRange;
  double avgLean = 0;
  double? avgKnee;
  double elbowDiff = 0;
  double energy = 0;
  int recentClaps = 0;
  String? pattern;
  double? clapHeight;
  double? clapCv;
}
