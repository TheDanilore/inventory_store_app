import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton con la misma estructura de la pantalla: podio + filas.
class TopCustomersShimmerList extends StatelessWidget {
  const TopCustomersShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    Widget box(double h, {double? w, double r = 12}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: box(190, r: 22)),
                      const SizedBox(width: 16),
                      Expanded(child: box(230, r: 22)),
                      const SizedBox(width: 16),
                      Expanded(child: box(190, r: 22)),
                    ],
                  )
                else ...[
                  box(210, r: 22),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: box(170, r: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: box(170, r: 22)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                for (var i = 0; i < 5; i++) ...[
                  Row(
                    children: [
                      box(16, w: 30),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: box(14)),
                      const SizedBox(width: 24),
                      box(14, w: 80),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
