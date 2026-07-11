import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/cart_checkout_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:provider/provider.dart';

class CartCheckoutFooter extends StatelessWidget {
  final CartProvider cart;
  final int saldoPuntos;
  final double pointsToSolesRatio;
  final VoidCallback onProcessCheckout;

  const CartCheckoutFooter({
    super.key,
    required this.cart,
    required this.saldoPuntos,
    required this.pointsToSolesRatio,
    required this.onProcessCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final checkoutProvider = context.read<CartCheckoutProvider>();
    final isSending = context.select<CartCheckoutProvider, bool>(
      (p) => p.isSending,
    );

    final config = context.read<AppConfigCubit>();
    final isLoyaltyEnabled =
        config.loyaltyGlobalEnabled && config.loyaltyCustomerVisible;

    final subtotal = cart.selectedTotalAmount;
    final totalAPagar =
        isLoyaltyEnabled
            ? checkoutProvider.calculateFinalTotal(
              cart,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : subtotal;
    final puntosUsados =
        isLoyaltyEnabled
            ? checkoutProvider.calculateApplicablePoints(
              cart,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : 0;
    final descuentoSoles = puntosUsados * pointsToSolesRatio;

    final selectedCount = cart.selectedItems.length;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (descuentoSoles > 0) ...[
              _buildPriceRow('Subtotal', 'S/ ${subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              _buildPriceRow(
                'Descuento por Puntos',
                '- S/ ${descuentoSoles.toStringAsFixed(2)}',
                valueColor: Colors.orange,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a pagar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/ ${totalAPagar.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$selectedCount prod.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (selectedCount == 0 || isSending)
                        ? null
                        : onProcessCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    isSending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Enviar por WhatsApp',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
