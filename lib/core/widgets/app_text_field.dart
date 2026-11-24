import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final bool readOnly;
  final String? helperText;
  final String? hintText;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? style;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.helperText,
    this.hintText,
    this.prefixText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.style,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.txtPrimary(context),
    );
    final resolvedStyle = style != null ? baseStyle.merge(style) : baseStyle;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: maxLines,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      focusNode: focusNode,
      style: resolvedStyle,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.txtMuted(context), fontSize: 14),
        prefixText: prefixText,
        labelStyle: TextStyle(
          color: AppColors.txtSecondary(context),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.txtSecondary(context),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: TextStyle(color: AppColors.txtMuted(context), fontSize: 12),
        filled: true,
        fillColor:
            readOnly
                ? AppColors.inputFillReadOnly(context)
                : AppColors.inputFill(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.brdSubtle(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.brdSubtle(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.brandPrimary(context),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.dangerText(context),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.dangerText(context),
            width: 1.8,
          ),
        ),
      ),
    );
  }
}
