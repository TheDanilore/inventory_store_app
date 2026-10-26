import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_sales_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_best_sellers_table.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/expiring_batches_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_admin_goal_card.dart';

/// Bento Grid adaptativo y modular para el Dashboard
class DashboardBentoGrid extends StatelessWidget {
  final DashboardLoaded state;
  final Set<String> visibleWidgets;
  final void Function(String widgetId, bool isVisible) onToggleWidget;
  final VoidCallback onOpenAddWidgetSheet;

  const DashboardBentoGrid({
    super.key,
    required this.state,
    required this.visibleWidgets,
    required this.onToggleWidget,
    required this.onOpenAddWidgetSheet,
  });

  bool hasAnyBodyWidgets(BuildContext context) {
    final canViewSales = context.hasAnyPermission(const [
      AppPermissions.reportsSales,
      AppPermissions.reportsFinancial,
      AppPermissions.reportsView,
    ]);
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);

    final hasSpline =
        visibleWidgets.contains('profit_spline') &&
        state.overview != null &&
        canViewSales;
    final hasWeekly =
        visibleWidgets.contains('weekly_activity') &&
        state.overview != null &&
        canViewSales;
    final hasGoal =
        visibleWidgets.contains('radial_goal') &&
        (context.isAdmin || canViewSales);
    final hasBestSellers =
        visibleWidgets.contains('best_sellers') && canViewSales;
    final hasCustomers =
        visibleWidgets.contains('customer_segments') &&
        state.topCustomers.isNotEmpty &&
        canViewSales;
    final hasBatches =
        visibleWidgets.contains('expiring_batches') && canViewInventory;

    return hasSpline ||
        hasWeekly ||
        hasGoal ||
        hasBestSellers ||
        hasCustomers ||
        hasBatches;
  }

  List<Widget> _withSpacers(List<Widget> list, double spacing) {
    if (list.isEmpty) return [];
    final res = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      res.add(list[i]);
      if (i < list.length - 1) {
        res.add(SizedBox(height: spacing));
      }
    }
    return res;
  }

  Widget _buildEmptyWidgetsPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                            : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 30,
                    color:
                        isDark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Lienzo de Dashboard Vacío',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'No hay componentes visibles o con permisos activos. Personaliza tu vista añadiendo widgets clave en cualquier momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onOpenAddWidgetSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Añadir Widgets (Atajo: W)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 350.ms)
        .scale(begin: const Offset(0.97, 0.97), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;

    final canViewSales = context.hasAnyPermission(const [
      AppPermissions.reportsSales,
      AppPermissions.reportsFinancial,
      AppPermissions.reportsView,
    ]);
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);

    // ── NIVEL 1: GRÁFICOS ANALÍTICOS Y METAS ──────────────────────────────
    final hasSpline =
        visibleWidgets.contains('profit_spline') &&
        overview != null &&
        canViewSales;
    final hasWeekly =
        visibleWidgets.contains('weekly_activity') &&
        overview != null &&
        canViewSales;
    final hasGoal =
        visibleWidgets.contains('radial_goal') &&
        (context.isAdmin || canViewSales);

    Widget? level1Widget;
    if (hasSpline && (hasWeekly || hasGoal)) {
      level1Widget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: SalesTrendCard(overview: overview)),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasWeekly) WeeklyActivityCard(overview: overview),
                if (hasWeekly && hasGoal) const SizedBox(height: 20),
                if (hasGoal) const DashboardAdminGoalCard(),
              ],
            ),
          ),
        ],
      );
    } else if (hasSpline) {
      level1Widget = SalesTrendCard(overview: overview);
    } else if (hasWeekly || hasGoal) {
      level1Widget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasWeekly)
            Expanded(flex: 6, child: WeeklyActivityCard(overview: overview)),
          if (hasWeekly && hasGoal) const SizedBox(width: 20),
          if (hasGoal) const Expanded(flex: 6, child: DashboardAdminGoalCard()),
        ],
      );
    }

    // ── NIVEL 2: OPERACIONES, ROTACIÓN Y FEFO (SIMETRÍA 1:1) ───────────────
    final hasBestSellers =
        visibleWidgets.contains('best_sellers') && canViewSales;
    final hasCustomers =
        visibleWidgets.contains('customer_segments') &&
        state.topCustomers.isNotEmpty &&
        canViewSales;
    final hasBatches =
        visibleWidgets.contains('expiring_batches') && canViewInventory;

    final leftLevel2 = <Widget>[
      if (hasBestSellers)
        DashboardBestSellersTable(
          bestSellers: state.sales.bestSellers,
          criticalBatches: state.criticalBatches,
        ),
    ];

    final rightLevel2 = <Widget>[
      if (hasCustomers)
        TopCustomersCard(
          customers: state.topCustomers,
          displayMode: TopCustomersDisplayMode.desktop,
        ),
      if (hasBatches) ExpiringBatchesCard(batches: state.criticalBatches),
    ];

    Widget? level2Widget;
    if (leftLevel2.isNotEmpty && rightLevel2.isNotEmpty) {
      level2Widget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacers(leftLevel2, 20),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacers(rightLevel2, 20),
            ),
          ),
        ],
      );
    } else if (leftLevel2.isNotEmpty) {
      level2Widget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacers(leftLevel2, 20),
      );
    } else if (rightLevel2.isNotEmpty) {
      level2Widget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacers(rightLevel2, 20),
      );
    }

    final allLevels = <Widget>[
      if (level1Widget != null) level1Widget,
      if (level2Widget != null) level2Widget,
    ];

    if (allLevels.isEmpty) {
      return _buildEmptyWidgetsPlaceholder(context);
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final widgetId = details.data;
        if (!visibleWidgets.contains(widgetId)) {
          onToggleWidget(widgetId, true);
          AppFeedbackService.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Widget añadido al Dashboard con éxito'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(isHovering ? 8 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                isHovering
                    ? Border.all(color: const Color(0xFF2563EB), width: 2)
                    : null,
            color:
                isHovering
                    ? const Color(0xFFEFF6FF).withValues(alpha: 0.25)
                    : Colors.transparent,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacers(allLevels, 20),
            ),
          ),
        );
      },
    );
  }
}
