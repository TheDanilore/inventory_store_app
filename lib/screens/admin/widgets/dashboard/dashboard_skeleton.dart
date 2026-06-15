import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Goal card shimmer
        AppShimmer(width: double.infinity, height: 120, borderRadius: 24),
        const SizedBox(height: 24),

        // Section Header Shimmer
        Row(
          children: [
            AppShimmer(width: 40, height: 40, borderRadius: 10),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(width: 150, height: 20, borderRadius: 4),
                const SizedBox(height: 6),
                AppShimmer(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // KPI Cards Row Shimmer
        Row(
          children: [
            Expanded(child: AppShimmer(height: 120, borderRadius: 16)),
            const SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 120, borderRadius: 16)),
          ],
        ),
        const SizedBox(height: 12),

        // Wide KPI Card Shimmer
        AppShimmer(width: double.infinity, height: 80, borderRadius: 16),
        const SizedBox(height: 12),

        // SubSection Shimmer
        Row(
          children: [
            AppShimmer(width: 3, height: 14, borderRadius: 2),
            const SizedBox(width: 8),
            AppShimmer(width: 150, height: 14, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 8),

        // Ganancia Bruta Shimmer
        AppShimmer(width: double.infinity, height: 140, borderRadius: 16),
        const SizedBox(height: 12),

        // KPI Cards Row Shimmer
        Row(
          children: [
            Expanded(child: AppShimmer(height: 120, borderRadius: 16)),
            const SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 120, borderRadius: 16)),
          ],
        ),
      ],
    );
  }
}
