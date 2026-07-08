import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class AttributesSkeleton extends StatelessWidget {
  final int itemCount;

  const AttributesSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const AppShimmer(
                          width: 24,
                          height: 24,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 8),
                        const AppShimmer(
                          width: 120,
                          height: 20,
                          borderRadius: 6,
                        ),
                      ],
                    ),
                    const AppShimmer(
                      width: 24,
                      height: 24,
                      borderRadius: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const AppShimmer(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    3,
                    (chipIndex) => const AppShimmer(
                      width: 60,
                      height: 32,
                      borderRadius: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
