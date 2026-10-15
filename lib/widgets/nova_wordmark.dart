import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The stacked NOVA / CINEMA wordmark used on the onboarding screens.
///
/// The "O" is drawn rather than typed: it is a thin light ring with a red arc
/// sweeping its upper-right, which no font can express.
class NovaWordmark extends StatelessWidget {
  const NovaWordmark({super.key, this.size = 30});

  /// Cap height of the NOVA lettering.
  final double size;

  @override
  Widget build(BuildContext context) {
    final letterStyle = TextStyle(
      fontFamily: 'Outfit',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1,
    );
    // Space between glyphs, matching the wide tracking in the design.
    final gap = size * 0.26;

    return Semantics(
      label: 'Nova Cinema',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('N', style: letterStyle),
              SizedBox(width: gap),
              _ArcRing(size: size * 0.82),
              SizedBox(width: gap),
              Text('V', style: letterStyle),
              SizedBox(width: gap),
              Text('A', style: letterStyle),
            ],
          ),
          SizedBox(height: size * 0.22),
          Text(
            'CINEMA',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: size * 0.34,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              letterSpacing: size * 0.30,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The stylised "O": a light ring overlaid by a red arc.
class _ArcRing extends StatelessWidget {
  const _ArcRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArcRingPainter(strokeWidth: size * 0.09)),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  const _ArcRingPainter({required this.strokeWidth});

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;

    // Light ring, leaving a gap where the red arc sits.
    canvas.drawArc(inset, -math.pi * 0.32, math.pi * 1.72, false, ring);
    // Red sweep across the upper-right.
    canvas.drawArc(inset, -math.pi * 0.46, math.pi * 0.62, false, arc);
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}
