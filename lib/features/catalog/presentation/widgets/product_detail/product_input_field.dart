import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final int maxLines;

  const ProductInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        isDense: true,
      ),
    );
  }
}
