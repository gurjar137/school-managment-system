import 'package:flutter/material.dart';

class AppColors {
  // Primary Reference Tokens
  static const Color navy = Color(0xFF10182D);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color mainBackground = Color(0xFFF5F7FB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Legacy Theme Aliases (strictly mapped to standard tokens)
  static const Color midnightNavy = navy;
  static const Color midnightNavyLight = Color(0xFF1E293B);
  static const Color midnightNavyDark = Color(0xFF0A0F1D);
  static const Color deepSlate = Color(0xFF1E293B);

  // Backgrounds
  static const Color warmOffWhite = mainBackground;
  static const Color pureWhite = cardBackground;
  static const Color surfaceLight = Color(0xFFF1F5F9);
  
  // Dark Surfaces
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF131C2E);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);

  // Supporting Accents
  static const Color softLavender = indigo;
  static const Color lavenderLight = Color(0xFFEEF2FF);
  static const Color lavenderDark = Color(0xFF4338CA);

  static const Color mutedGreen = success;
  static const Color greenLight = Color(0xFFECFDF5);
  static const Color greenDark = Color(0xFF059669);

  static const Color warmAmber = warning;
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color amberDark = Color(0xFFD97706);

  static const Color softCoral = error;
  static const Color coralLight = Color(0xFFFEF2F2);
  static const Color coralDark = Color(0xFFDC2626);

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
  static const Color glassDark = Color(0xCC131C2E);
  static const Color borderLight = border;
  static const Color borderDark = Color(0xFF334155);

  // Shimmer / Skeletal Loading
  static const Color shimmerBaseLight = Color(0xFFE2E8F0);
  static const Color shimmerHighlightLight = Color(0xFFF8FAFC);
  static const Color shimmerBaseDark = Color(0xFF1E293B);
  static const Color shimmerHighlightDark = Color(0xFF334155);
}
