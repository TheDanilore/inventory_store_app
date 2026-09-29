import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Shimmer de alta fidelidad que simula la estructura de una tabla Pro ejecutiva.
/// Reemplaza los bloques rectangulares cuadrados por una cabecera y filas
/// con celdas de dimensiones realistas.
class AppTableShimmer extends StatelessWidget {
  final int rowCount;
  final double minWidth;

  const AppTableShimmer({
    super.key,
    this.rowCount = 6,
    this.minWidth = 880.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Cabecera Skeleton ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        AppShimmer(width: 70, height: 11, borderRadius: 4),
                        SizedBox(width: 30),
                        AppShimmer(width: 90, height: 11, borderRadius: 4),
                        SizedBox(width: 40),
                        Expanded(
                          flex: 4,
                          child: AppShimmer(
                            width: 140,
                            height: 11,
                            borderRadius: 4,
                          ),
                        ),
                        SizedBox(width: 20),
                        AppShimmer(width: 80, height: 11, borderRadius: 4),
                        SizedBox(width: 30),
                        AppShimmer(width: 70, height: 11, borderRadius: 4),
                        SizedBox(width: 30),
                        AppShimmer(width: 60, height: 11, borderRadius: 4),
                        SizedBox(width: 30),
                        AppShimmer(width: 60, height: 11, borderRadius: 4),
                      ],
                    ),
                  ),

                  // --- Filas Skeleton ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rowCount,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            // ID Badge skeleton
                            const AppShimmer(
                              width: 65,
                              height: 22,
                              borderRadius: 6,
                            ),
                            const SizedBox(width: 35),

                            // Fecha / hora skeleton
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppShimmer(
                                  width: 95,
                                  height: 12,
                                  borderRadius: 4,
                                ),
                                SizedBox(height: 4),
                                AppShimmer(
                                  width: 60,
                                  height: 9,
                                  borderRadius: 3,
                                ),
                              ],
                            ),
                            const SizedBox(width: 35),

                            // Nombre / Descripción principal
                            const Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppShimmer(
                                    width: 160,
                                    height: 13,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 5),
                                  AppShimmer(
                                    width: 100,
                                    height: 10,
                                    borderRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Badge de estado skeleton
                            const AppShimmer(
                              width: 80,
                              height: 22,
                              borderRadius: 6,
                            ),
                            const SizedBox(width: 30),

                            // Badge de pago skeleton
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppShimmer(
                                  width: 60,
                                  height: 18,
                                  borderRadius: 5,
                                ),
                                SizedBox(height: 3),
                                AppShimmer(
                                  width: 45,
                                  height: 9,
                                  borderRadius: 3,
                                ),
                              ],
                            ),
                            const SizedBox(width: 30),

                            // Monto numérico skeleton
                            const AppShimmer(
                              width: 65,
                              height: 14,
                              borderRadius: 4,
                            ),
                            const SizedBox(width: 30),

                            // Acción / Chevron skeleton
                            const AppShimmer(
                              width: 28,
                              height: 28,
                              borderRadius: 6,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
