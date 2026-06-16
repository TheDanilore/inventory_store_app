import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/customer/cart_checkout_provider.dart';

class CartWalletSummary extends StatelessWidget {
  final CartProvider cart;
  final int saldoPuntos;

  const CartWalletSummary({
    super.key,
    required this.cart,
    required this.saldoPuntos,
  });

  @override
  Widget build(BuildContext context) {
    if (saldoPuntos <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo de Billetera',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tienes S/ ${(saldoPuntos * 0.01).toStringAsFixed(2)} disponibles',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildToggle(context, saldoPuntos),
        ],
      ),
    );
  }

  Widget _buildToggle(BuildContext context, int saldoPuntos) {
    final checkout = context.watch<CartCheckoutProvider>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          checkout.toggleUsePoints();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: checkout.usePoints ? Colors.orange : Colors.grey.shade300,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: checkout.usePoints ? 24 : 2,
                right: checkout.usePoints ? 2 : 24,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
