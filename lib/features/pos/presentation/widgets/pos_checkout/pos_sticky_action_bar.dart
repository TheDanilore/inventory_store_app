import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

class PosStickyActionBar extends StatelessWidget {
  final double ratio;
  final String discountText;
  final bool isDiscountPercentage;
  final bool isProcessingLocal;
  final void Function({required bool isDraft}) onProcessSale;

  const PosStickyActionBar({
    super.key,
    required this.ratio,
    required this.discountText,
    required this.isDiscountPercentage,
    required this.isProcessingLocal,
    required this.onProcessSale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.puntosAUsar != curr.puntosAUsar ||
                  prev.selectedClientId != curr.selectedClientId ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.activeShift != curr.activeShift ||
                  prev.creditInfo != curr.creditInfo ||
                  prev.status != curr.status,
          builder: (context, posState) {
            return BlocBuilder<CartCubit, CartState>(
              buildWhen:
                  (prev, curr) =>
                      prev.totalAmount != curr.totalAmount ||
                      prev.items.isEmpty != curr.items.isEmpty,
              builder: (context, cartState) {
                final isCredito = posState.paymentMethod == 'CRÉDITO';
                final puntosSeguros = PosCalculatorUtils.clampPointsValue(
                  posState.puntosAUsar,
                  posState,
                  cartState,
                  ratio,
                );
                final descuentoExtra =
                    PosCalculatorUtils.getCustomDiscountAmount(
                      discountText: discountText,
                      isDiscountPercentage: isDiscountPercentage,
                      pos: posState,
                      cart: cartState,
                      ratio: ratio,
                    );
                final descuentoExcedido =
                    descuentoExtra >
                    (cartState.totalAmount - (puntosSeguros * ratio));

                final totalFinal = PosCalculatorUtils.calcularTotalFinal(
                  discountText: discountText,
                  isDiscountPercentage: isDiscountPercentage,
                  pos: posState,
                  cart: cartState,
                  ratio: ratio,
                );

                final disp = PosCalculatorUtils.getCreditDisponible(
                  posState.creditInfo,
                );
                final creditoInsuficiente =
                    isCredito &&
                    posState.selectedClientId != null &&
                    PosCalculatorUtils.isCreditActivo(posState.creditInfo) &&
                    disp < totalFinal;
                final creditoSinCliente =
                    isCredito && posState.selectedClientId == null;

                final accountData = posState.accounts.firstWhere(
                  (a) => a['id'] == posState.selectedAccountId,
                  orElse: () => <String, dynamic>{},
                );
                final requiresShift =
                    accountData['is_cash_register'] == true ||
                    accountData['requires_shift'] == true;
                final noCajaAbierta =
                    !isCredito &&
                    posState.selectedAccountId != null &&
                    requiresShift &&
                    posState.activeShift == null;

                final puedeVender =
                    cartState.items.isNotEmpty &&
                    !descuentoExcedido &&
                    !creditoInsuficiente &&
                    !creditoSinCliente &&
                    !noCajaAbierta;

                final isProcessingSale =
                    posState.status == PosStatus.loading || isProcessingLocal;

                return Stack(
                  children: [
                    Row(
                      children: [
                        // Botón Secundario: Guardar Borrador
                        SizedBox(
                          height: 50,
                          child: Tooltip(
                            message: 'Guardar orden como borrador',
                            child: OutlinedButton(
                              onPressed:
                                  (isProcessingSale ||
                                          cartState.items.isEmpty ||
                                          descuentoExcedido)
                                      ? null
                                      : () => onProcessSale(isDraft: true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                backgroundColor: Colors.white,
                                disabledForegroundColor: AppColors.textMuted,
                                side: BorderSide(
                                  color:
                                      (cartState.items.isEmpty ||
                                              descuentoExcedido)
                                          ? Colors.grey.shade200
                                          : AppColors.border,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.bookmark_add_outlined, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Borrador',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Botón Principal: Cobrar (CTA)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  (!puedeVender || isProcessingSale)
                                      ? null
                                      : () => onProcessSale(isDraft: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                disabledBackgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.grey.shade500,
                                elevation: puedeVender ? 2 : 0,
                                shadowColor: AppColors.teal.withValues(
                                  alpha: 0.35,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                              ),
                              child:
                                  isProcessingSale
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                      : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons
                                                .shopping_cart_checkout_rounded,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              isCredito
                                                  ? 'Vender a crédito'
                                                  : 'Cobrar S/ ${totalFinal.toStringAsFixed(2)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isProcessingSale)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.5),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
