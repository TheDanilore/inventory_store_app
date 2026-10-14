import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart'
    show kAdminTableRowHPad, kAdminTableCellGutter;
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Shimmer de alta fidelidad que simula la estructura de una tabla Pro ejecutiva.
/// Reemplaza los bloques rectangulares cuadrados por una cabecera y filas
/// con celdas de dimensiones realistas.
/// Descripción mínima de una columna para el shimmer (espeja AdminTableColumn).
class AppShimmerColumn {
  final int flex;
  final double? fixedWidth;
  final AlignmentGeometry alignment;

  const AppShimmerColumn({
    this.flex = 1,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
  });
}

class AppTableShimmer extends StatelessWidget {
  final int rowCount;
  final double minWidth;

  /// Si se provee, el skeleton replica las columnas de la tabla real
  /// (anchos, flex y alineación) → sin salto visual al terminar de cargar.
  final List<AppShimmerColumn>? columns;
  final bool showCheckbox;

  const AppTableShimmer({
    super.key,
    this.rowCount = 6,
    this.minWidth = 880.0,
    this.columns,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    if (columns != null) {
      return _ColumnShimmerTable(
        columns: columns!,
        rowCount: rowCount,
        minWidth: minWidth,
        showCheckbox: showCheckbox,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

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
                    separatorBuilder:
                        (_, _) => const Divider(
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

class _ColumnShimmerTable extends StatelessWidget {
  final List<AppShimmerColumn> columns;
  final int rowCount;
  final double minWidth;
  final bool showCheckbox;

  const _ColumnShimmerTable({
    required this.columns,
    required this.rowCount,
    required this.minWidth,
    required this.showCheckbox,
  });

  static const _factors = [0.55, 0.8, 0.65, 0.9, 0.7, 0.6];

  Widget _bar(double factor, double height, AlignmentGeometry align) {
    return LayoutBuilder(
      builder:
          (_, c) => Align(
            alignment: align,
            child: AppShimmer(
              width: (c.maxWidth.isFinite ? c.maxWidth : 80) * factor,
              height: height,
              borderRadius: 4,
            ),
          ),
    );
  }

  Widget _cell(AppShimmerColumn col, Widget child) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kAdminTableCellGutter),
      child: child,
    );
    return col.fixedWidth != null
        ? SizedBox(width: col.fixedWidth, child: padded)
        : Expanded(flex: col.flex, child: padded);
  }

  Widget _leading() =>
      showCheckbox
          ? const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppShimmer(width: 16, height: 16, borderRadius: 4),
              ),
            ),
          )
          : const SizedBox.shrink();

  Widget _mainCell(int r) => Row(
    children: [
      const AppShimmer(width: 34, height: 34, borderRadius: 10),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(_factors[r % _factors.length], 12, Alignment.centerLeft),
            const SizedBox(height: 6),
            _bar(0.4, 9, Alignment.centerLeft),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > minWidth
                ? constraints.maxWidth
                : minWidth;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kAdminTableRowHPad,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : const Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        _leading(),
                        for (final c in columns)
                          _cell(c, _bar(0.5, 10, c.alignment)),
                      ],
                    ),
                  ),
                  for (int r = 0; r < rowCount; r++) ...[
                    if (r > 0) Divider(height: 1, color: border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kAdminTableRowHPad,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _leading(),
                          for (int i = 0; i < columns.length; i++)
                            _cell(
                              columns[i],
                              columns[i].fixedWidth == null
                                  ? _mainCell(r)
                                  : _bar(
                                    _factors[(r + i) % _factors.length].clamp(
                                      0.5,
                                      0.85,
                                    ),
                                    12,
                                    columns[i].alignment,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
