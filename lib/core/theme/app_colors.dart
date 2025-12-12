import 'package:flutter/material.dart';

/// Centralized color tokens for the app (voyage).
class AppColors {
  static const Color background = Color(0xFF050814);
  static const Color surface = Color(0xFF0B1020);
  static const Color surfaceElevated = Color(0xFF101526);
  static const Color surfaceHighlight = Color(0xFF151B34);

  static const Color primary = Color(0xFF2F8FFF);
  static const Color primaryBright = Color(0xFF47D4FF);
  static const Color primarySoft = Color(0x332F8FFF);

  static const Color secondary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF22C55E);
  static const Color accentWarm = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF6B7280);

  static const Color borderSubtle = Color(0xFF1F2933);
  static const Color chipBackground = Color(0xFF111827);

  static const Color chatBackground = background;
  static const Color chatBubbleMe = primary;
  static const Color chatBubbleOther = Color(0xFF111827);

  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      primary,
      primaryBright,
      secondary,
    ],
  );

  static const LinearGradient subtleSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      surfaceHighlight,
      surface,
    ],
  );
}
