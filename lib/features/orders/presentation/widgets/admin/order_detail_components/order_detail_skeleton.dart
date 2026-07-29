import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class OrderDetailSkeleton extends StatelessWidget {
  const OrderDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmer(width: 150, height: 24),
                const SizedBox(height: 8),
                const AppShimmer(width: 250, height: 14),
              ],
            ),
            Row(
              children: [
                const AppShimmer(width: 36, height: 36, borderRadius: 18),
                const SizedBox(width: 8),
                const AppShimmer(width: 36, height: 36, borderRadius: 18),
              ],
            ),
          ],
        ),
        const Divider(height: 32),

        // Cards
        for (int i = 0; i < 3; i++) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmer(width: 120, height: 16),
                const SizedBox(height: 12),
                const AppShimmer(width: double.infinity, height: 48),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        // Items section header
        const AppShimmer(width: double.infinity, height: 20),
        const SizedBox(height: 12),

        // Item row
        Row(
          children: [
            const AppShimmer(width: 60, height: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppShimmer(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  const AppShimmer(width: 100, height: 14),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
