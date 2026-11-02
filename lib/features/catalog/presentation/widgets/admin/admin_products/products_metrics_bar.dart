import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

/// Datos inmutables para el strip de mÃ©tricas de catÃ¡logo.
/// Permite que `BlocSelector` evite rebuilds innecesarios cuando cambia el tÃ©rmino de bÃºsqueda u otros filtros.
@immutable
class ProductsMetricsData {
  final int totalCount;
  final int inStockCount;
  final int outOfStockCount;
  final int totalUnits;
  final int categoriesCount;
  final bool isMultiPage;

  const ProductsMetricsData({
    required this.totalCount,
    required this.inStockCount,
    required this.outOfStockCount,
    required this.totalUnits,
    required this.categoriesCount,
    required this.isMultiPage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductsMetricsData &&
          runtimeType == other.runtimeType &&
          totalCount == other.totalCount &&
          inStockCount == other.inStockCount &&
          outOfStockCount == other.outOfStockCount &&
          totalUnits == other.totalUnits &&
          categoriesCount == other.categoriesCount &&
          isMultiPage == other.isMultiPage;

  @override
  int get hashCode => Object.hash(
    totalCount,
    inStockCount,
    outOfStockCount,
    totalUnits,
    categoriesCount,
    isMultiPage,
  );
}

/// Strip de mÃ©tricas ejecutivas de catÃ¡logo (Bento Grid) de alta densidad.
/// Utiliza `BlocSelector` para aislar el hilo UI y prevenir recomputaciÃ³n durante keystrokes de bÃºsqueda.
class ProductsMetricsBar extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;

  const ProductsMetricsBar({
    super.key,
    required this.isMobile,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      AdminCatalogCubit,
      AdminCatalogState,
      ProductsMetricsData
    >(
      selector: (state) {
        final totalCount = state.totalCount;
        int inStockCount = 0;
        int totalUnits = 0;
        for (final p in state.products) {
          final stock = p.totalStock;
          if (stock > 0) inStockCount++;
          totalUnits += stock;
        }
        final outOfStockCount = state.products.length - inStockCount;
        final isMultiPage = state.totalPages > 1;

        return ProductsMetricsData(
          totalCount: totalCount,
          inStockCount: inStockCount,
          outOfStockCount: outOfStockCount,
          totalUnits: totalUnits,
          categoriesCount: state.categories.length,
          isMultiPage: isMultiPage,
        );
      },
      builder: (context, data) {
        return AdminKpiMetricsBar(
          isDesktop: !isMobile,
          padding: EdgeInsets.zero,
          items: [
            AdminKpiItem(
              title: 'TOTAL CATÁLOGO',
              value: '${data.totalCount}',
              subtitle: '${data.categoriesCount} categorías registradas',
              icon: Icons.inventory_2_rounded,
              accentColor: AppColors.primary,
              gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
              iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
              borderColor: const Color(0xFFE2E8F0),
              glowColor: const Color(0x1F0F172A),
            ),
            AdminKpiItem(
              title:
                  data.isMultiPage ? 'EN STOCK (PÁG)' : 'EN STOCK DISPONIBLE',
              value: '${data.inStockCount}',
              subtitle:
                  data.isMultiPage
                      ? '${data.inStockCount} en pág. actual'
                      : (data.totalCount > 0
                          ? '${((data.inStockCount / (data.totalCount > 0 ? data.totalCount : 1)) * 100).toStringAsFixed(0)}% disponible para venta'
                          : 'Listo para despacho'),
              icon: Icons.check_circle_outline_rounded,
              accentColor: AppColors.successDark,
              gradientColors: const [Colors.white, Color(0xFFECFDF5)],
              iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
              borderColor: const Color(0xFFA7F3D0),
              glowColor: const Color(0x2E10B981),
            ),
            AdminKpiItem(
              title:
                  data.isMultiPage ? 'AGOTADOS (PÁG)' : 'AGOTADOS / CRÍTICOS',
              value: '${data.outOfStockCount}',
              subtitle:
                  data.isMultiPage
                      ? '${data.outOfStockCount} en pág. actual'
                      : (data.outOfStockCount > 0
                          ? 'Requieren reposición'
                          : 'Sin quiebres de inventario'),
              icon: Icons.warning_amber_rounded,
              accentColor:
                  data.outOfStockCount > 0
                      ? AppColors.danger
                      : AppColors.tealDark,
              gradientColors: [
                Colors.white,
                data.outOfStockCount > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDFA),
              ],
              iconGradient:
                  data.outOfStockCount > 0
                      ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                      : const [Color(0xFF0D9488), Color(0xFF0F766E)],
              borderColor:
                  data.outOfStockCount > 0
                      ? const Color(0xFFFECACA)
                      : const Color(0xFF99F6E4),
              glowColor:
                  data.outOfStockCount > 0
                      ? const Color(0x2EEF4444)
                      : const Color(0x2E0D9488),
              isAlert: data.outOfStockCount > 0,
            ),
            AdminKpiItem(
              title: 'UNIDADES EN ALMACÉN',
              value: '${data.totalUnits} unid.',
              subtitle:
                  data.isMultiPage
                      ? 'En pág. actual'
                      : 'Existencias consolidadas',
              icon: Icons.all_inbox_rounded,
              accentColor: AppColors.info,
              gradientColors: const [Colors.white, Color(0xFFF0F9FF)],
              iconGradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              borderColor: const Color(0xFFBAE6FD),
              glowColor: const Color(0x2E0EA5E9),
            ),
          ],
        );
      },
    );
  }
}
