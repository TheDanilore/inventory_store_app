import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CategoriesEmptyState extends StatelessWidget {
  final bool isSearch;
  final String searchQuery;
  final VoidCallback onCreateCategory;

  const CategoriesEmptyState({
    super.key,
    required this.isSearch,
    required this.searchQuery,
    required this.onCreateCategory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearch ? Icons.search_off_rounded : Icons.category_outlined,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSearch
                    ? 'Sin resultados para\n"$searchQuery"'
                    : 'Aún no hay categorías',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isSearch
                    ? 'Intenta con otro término de búsqueda.'
                    : 'Organiza tus productos creando la primera categoría.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isSearch) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCreateCategory,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear categoría'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
