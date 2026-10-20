import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_section_card.dart';

class CustomerTopProductsSection extends StatelessWidget {
  final List<TopProductEntity> products;

  const CustomerTopProductsSection({super.key, required this.products});

  static const _palette = [
    AppColors.primary,
    AppColors.success,
    Colors.purple,
    Colors.orange,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final maxQty = products.first.totalQuantity;

    return CustomerSectionCard(
      title: 'Productos más comprados',
      icon: Icons.favorite_rounded,
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++)
            _TopProductTile(
              rank: i + 1,
              product: products[i],
              pct: maxQty > 0 ? products[i].totalQuantity / maxQty : 0.0,
              color: _palette[i % _palette.length],
              isLast: i == products.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  final int rank;
  final TopProductEntity product;
  final double pct;
  final Color color;
  final bool isLast;

  const _TopProductTile({
    required this.rank,
    required this.product,
    required this.pct,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          _Thumb(url: p.imageUrl, rank: rank, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${p.totalQuantity} uds',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· S/ ${p.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final int rank;
  final Color color;

  const _Thumb({required this.url, required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: color.withValues(alpha: 0.1),
      child: Icon(Icons.inventory_2_outlined, color: color, size: 22),
    );

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  (url == null || url!.isEmpty)
                      ? fallback
                      : CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        placeholder: (_, _) => fallback,
                        errorWidget: (_, _, _) => fallback,
                      ),
            ),
          ),
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1 ? AppColors.gold : color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
