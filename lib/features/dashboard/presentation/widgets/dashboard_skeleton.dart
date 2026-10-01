import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 720;

        if (isDesktop) {
          return _buildDesktopSkeleton();
        }
        if (isTablet) {
          return _buildTabletSkeleton();
        }
        return _buildMobileSkeleton();
      },
    );
  }

  Widget _buildDesktopSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Health summary bar
        AppShimmer(width: double.infinity, height: 48, borderRadius: 16),
        const SizedBox(height: 20),

        // Row of 4 Hero KPIs
        Row(
          children: [
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 16),
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 16),
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 16),
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 24),

        // Main 2-column body
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Ventas & Clientes VIP)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmer(width: 160, height: 24, borderRadius: 6),
                      AppShimmer(width: 220, height: 36, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppShimmer(width: double.infinity, height: 88, borderRadius: 18),
                  const SizedBox(height: 12),
                  AppShimmer(width: double.infinity, height: 120, borderRadius: 20),
                  const SizedBox(height: 20),
                  // Table Shimmer (Clientes que más compran)
                  AppShimmer(width: double.infinity, height: 260, borderRadius: 20),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column (Inventario & Operación)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppShimmer(width: 160, height: 24, borderRadius: 6),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppShimmer(width: double.infinity, height: 88, borderRadius: 18),
                  const SizedBox(height: 12),
                  AppShimmer(width: double.infinity, height: 130, borderRadius: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppShimmer(width: double.infinity, height: 48, borderRadius: 16),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: AppShimmer(height: 100, borderRadius: 20)),
            const SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 100, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  AppShimmer(width: double.infinity, height: 116, borderRadius: 20),
                  const SizedBox(height: 14),
                  AppShimmer(width: double.infinity, height: 180, borderRadius: 20),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  AppShimmer(width: double.infinity, height: 150, borderRadius: 20),
                  const SizedBox(height: 14),
                  AppShimmer(width: double.infinity, height: 180, borderRadius: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppShimmer(width: double.infinity, height: 52, borderRadius: 16),
        const SizedBox(height: 16),
        AppShimmer(width: double.infinity, height: 116, borderRadius: 24),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: AppShimmer(height: 100, borderRadius: 20)),
            const SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 100, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 12),
        AppShimmer(width: double.infinity, height: 84, borderRadius: 16),
        const SizedBox(height: 12),
        AppShimmer(width: double.infinity, height: 130, borderRadius: 20),
        const SizedBox(height: 20),
        // Clientes skeleton
        AppShimmer(width: double.infinity, height: 220, borderRadius: 20),
      ],
    );
  }
}
