import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
    
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'customer_section_card.dart';

class CustomerTopProductsSection extends StatelessWidget {
  final List<TopProductEntity> products;

  const CustomerTopProductsSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final maxQty = products.first.totalQuantity;

    return CustomerSectionCard(
      title: 'Productos más comprados',
      icon: Icons.favorite_rounded,
      child: Column(
        children:
            products.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final pct = maxQty > 0 ? p.totalQuantity / maxQty : 0.0;
              final colors = [
                AppColors.primary,
                AppColors.success,
                Colors.purple,
                Colors.orange,
                Colors.teal,
              ];
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.totalQuantity} uds',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'S/ ${p.totalSpent.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
