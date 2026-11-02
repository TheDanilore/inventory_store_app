import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AccountFormBalanceRow extends StatelessWidget {
  final TextEditingController balanceCtrl;
  final bool isEditing;
  final bool editBalance;
  final String currencyCode;
  final VoidCallback onToggleEditBalance;
  final ValueChanged<String> onCurrencyChanged;

  const AccountFormBalanceRow({
    super.key,
    required this.balanceCtrl,
    required this.isEditing,
    required this.editBalance,
    required this.currencyCode,
    required this.onToggleEditBalance,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final soft = dark ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;
    final line = AppColors.brdSubtle(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final tealText = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;
    final symbol = currencyCode == 'USD' ? '\$ ' : 'S/ ';
    final locked = isEditing && !editBalance;

    Widget currencySeg(String code) {
      final selected = currencyCode == code;
      return InkWell(
        onTap: () => onCurrencyChanged(code),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : muted,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: balanceCtrl,
            readOnly: locked,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: AppColors.txtMuted(context),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: locked ? soft : field,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.danger,
                  width: 1.5,
                ),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: title,
                    fontSize: 15,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon:
                  isEditing
                      ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton(
                          onPressed: onToggleEditBalance,
                          style: TextButton.styleFrom(
                            foregroundColor: tealText,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            editBalance ? 'Cancelar' : 'Corregir',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      : null,
              helperText:
                  editBalance
                      ? 'Estás corrigiendo el saldo manualmente.'
                      : null,
              helperStyle: TextStyle(fontSize: 11.5, color: muted),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: (v) {
              if (locked) return null;
              final text = v?.trim() ?? '';
              if (text.isEmpty) return isEditing ? 'Ingresa un saldo' : null;
              final parsed = double.tryParse(text.replaceAll(',', '.'));
              if (parsed == null) return 'Ingresa un número válido';
              if (!isEditing && parsed < 0) {
                return 'El saldo inicial no puede ser negativo';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [currencySeg('PEN'), currencySeg('USD')],
          ),
        ),
      ],
    );
  }
}
