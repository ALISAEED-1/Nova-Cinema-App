import 'package:flutter/material.dart';

/// Central colour palette. Every widget reads from here — never inline colours.
abstract final class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF050608);
  static const Color surface = Color(0xFF0E1013);
  static const Color surfaceElevated = Color(0xFF161A1F);
  static const Color surfaceHighlight = Color(0xFF1F242B);

  // Brand
  static const Color primary = Color(0xFFE50914);
  static const Color primaryPressed = Color(0xFFB20710);
  static const Color gold = Color(0xFFE8B44C);

  // Text
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF6B6F76);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnLight = Color(0xFF0A0A0A);

  // Lines & overlays
  static const Color border = Color(0x14FFFFFF);
  static const Color borderStrong = Color(0x29FFFFFF);
  static const Color overlay = Color(0x99000000);
  static const Color shimmerBase = Color(0xFF15181D);
  static const Color shimmerHighlight = Color(0xFF23282F);

  // Semantic
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ADE80);
}
