import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_card_header.dart';

// ─── DETAILS CARD ─────────────────────────────────────────────────────────────

class ProductDetailsCard extends StatelessWidget {
  final Map<String, dynamic> details;
  const ProductDetailsCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    final entries = details.entries.toList();
    return Container(
      decoration: AppColors.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: ProductCardHeader(
              icon: Icons.list_alt_rounded,
              iconColor: Color(0xFF8B5CF6),
              iconBg: Color(0xFFEDE9FE),
              title: 'Especificaciones',
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          ...entries.asMap().entries.map((e) {
            final isEven = e.key % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              color: isEven ? AppColors.background : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.value.key.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.value.value.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
