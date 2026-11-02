import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Estado vacío para el catálogo de componentes químicos.
class ActiveIngredientsEmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onCreate;
  final VoidCallback onClearSearch;

  const ActiveIngredientsEmptyState({
    super.key,
    required this.searchQuery,
    required this.onCreate,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: const Icon(
                Icons.science_outlined,
                size: 34,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? 'No se encontraron componentes'
                  : 'No hay componentes registrados',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                hasSearch
                    ? 'No existen componentes que coincidan con "$searchQuery". Prueba con otro término.'
                    : 'Registra los principios activos que forman parte de la formulación de tus productos.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (hasSearch)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Limpiar búsqueda'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Registrar Primer Componente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
