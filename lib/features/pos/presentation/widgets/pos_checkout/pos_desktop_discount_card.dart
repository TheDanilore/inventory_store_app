import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

/// Tarjeta de descuento manual optimizada para escritorio (44px compact, segment control rápido).
class PosDesktopDiscountCard extends StatelessWidget {
  final TextEditingController discountController;
  final PosState posState;
  final CartState cartState;
  final double ratio;
  final int puntosSeguros;

  const PosDesktopDiscountCard({
    super.key,
    required this.discountController,
    required this.posState,
    required this.cartState,
    required this.ratio,
    required this.puntosSeguros,
  });

  @override
  Widget build(BuildContext context) {
    final isPercentage = posState.isDiscountPercentage;
    final discountAmount = PosCalculatorUtils.getCustomDiscountAmount(
      discountText: posState.discountText,
      isDiscountPercentage: isPercentage,
      pos: posState,
      cart: cartState,
      ratio: ratio,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sell_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'DESCUENTO MANUAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (discountAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '- S/ ${discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // ── Campo de Entrada 44px ──
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextFormField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    validator:
                        (v) => PosCalculatorUtils.validateDiscountInput(
                          text: v,
                          isPercentage: isPercentage,
                          maxDiscountAmount:
                              PosCalculatorUtils.getMaxCustomDiscount(
                                cartState,
                                ratio,
                                puntosSeguros,
                              ),
                          cartTotal: cartState.totalAmount,
                        ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6),
                        child: Text(
                          isPercentage ? '%' : 'S/',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      final posCubit = context.read<PosCubit>();
                      if (v.trim().isEmpty) {
                        posCubit.setDiscountText('');
                        return;
                      }
                      final val = double.tryParse(v) ?? 0.0;
                      final maxDiscount =
                          PosCalculatorUtils.getMaxCustomDiscount(
                            cartState,
                            ratio,
                            puntosSeguros,
                          );
                      final amt =
                          isPercentage
                              ? (cartState.totalAmount * (val / 100))
                              : val;
                      if (amt > maxDiscount) {
                        if (isPercentage) {
                          final maxPerc =
                              (maxDiscount / cartState.totalAmount) * 100;
                          final text = maxPerc.toStringAsFixed(2);
                          discountController.value = TextEditingValue(
                            text: text,
                            selection: TextSelection.collapsed(
                              offset: text.length,
                            ),
                          );
                          posCubit.setDiscountText(text);
                        } else {
                          final text = maxDiscount.toStringAsFixed(2);
                          discountController.value = TextEditingValue(
                            text: text,
                            selection: TextSelection.collapsed(
                              offset: text.length,
                            ),
                          );
                          posCubit.setDiscountText(text);
                        }
                      } else {
                        posCubit.setDiscountText(v);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Selector Segmentado Moderno [ S/ ] [ % ] 44px ──
              Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentButton(
                      label: 'S/ Monto',
                      isSelected: !isPercentage,
                      onTap: () {
                        if (isPercentage) {
                          context.read<PosCubit>().setIsDiscountPercentage(
                            false,
                          );
                          discountController.text = '';
                          context.read<PosCubit>().setDiscountText('');
                        }
                      },
                    ),
                    _buildSegmentButton(
                      label: '% Porc.',
                      isSelected: isPercentage,
                      onTap: () {
                        if (!isPercentage) {
                          context.read<PosCubit>().setIsDiscountPercentage(
                            true,
                          );
                          discountController.text = '';
                          context.read<PosCubit>().setDiscountText('');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.teal : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
