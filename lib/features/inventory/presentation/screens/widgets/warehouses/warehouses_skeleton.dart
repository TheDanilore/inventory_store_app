import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class WarehousesSkeleton extends StatelessWidget {
  final int itemCount;

  const WarehousesSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Shimmer
                const AppShimmer(
                  width: 46,
                  height: 46,
                  borderRadius: 12,
                ),
                const SizedBox(width: 16),
                
                // Text Shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppShimmer(
                        width: 160,
                        height: 18,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const AppShimmer(
                        width: 120,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Status Shimmer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const AppShimmer(
                      width: 50,
                      height: 16,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 8),
                    const AppShimmer(
                      width: 36,
                      height: 20,
                      borderRadius: 10,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
