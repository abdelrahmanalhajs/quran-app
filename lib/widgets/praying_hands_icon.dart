import 'package:flutter/material.dart';

/// Two palms pressed together, fingers up — the 🤲/🙏 praying-hands posture
/// used for Athkar throughout the app (main nav, the in-reader nav bar, and
/// the onboarding walkthrough). Drawn as a plain outline rather than using
/// the emoji glyph, which renders as fixed full-color art and can't pick up
/// [IconTheme]'s tint (or an explicit [color]) the way the rest of this
/// app's "_outlined" icons do.
class PrayingHandsIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const PrayingHandsIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24.0;
    final resolvedColor = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: CustomPaint(painter: _PrayingHandsPainter(resolvedColor)),
    );
  }
}

class _PrayingHandsPainter extends CustomPainter {
  final Color color;

  _PrayingHandsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    // Each hand is a petal: an outer curve up to the fingertips and an
    // inner curve back down to where the wrists meet, mirrored left/right
    // of the center seam where the two palms touch.
    final right = Path()
      ..moveTo(p(12, 19).dx, p(12, 19).dy)
      ..quadraticBezierTo(p(17, 12).dx, p(17, 12).dy, p(15, 4).dx, p(15, 4).dy)
      ..quadraticBezierTo(p(13, 11).dx, p(13, 11).dy, p(12, 19).dx, p(12, 19).dy);
    final left = Path()
      ..moveTo(p(12, 19).dx, p(12, 19).dy)
      ..quadraticBezierTo(p(7, 12).dx, p(7, 12).dy, p(9, 4).dx, p(9, 4).dy)
      ..quadraticBezierTo(p(11, 11).dx, p(11, 11).dy, p(12, 19).dx, p(12, 19).dy);
    canvas.drawPath(right, paint);
    canvas.drawPath(left, paint);

    // Wrist band where the hands meet.
    canvas.drawLine(p(9.5, 19.5), p(14.5, 19.5), paint);
  }

  @override
  bool shouldRepaint(covariant _PrayingHandsPainter oldDelegate) =>
      oldDelegate.color != color;
}
