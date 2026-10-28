import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

String fmtQty(double v) {
  if (v % 1 == 0) return v.toInt().toString();
  return v
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

InputDecoration entryInputDecoration({
  String? hint,
  String? helper,
  String? prefixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color? accent,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    helperText: helper,
    helperStyle: TextStyle(
      color: accent ?? AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(accent ?? AppColors.border),
    enabledBorder: border(accent ?? AppColors.border),
    focusedBorder: border(accent ?? AppColors.primary, 1.5),
  );
}
