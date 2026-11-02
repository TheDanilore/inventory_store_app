import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Vista de estado vacío contextual para el directorio de clientes.
class CustomersEmptyState extends StatelessWidget {
  final int tabIndex;
  final String searchQuery;
  final VoidCallback onCreateCustomer;

  const CustomersEmptyState({
    super.key,
    required this.tabIndex,
    required this.searchQuery,
    required this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 52,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tabIndex == 1
                ? 'No hay clientes con deuda activa'
                : (tabIndex == 2
                    ? 'Aún no hay compras registradas para el ranking VIP'
                    : 'No se encontraron clientes registrados'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tabIndex == 1
                ? 'Todos los clientes se encuentran al día con sus saldos.'
                : 'Crea un nuevo registro para comenzar a procesar ventas.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (tabIndex == 0 && searchQuery.isEmpty)
            FilledButton.icon(
              onPressed: onCreateCustomer,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Registrar nuevo cliente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
