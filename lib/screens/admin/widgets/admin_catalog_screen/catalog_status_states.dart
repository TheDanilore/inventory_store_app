import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:provider/provider.dart';

class CatalogEmptyState extends StatelessWidget {
  final bool searchByIngredient;
  final String searchTerm;

  const CatalogEmptyState({
    super.key,
    this.searchByIngredient = false,
    this.searchTerm = '',
  });

  @override
  Widget build(BuildContext context) {
    final isIngMode = searchByIngredient && searchTerm.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                    isIngMode ? const Color(0xFFECFDF5) : AppColors.tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isIngMode ? Icons.science_rounded : Icons.inventory_2_rounded,
                size: 36,
                color: isIngMode ? const Color(0xFF10B981) : AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isIngMode ? 'Sin resultados para "$searchTerm"' : 'Sin productos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isIngMode
                  ? 'Ningún producto tiene ese ingrediente activo registrado. '
                      'Verifica el nombre o agrégalo desde el formulario del producto.'
                  : 'No se encontraron productos\ncon los filtros actuales.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogErrorState extends StatelessWidget {
  final String message;
  const CatalogErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOffline = !context.watch<NetworkProvider>().isOnline || 
                      message.toLowerCase().contains('conexión') || 
                      message.toLowerCase().contains('internet') ||
                      message.toLowerCase().contains('offline');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isOffline ? Colors.orange.withValues(alpha: 0.15) : AppColors.dangerLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 32,
                color: isOffline ? Colors.orange : AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? 'Sin conexión a internet' : 'Ocurrió un error',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isOffline 
                  ? 'Revisa tu conexión para cargar el catálogo.' 
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (isOffline) ...[
              const SizedBox(height: 24),
              const Text(
                '¿Aburrido esperando?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
                '¡Juega y gana monedas offline!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
