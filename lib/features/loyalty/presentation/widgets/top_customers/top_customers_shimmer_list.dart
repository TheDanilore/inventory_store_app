import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TopCustomersShimmerList extends StatelessWidget {
  const TopCustomersShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        Widget buildItem() {
          return Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(width: 32, height: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  const CircleAvatar(radius: 24, backgroundColor: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(width: 100, height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 80, height: 16, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (isWide) {
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisExtent: 96,
              crossAxisSpacing: 16,
              mainAxisSpacing: 0,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => buildItem(),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: 8,
            itemBuilder: (context, index) => buildItem(),
          );
        }
      },
    );
  }
}
