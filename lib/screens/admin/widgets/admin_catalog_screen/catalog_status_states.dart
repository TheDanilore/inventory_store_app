import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

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
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ocurrió un error',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
