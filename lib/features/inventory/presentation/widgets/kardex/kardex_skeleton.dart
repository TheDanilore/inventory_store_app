import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class KardexSkeleton extends StatelessWidget {
  const KardexSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AppShimmer(width: 100, height: 14, borderRadius: 4),
                    AppShimmer(width: 60, height: 20, borderRadius: 10),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppShimmer(width: 52, height: 52, borderRadius: 12),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppShimmer(width: 150, height: 18, borderRadius: 4),
                          SizedBox(height: 8),
                          AppShimmer(width: 100, height: 14, borderRadius: 4),
                          SizedBox(height: 8),
                          AppShimmer(width: 80, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        AppShimmer(width: 40, height: 12, borderRadius: 4),
                        SizedBox(height: 4),
                        AppShimmer(width: 50, height: 24, borderRadius: 4),
                        SizedBox(height: 4),
                        AppShimmer(width: 70, height: 12, borderRadius: 4),
                      ],
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
