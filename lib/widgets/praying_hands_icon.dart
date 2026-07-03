import 'package:flutter/material.dart';

/// Two open cupped hands raised in dua (the 🤲 posture) — used for Athkar
/// throughout the app (main nav, in-reader nav, onboarding). Drawn as a plain
/// outline so it picks up [IconTheme]'s tint like the rest of the app's
/// "_outlined" icons, instead of rendering as a fixed full-color emoji glyph.
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
    final sc = size.width / 24;
    Offset p(double x, double y) => Offset(x * sc, y * sc);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * sc
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Traces one hand from inner wrist up through 4 finger lobes (with notch
    // valleys between them) and down to the outer wrist flare. When mirror is
    // true every x-coordinate is reflected across the centre line (x=12) so
    // the same path doubles as the left hand.
    void drawHand(bool mirror) {
      double mx(double x) => mirror ? 24 - x : x;
      Offset q(double x, double y) => p(mx(x), y);

      final path = Path()
        // Inner wrist (near centre bottom)
        ..moveTo(q(12.3, 21.5).dx, q(12.3, 21.5).dy)
        // Up inner palm
        ..quadraticBezierTo(
          q(12.8, 13.0).dx, q(12.8, 13.0).dy,
          q(14.2, 6.5).dx, q(14.2, 6.5).dy,
        )
        // Index fingertip (tallest)
        ..quadraticBezierTo(
          q(14.4, 3.8).dx, q(14.4, 3.8).dy,
          q(15.0, 7.2).dx, q(15.0, 7.2).dy,
        )
        // Valley → middle finger
        ..quadraticBezierTo(
          q(15.4, 8.8).dx, q(15.4, 8.8).dy,
          q(16.0, 6.0).dx, q(16.0, 6.0).dy,
        )
        // Middle fingertip
        ..quadraticBezierTo(
          q(16.2, 4.5).dx, q(16.2, 4.5).dy,
          q(16.6, 6.0).dx, q(16.6, 6.0).dy,
        )
        // Valley → ring finger
        ..quadraticBezierTo(
          q(17.2, 8.5).dx, q(17.2, 8.5).dy,
          q(17.8, 7.0).dx, q(17.8, 7.0).dy,
        )
        // Ring fingertip
        ..quadraticBezierTo(
          q(18.1, 5.8).dx, q(18.1, 5.8).dy,
          q(18.4, 7.0).dx, q(18.4, 7.0).dy,
        )
        // Valley → pinky
        ..quadraticBezierTo(
          q(19.0, 9.8).dx, q(19.0, 9.8).dy,
          q(19.6, 9.0).dx, q(19.6, 9.0).dy,
        )
        // Pinky fingertip
        ..quadraticBezierTo(
          q(19.9, 8.0).dx, q(19.9, 8.0).dy,
          q(20.2, 9.0).dx, q(20.2, 9.0).dy,
        )
        // Down outer edge to wrist flare
        ..quadraticBezierTo(
          q(21.8, 14.0).dx, q(21.8, 14.0).dy,
          q(22.2, 21.5).dx, q(22.2, 21.5).dy,
        );

      canvas.drawPath(path, paint);
    }

    drawHand(false); // right hand
    drawHand(true); // left hand (mirrored)

    // V-notch where the two inner wrists meet at the very centre bottom.
    canvas.drawLine(p(11.7, 21.5), p(12.0, 23.0), paint);
    canvas.drawLine(p(12.0, 23.0), p(12.3, 21.5), paint);
  }

  @override
  bool shouldRepaint(covariant _PrayingHandsPainter old) => old.color != color;
}
