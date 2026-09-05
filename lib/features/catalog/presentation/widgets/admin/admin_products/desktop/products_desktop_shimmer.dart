import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Esqueleto de carga (Shimmer) de alta fidelidad para la tabla de escritorio.
class ProductsDesktopShimmer extends StatelessWidget {
  final int rows;

  const ProductsDesktopShimmer({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              AppShimmer(width: 20, height: 20, borderRadius: 4),
              SizedBox(width: 16),
              AppShimmer(width: 36, height: 36, borderRadius: 10),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmer(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  AppShimmer(width: 200, height: 11, borderRadius: 4),
                ],
              ),
              Spacer(),
              AppShimmer(width: 90, height: 20, borderRadius: 6),
              SizedBox(width: 20),
              AppShimmer(width: 70, height: 20, borderRadius: 6),
              SizedBox(width: 20),
              AppShimmer(width: 60, height: 20, borderRadius: 12),
              SizedBox(width: 20),
              AppShimmer(width: 48, height: 20, borderRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
