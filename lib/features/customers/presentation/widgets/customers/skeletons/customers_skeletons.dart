import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Esqueleto Shimmer para la vista en tabla en Desktop y Tablet
class DesktopTableSkeleton extends StatelessWidget {
  const DesktopTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.background,
                child: const Row(
                  children: [
                    AppShimmer(width: 80, height: 12, borderRadius: 4),
                    Spacer(),
                    AppShimmer(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              ...List.generate(
                7,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: const Row(
                    children: [
                      AppShimmer(width: 34, height: 34, borderRadius: 17),
                      SizedBox(width: 12),
                      AppShimmer(width: 160, height: 14, borderRadius: 4),
                      Spacer(),
                      AppShimmer(width: 90, height: 14, borderRadius: 4),
                      SizedBox(width: 20),
                      AppShimmer(width: 70, height: 20, borderRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esqueleto Shimmer para la vista en tarjetas o lista en Móvil
class CustomersCardSkeleton extends StatelessWidget {
  const CustomersCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  AppShimmer(width: 48, height: 48, borderRadius: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmer(width: 150, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        AppShimmer(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  AppShimmer(width: 60, height: 24, borderRadius: 12),
                ],
              ),
            ),
          );
        }, childCount: 6),
      ),
    );
  }
}
