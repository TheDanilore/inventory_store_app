import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class ActiveIngredientsSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const ActiveIngredientsSkeleton({
    super.key,
    this.itemCount = 8,
    this.crossAxisCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (crossAxisCount > 1) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 14,
          mainAxisExtent: 80,
        ),
        itemBuilder: (context, index) => _buildSkeletonCard(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: const Row(
        children: [
          // Icon Shimmer
          AppShimmer(width: 42, height: 42, borderRadius: 12),
          SizedBox(width: 14),

          // Text Shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppShimmer(width: 140, height: 15, borderRadius: 4),
                SizedBox(height: 6),
                AppShimmer(width: 80, height: 11, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),

          // Action button shimmer
          AppShimmer(width: 28, height: 28, borderRadius: 8),
        ],
      ),
    );
  }
}

