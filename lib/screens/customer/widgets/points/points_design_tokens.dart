import 'package:flutter/material.dart';

class PointsDS {
  // Amber / gold palette
  static const gold = Color(0xFFF59E0B);
  static const goldLight = Color(0xFFFEF3C7);
  static const goldDark = Color(0xFF92400E);
  static const goldMid = Color(0xFFFBBF24);

  // Teal palette
  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFFCCFBF1);
  static const tealDark = Color(0xFF0F766E);

  // Neutrals
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8ECF0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Status
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const successDark = Color(0xFF047857);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFFE4E6);

  static const radius = 16.0;
  static const radiusXl = 24.0;

  static List<BoxShadow> cardShadow({double opacity = 0.06}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
