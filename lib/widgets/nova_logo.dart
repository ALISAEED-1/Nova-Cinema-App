import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The NOVA CINEMA wordmark.
class NovaLogo extends StatelessWidget {
  const NovaLogo({super.key, this.size = 20, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NOVA CINEMA',
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -size * 0.06,
        color: color,
        height: 1,
      ),
    );
  }
}
