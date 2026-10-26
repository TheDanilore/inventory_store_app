import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_executive_widgets.dart';

/// Franja o cuadrícula de las 4 tarjetas KPI principales del Dashboard con control de permisos.
class DashboardKpisSection extends StatelessWidget {
  final DashboardLoaded state;
  final bool isTabletOrMobile;

  const DashboardKpisSection({
    super.key,
    required this.state,
    this.isTabletOrMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final canViewSales = context.hasAnyPermission(const [
      AppPermissions.reportsSales,
      AppPermissions.reportsFinancial,
      AppPermissions.reportsView,
    ]);
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);
    final canViewFinancial = context.hasAnyPermission(const [
      AppPermissions.reportsFinancial,
      AppPermissions.productsCostsView,
    ]);

    final totalSalesKpi =
        canViewSales
            ? DashboardKpiStripCard(
              title: 'Ventas Totales',
              value: 'S/ ${state.sales.totalRevenue.toStringAsFixed(2)}',
              deltaText: '15.5%',
              isPositiveDelta: true,
              subtitle: '${state.sales.totalSales} órdenes en período',
              icon: Icons.point_of_sale_rounded,
              accentColor: const Color(0xFF2563EB),
            )
            : null;

    final averageTicketKpi =
        canViewSales
            ? DashboardKpiStripCard(
              title: 'Ticket Promedio',
              value: 'S/ ${state.sales.averageTicket.toStringAsFixed(2)}',
              deltaText: '8.4%',
              isPositiveDelta: true,
              subtitle: 'Gasto medio por orden',
              icon: Icons.calculate_rounded,
              accentColor: const Color(0xFF0D9488),
            )
            : null;

    final totalStockKpi =
        canViewInventory
            ? DashboardKpiStripCard(
              title: 'Stock Total',
              value: '${state.inventory.totalStock} unid.',
              deltaText:
                  state.inventory.lowStockProducts > 0
                      ? '${state.inventory.lowStockProducts} alertas'
                      : 'Óptimo',
              isPositiveDelta: state.inventory.lowStockProducts == 0,
              subtitle: '${state.inventory.totalProducts} prods.',
              icon: Icons.inventory_2_rounded,
              accentColor: const Color(0xFF0EA5E9),
            )
            : null;

    final grossProfitKpi =
        canViewFinancial
            ? DashboardKpiStripCard(
              title: 'Ganancia Bruta',
              value: 'S/ ${state.sales.totalProfit.toStringAsFixed(2)}',
              deltaText: '${state.sales.salesMargin.toStringAsFixed(1)}%',
              isPositiveDelta: true,
              subtitle:
                  'Fondo: S/ ${state.sales.replacementFund.toStringAsFixed(2)}',
              icon: Icons.trending_up_rounded,
              accentColor: const Color(0xFF10B981),
            )
            : null;

    final visibleKpis = [
      if (totalSalesKpi != null) totalSalesKpi,
      if (averageTicketKpi != null) averageTicketKpi,
      if (totalStockKpi != null) totalStockKpi,
      if (grossProfitKpi != null) grossProfitKpi,
    ];

    if (visibleKpis.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget animateKpi(Widget kpi, int index) {
      return kpi
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 160 + index * 50),
            duration: const Duration(milliseconds: 380),
          )
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
    }

    if (!isTabletOrMobile) {
      // ── DESKTOP: FILA HORIZONTAL DE KPIS ─────────────────────────────────
      return Row(
        children: [
          for (int i = 0; i < visibleKpis.length; i++) ...[
            Expanded(child: animateKpi(visibleKpis[i], i)),
            if (i < visibleKpis.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    }

    // ── TABLET / MÓVIL: CUADRÍCULA 2X2 O SEGÚN CANTIDAD VISIBLE ──────────
    if (visibleKpis.length <= 2) {
      return Row(
        children: [
          for (int i = 0; i < visibleKpis.length; i++) ...[
            Expanded(child: animateKpi(visibleKpis[i], i)),
            if (i < visibleKpis.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    // Dividir en 2 filas
    final mid = (visibleKpis.length / 2).ceil();
    final firstRow = visibleKpis.sublist(0, mid);
    final secondRow = visibleKpis.sublist(mid);

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < firstRow.length; i++) ...[
              Expanded(child: animateKpi(firstRow[i], i)),
              if (i < firstRow.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < secondRow.length; i++) ...[
              Expanded(child: animateKpi(secondRow[i], mid + i)),
              if (i < secondRow.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}
