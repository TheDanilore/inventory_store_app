import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';

class CategoriesStatsBar extends StatelessWidget {
  final List<CategoryEntity> categories;

  const CategoriesStatsBar({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final total = categories.length;
    final active = categories.where((c) => c.isActive).length;
    final inactive = total - active;

    return Row(
      children: [
        Text(
          '$total ${total == 1 ? 'categoría' : 'categorías'}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 10),
          _StatPill(label: '$active activas', color: AppColors.teal),
          if (inactive > 0) ...[
            const SizedBox(width: 6),
            _StatPill(label: '$inactive inactivas', color: AppColors.textMuted),
          ],
        ],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
