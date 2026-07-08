import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/network/presentation/bloc/network_cubit.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_cubit.dart';
import 'package:provider/provider.dart';

class OfflineGamesSuggestion extends StatelessWidget {
  final String? errorMessage;

  const OfflineGamesSuggestion({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final isLoyaltyEnabled =
        config.loyaltyGlobalEnabled && config.loyaltyCustomerVisible;

    final isOffline =
        !context.watch<NetworkCubit>().isOnline ||
        (errorMessage?.toLowerCase().contains('conexión') ?? false) ||
        (errorMessage?.toLowerCase().contains('internet') ?? false) ||
        (errorMessage?.toLowerCase().contains('offline') ?? false);

    if (!isOffline || !isLoyaltyEnabled) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const Text(
          '¿Aburrido esperando?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.push('/customer/points');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.sports_esports_rounded),
          label: const Text(
            'Ir a Minijuegos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '¡Juega y gana monedas sin internet!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
