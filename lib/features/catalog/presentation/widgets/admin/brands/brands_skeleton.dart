import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class BrandsSkeleton extends StatelessWidget {
  final int itemCount;

  const BrandsSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100 ? 3 : (width >= 650 ? 2 : 1);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 96,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Logo placeholder shimmer
                const AppShimmer(width: 52, height: 52, borderRadius: 12),
                const SizedBox(width: 14),

                // Name and Description Shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      AppShimmer(width: 120, height: 16, borderRadius: 4),
                      SizedBox(height: 8),
                      AppShimmer(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status & Switch Shimmer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    AppShimmer(width: 48, height: 18, borderRadius: 6),
                    SizedBox(height: 8),
                    AppShimmer(width: 36, height: 18, borderRadius: 10),
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
