import 'package:flutter/material.dart';

class AppColors {
  // --- Modern Light Design System Core Tokens ---
  static const Color mainBackground = Color(0xFFF7F9FC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color primaryAccent = Color(0xFF4F46E5);
  static const Color softBlue = Color(0xFFEAF2FF);
  static const Color softLavender = Color(0xFFF0ECFF);
  static const Color softMint = Color(0xFFE9F9F1);
  static const Color softAmber = Color(0xFFFFF5DF);
  static const Color primaryText = Color(0xFF243047);
  static const Color secondaryText = Color(0xFF738096);
  static const Color border = Color(0xFFE7ECF3);
  static const Color success = Color(0xFF16A765);
  static const Color warning = Color(0xFFE9A23B);
  static const Color error = Color(0xFFE45454);

  // --- Mapped & Backwards-Compatible Tokens ---
  static const Color indigo = primaryAccent;
  static const Color navy = primaryText;
  static const Color pureWhite = cardBackground;
  static const Color warmOffWhite = mainBackground;
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color borderLight = border;

  // Legacy Theme Aliases (strictly mapped to standard tokens)
  static const Color midnightNavy = primaryText;
  static const Color midnightNavyLight = Color(0xFF334155);
  static const Color midnightNavyDark = Color(0xFF0F172A);
  static const Color deepSlate = primaryText;

  // Dark Surfaces (Clean, subtle slate dark mode)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color borderDark = Color(0xFF334155);

  // Supporting Accents & Pastels
  static const Color lavenderLight = softLavender;
  static const Color lavenderDark = Color(0xFF4338CA);

  static const Color mutedGreen = success;
  static const Color greenLight = softMint;
  static const Color greenDark = Color(0xFF0D7A4A);

  static const Color warmAmber = warning;
  static const Color amberLight = softAmber;
  static const Color amberDark = Color(0xFFC0761B);

  static const Color softCoral = error;
  static const Color coralLight = Color(0xFFFDE8E8);
  static const Color coralDark = Color(0xFFC83232);

  static const Color coolGray = secondaryText;
  static const Color coolGrayLight = Color(0xFF94A3B8);
  static const Color coolGrayDark = Color(0xFF475569);

  // Attendance Status Colors
  static const Color attendancePresent = success;
  static const Color attendanceAbsent = error;
  static const Color attendanceLate = warning;
  static const Color attendanceNotMarked = Color(0xFF94A3B8);

  // Glass / Elevation Overlays
  static const Color glassWhite = Color(0xCCFFFFFF);
  static const Color glassDark = Color(0xCC1E293B);

  // Shimmer / Skeletal Loading
  static const Color shimmerBaseLight = Color(0xFFE7ECF3);
  static const Color shimmerHighlightLight = Color(0xFFF8FAFC);
  static const Color shimmerBaseDark = Color(0xFF1E293B);
  static const Color shimmerHighlightDark = Color(0xFF334155);
}
