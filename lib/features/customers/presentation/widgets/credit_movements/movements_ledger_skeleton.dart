import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class DesktopLedgerSkeleton extends StatelessWidget {
  const DesktopLedgerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 90, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 60, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 24, height: 12, borderRadius: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 90, height: 16, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 80, height: 20, borderRadius: 6),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 70, height: 16, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 75, height: 14, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 80, height: 14, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 65, height: 16, borderRadius: 4),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 20, height: 20, borderRadius: 4),
                    ),
                  ),
                ],
              ),
            ),
            if (i < 5) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}
