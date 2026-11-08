import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_credit_warning_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_custom_discount_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';

class PosCheckoutSummaryBlock extends StatelessWidget {
  final double ratio;
  final double earningRate;
  final bool isLoyaltyEnabled;
  final TextEditingController discountCtrl;
  final ValueNotifier<bool> isDiscountPercentageNotifier;

  const PosCheckoutSummaryBlock({
    super.key,
    required this.ratio,
    required this.earningRate,
    required this.isLoyaltyEnabled,
    required this.discountCtrl,
    required this.isDiscountPercentageNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, curr) =>
              prev.paymentMethod != curr.paymentMethod ||
              prev.puntosAUsar != curr.puntosAUsar ||
              prev.selectedClientId != curr.selectedClientId ||
              prev.saldoActualCliente != curr.saldoActualCliente ||
              prev.creditInfo != curr.creditInfo,
      builder: (context, posState) {
        return BlocBuilder<CartCubit, CartState>(
          buildWhen: (prev, curr) => prev.totalAmount != curr.totalAmount,
          builder: (context, cartState) {
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            final puntosSeguros = PosCalculatorUtils.clampPointsValue(
              posState.puntosAUsar,
              posState,
              cartState,
              ratio,
            );

            return RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCredito) ...[
                    PosCreditWarningCard(
                      clienteSeleccionado: posState.selectedClientId != null,
                      creditActivo: PosCalculatorUtils.isCreditActivo(
                        posState.creditInfo,
                      ),
                      creditDisponible: PosCalculatorUtils.getCreditDisponible(
                        posState.creditInfo,
                      ),
                      totalFinal: PosCalculatorUtils.calcularTotalFinal(
                        discountText: discountCtrl.text,
                        isDiscountPercentage:
                            isDiscountPercentageNotifier.value,
                        pos: posState,
                        cart: cartState,
                        ratio: ratio,
                      ),
                      creditInfo: posState.creditInfo,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (!isCredito) ...[
                    PosCustomDiscountCard(
                      discountController: discountCtrl,
                      isPercentageNotifier: isDiscountPercentageNotifier,
                      posState: posState,
                      cartState: cartState,
                      ratio: ratio,
                      puntosSeguros: puntosSeguros,
                    ),
                    const SizedBox(height: 24),
                  ],
                  PosTotalSummarySection(
                    subtotalAntesDePuntos: cartState.totalAmount,
                    puntosAplicables:
                        isCredito || !isLoyaltyEnabled ? 0 : puntosSeguros,
                    descuentoPuntos:
                        isCredito || !isLoyaltyEnabled
                            ? 0
                            : puntosSeguros * ratio,
                    isLoyaltyEnabled: isLoyaltyEnabled,
                    descuentoExtra:
                        isCredito
                            ? 0
                            : PosCalculatorUtils.getCustomDiscountAmount(
                              discountText: discountCtrl.text,
                              isDiscountPercentage:
                                  isDiscountPercentageNotifier.value,
                              pos: posState,
                              cart: cartState,
                              ratio: ratio,
                            ),
                    totalFinal: PosCalculatorUtils.calcularTotalFinal(
                      discountText: discountCtrl.text,
                      isDiscountPercentage: isDiscountPercentageNotifier.value,
                      pos: posState,
                      cart: cartState,
                      ratio: ratio,
                    ),
                    pointsToSolesRatio: ratio,
                    earningRate: earningRate,
                    isCredito: isCredito,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
