import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';

class InventoryStockSkeleton extends StatelessWidget {
  const InventoryStockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: InventoryPalette.of(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: InventoryPalette.of(context).border),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 48, height: 48, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 140, height: 16, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 90, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const AppShimmer(width: 60, height: 22, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }
}
