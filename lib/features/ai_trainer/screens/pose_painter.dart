import 'package:flutter/material.dart';

import '../engine/garba_analyzer.dart';

/// Draws the detected skeleton over the camera preview. Joints that belong to
/// an active correction are drawn red so the dancer sees WHAT to fix.
class PosePainter extends CustomPainter {
  final Map<Joint, Offset> points; // normalised 0..1 (already mirrored)
  final Set<Joint> problems;
  final Color okColor;

  PosePainter({
    required this.points,
    required this.problems,
    required this.okColor,
  });

  static const _bones = <List<Joint>>[
    [Joint.lShoulder, Joint.rShoulder],
    [Joint.lShoulder, Joint.lElbow],
    [Joint.lElbow, Joint.lWrist],
    [Joint.rShoulder, Joint.rElbow],
    [Joint.rElbow, Joint.rWrist],
    [Joint.lShoulder, Joint.lHip],
    [Joint.rShoulder, Joint.rHip],
    [Joint.lHip, Joint.rHip],
    [Joint.lHip, Joint.lKnee],
    [Joint.lKnee, Joint.lAnkle],
    [Joint.rHip, Joint.rKnee],
    [Joint.rKnee, Joint.rAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Joint j) =>
        Offset(points[j]!.dx * size.width, points[j]!.dy * size.height);

    for (final b in _bones) {
      if (!points.containsKey(b[0]) || !points.containsKey(b[1])) continue;
      final bad = problems.contains(b[0]) && problems.contains(b[1]);
      final paint = Paint()
        ..color = bad ? Colors.redAccent : okColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(at(b[0]), at(b[1]), paint);
    }
    for (final e in points.entries) {
      final bad = problems.contains(e.key);
      canvas.drawCircle(
        Offset(e.value.dx * size.width, e.value.dy * size.height),
        bad ? 9 : 5,
        Paint()..color = bad ? Colors.redAccent : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter old) => true;
}
