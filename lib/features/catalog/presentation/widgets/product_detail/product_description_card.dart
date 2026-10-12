import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_card_header.dart';

class ProductDescriptionCard extends StatelessWidget {
  final String description;
  const ProductDescriptionCard({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.trim().isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.cardAdaptive(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductCardHeader(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF3B82F6),
            iconBg:
                isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                    : const Color(0xFFEFF6FF),
            title: 'Descripción',
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
