import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_document_and_currency_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';

class PosPaymentAndConfigSection extends StatelessWidget {
  final double ratio;
  final bool isLoyaltyEnabled;
  final TextEditingController pointsController;
  final ValueChanged<String?> onWarehouseChanged;

  const PosPaymentAndConfigSection({
    super.key,
    required this.ratio,
    required this.isLoyaltyEnabled,
    required this.pointsController,
    required this.onWarehouseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.selectedClientId != curr.selectedClientId ||
                  prev.saldoActualCliente != curr.saldoActualCliente ||
                  prev.puntosAUsar != curr.puntosAUsar,
          builder: (context, posState) {
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            return BlocSelector<CartCubit, CartState, double>(
              selector: (state) => state.totalAmount,
              builder: (context, totalAmount) {
                final cartState = context.read<CartCubit>().state;
                return AdminSalePointsSection(
                  show:
                      isLoyaltyEnabled &&
                      posState.selectedClientId != null &&
                      posState.saldoActualCliente > 0 &&
                      !isCredito,
                  saldoActualCliente: posState.saldoActualCliente,
                  maxPuntosAplicables: PosCalculatorUtils.maxPuntosAplicables(
                    posState,
                    cartState,
                    ratio,
                  ),
                  pointsToSolesRatio: ratio,
                  pointsController: pointsController,
                  onPointsChanged: (p) {
                    final posCubit = context.read<PosCubit>();
                    final next = PosCalculatorUtils.clampPointsValue(
                      p,
                      posState,
                      cartState,
                      ratio,
                    );
                    posCubit.setPuntosAUsar(next);
                    pointsController.value = TextEditingValue(
                      text: next.toString(),
                      selection: TextSelection.collapsed(
                        offset: next.toString().length,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.discountText != curr.discountText ||
                  prev.isDiscountPercentage != curr.isDiscountPercentage ||
                  prev.puntosAUsar != curr.puntosAUsar,
          builder: (context, posState) {
            return BlocBuilder<CartCubit, CartState>(
              buildWhen: (prev, curr) => prev.totalAmount != curr.totalAmount,
              builder: (context, cartState) {
                final currentTotal = PosCalculatorUtils.calcularTotalFinal(
                  discountText: posState.discountText,
                  isDiscountPercentage: posState.isDiscountPercentage,
                  pos: posState,
                  cart: cartState,
                  ratio: ratio,
                );
                return PosDocumentAndCurrencyCard(totalFinal: currentTotal);
              },
            );
          },
        ),
        const SizedBox(height: 20),
        PosSectionLabel('Método de pago y almacén'),
        BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.warehouses != curr.warehouses ||
                  prev.selectedWarehouseId != curr.selectedWarehouseId ||
                  prev.accounts != curr.accounts ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.activeShift != curr.activeShift,
          builder: (context, posState) {
            final posCubit = context.read<PosCubit>();
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            return PaymentWarehouseAccountCard(
              paymentMethod: posState.paymentMethod,
              warehouseList: posState.warehouses,
              selectedWarehouseId: posState.selectedWarehouseId,
              accountsList: posState.accounts,
              selectedAccountId: posState.selectedAccountId,
              activeShift: posState.activeShift,
              isCredito: isCredito,
              onCreditoToggle: (isCredito) {
                if (isCredito) {
                  posCubit.setPaymentMethod('CRÉDITO');
                  posCubit.setPuntosAUsar(0);
                  pointsController.text = '0';
                } else {
                  if (posState.selectedAccountId != null) {
                    final acc = posState.accounts.firstWhere(
                      (a) => a['id'] == posState.selectedAccountId,
                      orElse: () => {},
                    );
                    final accName = acc['name'] as String? ?? 'EFECTIVO';
                    posCubit.setPaymentMethod(accName);
                  } else {
                    posCubit.setPaymentMethod('EFECTIVO');
                  }
                }
              },
              onWarehouseChanged: onWarehouseChanged,
              onAccountChanged: (v) {
                posCubit.setSelectedAccountId(v);
                if (v != null) {
                  final acc = posState.accounts.firstWhere(
                    (a) => a['id'] == v,
                    orElse: () => {},
                  );
                  final accName = acc['name'] as String? ?? 'OTRO';
                  posCubit.setPaymentMethod(accName);
                }
              },
            );
          },
        ),
      ],
    );
  }
}
