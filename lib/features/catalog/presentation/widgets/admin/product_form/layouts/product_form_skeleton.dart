import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Skeleton loader responsivo para la pantalla de formulario de producto.
/// Se muestra únicamente en cold starts cuando no existen datos en memoria/caché L1.
class ProductFormSkeleton extends StatelessWidget {
  const ProductFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        if (isDesktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: const [
                      AppShimmer(
                        width: double.infinity,
                        height: 180,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 250,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 200,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: const [
                      AppShimmer(
                        width: double.infinity,
                        height: 220,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 160,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 100,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [AppShimmer(width: 120, height: 40, borderRadius: 12)],
            ),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 180, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 300, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 120, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 250, borderRadius: 16),
          ],
        );
      },
    );
  }
}
