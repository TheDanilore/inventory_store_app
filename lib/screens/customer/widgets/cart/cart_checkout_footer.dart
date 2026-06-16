import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/customer/cart_checkout_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
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

    final subtotal = cart.selectedTotalAmount;
    final totalAPagar = checkoutProvider.calculateFinalTotal(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final puntosUsados = checkoutProvider.calculateApplicablePoints(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final descuentoSoles = puntosUsados * pointsToSolesRatio;

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
          children: [
            _buildPriceRow('Subtotal', 'S/ ${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            if (descuentoSoles > 0)
              _buildPriceRow(
                'Descuento por Puntos',
                '- S/ ${descuentoSoles.toStringAsFixed(2)}',
                valueColor: Colors.orange,
              ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total a Pagar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'S/ ${totalAPagar.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (cart.selectedItems.isEmpty || isSending)
                        ? null
                        : onProcessCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Enviar por WhatsApp',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
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
