import 'package:flutter/material.dart';

/// Enterprise brand palette for Smart Delivery.
abstract final class AppColors {
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color accent = Color(0xFF0D9488);
  static const Color accentLight = Color(0xFF14B8A6);
  static const Color accentDark = Color(0xFF0F766E);

  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);

  static const Color live = Color(0xFF22C55E);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
  );

  static Color statusColor(String status) {
    switch (status) {
      case 'delivered':
        return success;
      case 'cancelled':
        return error;
      case 'high_risk':
        return error;
      case 'delayed':
        return warning;
      case 'in_transit':
      case 'out_for_delivery':
      case 'picked_up':
        return accent;
      default:
        return info;
    }
  }

  static Color delayColor(String delayStatus) {
    switch (delayStatus) {
      case 'delayed':
        return warning;
      case 'high_risk':
        return error;
      default:
        return success;
    }
  }
}
