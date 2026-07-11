import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/cart_checkout_provider.dart';

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

    final config = context.watch<AppConfigCubit>();
    final checkout = context.watch<CartCheckoutProvider>();

    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final totalAPagar = checkout.calculateFinalTotal(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final puntosAGanar =
        (totalAPagar * earningRate / pointsToSolesRatio).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.shade500.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monedas disponibles',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade200,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$saldoPuntos monedas',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: checkout.usePoints,
                activeTrackColor: Colors.amber,
                onChanged: (val) {
                  checkout.toggleUsePoints();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: Colors.blueGrey.shade300,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Ganarás $puntosAGanar monedas con este pedido',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
