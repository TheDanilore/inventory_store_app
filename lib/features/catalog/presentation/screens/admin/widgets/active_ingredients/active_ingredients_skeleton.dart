import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class ActiveIngredientsSkeleton extends StatelessWidget {
  final int itemCount;

  const ActiveIngredientsSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon Shimmer
                const AppShimmer(
                  width: 40,
                  height: 40,
                  borderRadius: 20,
                ),
                const SizedBox(width: 16),
                
                // Text Shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppShimmer(
                        width: 180,
                        height: 16,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const AppShimmer(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // More button shimmer
                const AppShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
