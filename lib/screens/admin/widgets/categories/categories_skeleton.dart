import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class CategoriesSkeleton extends StatelessWidget {
  final int itemCount;

  const CategoriesSkeleton({super.key, this.itemCount = 6});

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
                AppShimmer(
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
                      AppShimmer(
                        width: 150,
                        height: 16,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      AppShimmer(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Status Shimmer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppShimmer(
                      width: 50,
                      height: 18,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 8),
                    AppShimmer(
                      width: 40,
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
