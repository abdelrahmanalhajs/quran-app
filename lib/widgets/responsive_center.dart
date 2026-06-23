import 'package:flutter/material.dart';

/// Centers [child] and caps its width on large screens (tablets like iPad,
/// foldables, desktop windows) so list rows, cards and text don't stretch
/// edge-to-edge and become hard to read. On phone-width screens this is a
/// no-op since the constraint is wider than the available space.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 700});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
