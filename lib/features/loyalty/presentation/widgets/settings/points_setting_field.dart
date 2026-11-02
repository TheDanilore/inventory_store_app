import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';

class PointsSettingField extends StatelessWidget {
  final SettingItemConfig config;
  final TextEditingController controller;
  final bool disabled;
  final bool allowNegative;

  static final RegExp _positiveRegex = RegExp(r'^\d*\.?\d*');
  static final RegExp _signedRegex = RegExp(r'^-?\d*\.?\d*');

  static final List<TextInputFormatter> _positiveFormatters = [
    FilteringTextInputFormatter.allow(_positiveRegex),
  ];
  static final List<TextInputFormatter> _signedFormatters = [
    FilteringTextInputFormatter.allow(_signedRegex),
  ];

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade200),
  );

  static const OutlineInputBorder _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: AppColors.primary, width: 2),
  );

  static const OutlineInputBorder _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: Colors.red, width: 1.5),
  );

  const PointsSettingField({
    super.key,
    required this.config,
    required this.controller,
    this.disabled = false,
    this.allowNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? prefix;
    Widget? suffix;

    TextInputType kType = const TextInputType.numberWithOptions(
      decimal: true,
      signed: false,
    );

    if (config.format == SettingFormat.percent) {
      suffix = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          '%',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    } else if (config.format == SettingFormat.currency) {
      prefix = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          'S/',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
      );
    } else if (config.format == SettingFormat.integer) {
      kType = TextInputType.numberWithOptions(
        decimal: false,
        signed: allowNegative,
      );
      prefix = Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(
          config.icon ?? Icons.monetization_on_rounded,
          color: Colors.amber,
          size: 20,
        ),
      );
    }

    final inputFormatters =
        allowNegative ? _signedFormatters : _positiveFormatters;

    return TextFormField(
      controller: controller,
      enabled: !disabled,
      keyboardType: kType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: disabled ? Colors.grey : null,
      ),
      decoration: InputDecoration(
        labelText: config.description,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: disabled ? Colors.grey.shade100 : Colors.grey.shade50,
        border: _border,
        enabledBorder: _border,
        disabledBorder: _border,
        focusedBorder: _focusedBorder,
        errorBorder: _errorBorder,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Requerido';
        final parsed = double.tryParse(text);
        if (parsed == null) return 'Número inválido';
        if (!allowNegative && parsed < 0) return 'Debe ser positivo';
        if (config.format == SettingFormat.integer &&
            parsed != parsed.toInt()) {
          return 'Debe ser entero';
        }
        if (allowNegative &&
            parsed > 0 &&
            config.key == LoyaltySettingsKeys.catcherBombPenalty) {
          return 'Debe ser negativo';
        }
        return null;
      },
    );
  }
}
