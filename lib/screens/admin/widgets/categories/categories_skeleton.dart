import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class CategoriesSkeleton extends StatelessWidget {
  final int itemCount;

  const CategoriesSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width >= 600 ? 2 : 1;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 88, // Altura fija que coincide con las tarjetas reales
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Shimmer
                AppShimmer(
                  width: 46,
                  height: 46,
                  borderRadius: 12,
                ),
                const SizedBox(width: 16),

                // Text Shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppShimmer(
                        width: 100, // Menos ancho porque puede ser de 2 columnas
                        height: 16,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      AppShimmer(
                        width: double.infinity,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Status Shimmer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppShimmer(
                      width: 50,
                      height: 18,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 8),
                    AppShimmer(
                      width: 40,
                      height: 20,
                      borderRadius: 10,
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
