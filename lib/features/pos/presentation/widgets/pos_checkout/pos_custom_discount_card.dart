import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

class PosCustomDiscountCard extends StatelessWidget {
  final TextEditingController discountController;
  final ValueNotifier<bool> isPercentageNotifier;
  final PosState posState;
  final CartState cartState;
  final double ratio;
  final int puntosSeguros;

  const PosCustomDiscountCard({
    super.key,
    required this.discountController,
    required this.isPercentageNotifier,
    required this.posState,
    required this.cartState,
    required this.ratio,
    required this.puntosSeguros,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPercentageNotifier,
      builder: (context, isPercentage, _) {
        final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
          discountText: discountController.text,
          isDiscountPercentage: isPercentage,
          pos: posState,
          cart: cartState,
          ratio: ratio,
        );
        final maxAllowed = cartState.totalAmount - (puntosSeguros * ratio);
        final descuentoExcedido = descuentoExtra > maxAllowed;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(
              color:
                  descuentoExcedido ? AppColors.danger : Colors.grey.shade200,
            ),
            boxShadow: AppColors.cardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sell_outlined,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Descuento Extra',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusSm + 2,
                        ),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusSm + 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => isPercentageNotifier.value = false,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color:
                                      !isPercentage
                                          ? Colors.white
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radiusSm,
                                  ),
                                  boxShadow:
                                      !isPercentage
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                          : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'S/',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        !isPercentage
                                            ? AppColors.primary
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => isPercentageNotifier.value = true,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color:
                                      isPercentage
                                          ? Colors.white
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radiusSm,
                                  ),
                                  boxShadow:
                                      isPercentage
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                          : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPercentage
                                            ? AppColors.primary
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (descuentoExcedido)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'El descuento supera el total a pagar (S/ ${maxAllowed.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
