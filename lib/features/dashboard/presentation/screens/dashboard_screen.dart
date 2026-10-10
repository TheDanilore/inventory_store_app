import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_executive_widgets.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/admin_goal_dialog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_add_widget_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DashboardCubit>()..loadDashboardData(),
      child: const _DashboardScreenContent(),
    );
  }
}

class _DashboardScreenContent extends StatefulWidget {
  const _DashboardScreenContent();

  static void _openGoalDialog(
    BuildContext context,
    double currentAmount,
    double targetAmount,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            elevation: 12,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AdminGoalDialog(
                currentAmount: currentAmount,
                targetAmount: targetAmount,
              ),
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AdminGoalDialog(
                    currentAmount: currentAmount,
                    targetAmount: targetAmount,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  State<_DashboardScreenContent> createState() =>
      _DashboardScreenContentState();
}

class _DashboardScreenContentState extends State<_DashboardScreenContent> {
  static const String _prefsKey = 'dashboard_visible_widget_ids';

  Set<String> _visibleWidgets = {
    'kpi_strip',
    'profit_spline',
    'best_sellers',
    'customer_segments',
    'weekly_activity',
    'radial_goal',
    'expiring_batches',
  };

  @override
  void initState() {
    super.initState();
    _loadVisibleWidgets();
  }

  Future<void> _loadVisibleWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _visibleWidgets =
              list.where((id) => id != 'ai_assistant').toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveVisibleWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _visibleWidgets.toList());
    } catch (_) {}
  }

  void _toggleWidget(String id, bool isVisible) {
    setState(() {
      if (isVisible) {
        _visibleWidgets.add(id);
      } else {
        _visibleWidgets.remove(id);
      }
    });
    _saveVisibleWidgets();
  }

  void _resetWidgetsToDefault() {
    setState(() {
      _visibleWidgets = {
        'kpi_strip',
        'profit_spline',
        'best_sellers',
        'customer_segments',
        'weekly_activity',
        'radial_goal',
        'expiring_batches',
      };
    });
    _saveVisibleWidgets();
  }

  void _openAddWidgetSheet() {
    DashboardAddWidgetSheet.show(
      context,
      visibleWidgetIds: _visibleWidgets,
      onToggleWidget: _toggleWidget,
      onResetDefaults: _resetWidgetsToDefault,
    );
  }

  bool _isTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    return primaryFocus != null && primaryFocus.context?.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Atajo R: Recargar Dashboard
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().loadDashboardData();
        },
        // Atajo W: Abrir panel Add Widget (Shopeers Style)
        const SingleActivator(LogicalKeyboardKey.keyW): () {
          if (_isTextFieldFocused()) return;
          _openAddWidgetSheet();
        },
        // Atajos 1-4: Filtros temporales de ventas
        const SingleActivator(LogicalKeyboardKey.digit1): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.today,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit2): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.thisWeek,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit3): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.thisMonth,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit4): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.allTime,
          );
        },
        // Atajo G o M: Abrir meta de ahorro
        const SingleActivator(LogicalKeyboardKey.keyG): () {
          if (_isTextFieldFocused()) return;
          final cfg = context.read<AppConfigCubit>();
          _DashboardScreenContent._openGoalDialog(
            context,
            cfg.getDouble('admin_goal_current', 0.0),
            cfg.getDouble('admin_goal_target', 2600.0),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          if (_isTextFieldFocused()) return;
          final cfg = context.read<AppConfigCubit>();
          _DashboardScreenContent._openGoalDialog(
            context,
            cfg.getDouble('admin_goal_current', 0.0),
            cfg.getDouble('admin_goal_target', 2600.0),
          );
        },
        // Atajo / : Abrir barra de comandos global
        const SingleActivator(LogicalKeyboardKey.slash): () {
          if (_isTextFieldFocused()) return;
          AdminCommandPaletteDialog.show(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Dashboard',
          showBackButton: false,
          showDrawerButton: true,
          showProfileButton: true,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              if (!kIsWeb) {
                Vibration.vibrate(duration: 50, amplitude: 128);
              }
              await context.read<DashboardCubit>().loadDashboardData();
            },
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state is DashboardInitial || state is DashboardLoading) {
                  return const SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: DashboardSkeleton(),
                  );
                }

                if (state is DashboardError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                () =>
                                    context
                                        .read<DashboardCubit>()
                                        .loadDashboardData(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar conexión'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is DashboardLoaded) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1100;
                      final isTablet = constraints.maxWidth >= 720;

                      if (isDesktop) {
                        return _buildDesktopLayout(context, state);
                      }
                      if (isTablet) {
                        return _buildTabletLayout(context, state);
                      }
                      return _buildMobileLayout(context, state);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SUB-HEADER: CONTEXT BAR (SHOPEERS / APPLE STYLE FECHA + FILTROS + ACCIONES)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildExecutiveSubheader(
    BuildContext context,
    DashboardLoaded state, {
    required bool isDesktop,
  }) {
    if (!isDesktop) {
      // ── MÓVIL: DISEÑO SIMÉTRICO EN 2 FILAS SHOPEERS ─────────────────────────
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Título y Botón Exportar (ambos con balance perfecto)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Métricas en tiempo real',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Generando reporte consolidado del dashboard...',
                        ),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                  label: const Text('Exportar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 2: Cápsula de Fecha Shopeers + Botón +Widget
          Row(
            children: [
              Expanded(
                child: _buildShopeersDateRangePill(
                  context,
                  state,
                  isDesktop: false,
                ),
              ),
              const SizedBox(width: 8),

              // Botón Añadir Widget en móvil (Shopeers exact match)
              InkWell(
                onTap: _openAddWidgetSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Widget (${_visibleWidgets.length})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── DESKTOP / TABLET: FILA ÚNICA CON ALTURA 38DP Y RADIO 10DP ─────────────
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Screen Title & Subtitle
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Métricas clave de rendimiento y control en tiempo real',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Right: Shopeers Date Range Composite Pill + Actions (Exact 38dp height)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShopeersDateRangePill(
              context,
              state,
              isDesktop: true,
            ),
            const SizedBox(width: 10),

            // Botón Añadir Widget (Shopeers Style)
            Tooltip(
              message: 'Personalizar widgets del dashboard (Atajo: W)',
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _openAddWidgetSheet,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(
                    Icons.widgets_outlined,
                    size: 15,
                    color: Color(0xFF2563EB),
                  ),
                  label: Text(
                    'Widgets (${_visibleWidgets.length}/7)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Reload Button with Shortcut Hint
            Tooltip(
              message: 'Recargar métricas (Atajo: R)',
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (!kIsWeb) {
                      Vibration.vibrate(duration: 30, amplitude: 60);
                    }
                    context.read<DashboardCubit>().loadDashboardData();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: Color(0xFF475569),
                  ),
                  label: const Text(
                    'Actualizar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Export Button
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Generando reporte consolidado del dashboard...',
                      ),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, size: 15),
                label: const Text('Exportar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TOP 4 KPIS UNIFORM STRIP (SHOPEERS / APPLE STYLE)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTopKpiStrip(BuildContext context, DashboardLoaded state) {
    return Row(
      children: [
        Expanded(
          child: DashboardKpiStripCard(
            title: 'Ventas Totales',
            value: 'S/ ${state.sales.totalRevenue.toStringAsFixed(2)}',
            deltaText: '15.5%',
            isPositiveDelta: true,
            subtitle: '${state.sales.totalSales} órdenes en período',
            icon: Icons.point_of_sale_rounded,
            accentColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DashboardKpiStripCard(
            title: 'Ticket Promedio',
            value: 'S/ ${state.sales.averageTicket.toStringAsFixed(2)}',
            deltaText: '8.4%',
            isPositiveDelta: true,
            subtitle: 'Gasto medio por orden',
            icon: Icons.calculate_rounded,
            accentColor: const Color(0xFF0D9488),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DashboardKpiStripCard(
            title: 'Stock Total',
            value: '${state.inventory.totalStock} unid.',
            deltaText:
                state.inventory.lowStockProducts > 0
                    ? '${state.inventory.lowStockProducts} alertas'
                    : 'Óptimo',
            isPositiveDelta: state.inventory.lowStockProducts == 0,
            subtitle: '${state.inventory.totalProducts} productos registrados',
            icon: Icons.inventory_2_rounded,
            accentColor: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DashboardKpiStripCard(
            title: 'Ganancia Bruta',
            value: 'S/ ${state.sales.totalProfit.toStringAsFixed(2)}',
            deltaText: '${state.sales.salesMargin.toStringAsFixed(1)}%',
            isPositiveDelta: true,
            subtitle:
                'Reposición: S/ ${state.sales.replacementFund.toStringAsFixed(2)}',
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletKpiGrid(BuildContext context, DashboardLoaded state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardKpiStripCard(
                title: 'Ventas Totales',
                value: 'S/ ${state.sales.totalRevenue.toStringAsFixed(2)}',
                deltaText: '15.5%',
                isPositiveDelta: true,
                subtitle: '${state.sales.totalSales} órdenes en período',
                icon: Icons.point_of_sale_rounded,
                accentColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashboardKpiStripCard(
                title: 'Ticket Promedio',
                value: 'S/ ${state.sales.averageTicket.toStringAsFixed(2)}',
                deltaText: '8.4%',
                isPositiveDelta: true,
                subtitle: 'Gasto promedio por orden',
                icon: Icons.calculate_rounded,
                accentColor: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DashboardKpiStripCard(
                title: 'Stock Total',
                value: '${state.inventory.totalStock} unid.',
                deltaText:
                    state.inventory.lowStockProducts > 0
                        ? '${state.inventory.lowStockProducts} alertas'
                        : 'Óptimo',
                isPositiveDelta: state.inventory.lowStockProducts == 0,
                subtitle:
                    '${state.inventory.totalProducts} productos registrados',
                icon: Icons.inventory_2_rounded,
                accentColor: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashboardKpiStripCard(
                title: 'Ganancia Bruta',
                value: 'S/ ${state.sales.totalProfit.toStringAsFixed(2)}',
                deltaText: '${state.sales.salesMargin.toStringAsFixed(1)}%',
                isPositiveDelta: true,
                subtitle:
                    'Reposición: S/ ${state.sales.replacementFund.toStringAsFixed(2)}',
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP: BENTO GRID INTERNACIONAL (SPLINE PROFIT + ACTIVITY + RADIAL GOAL)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, DashboardLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.inventory.lowStockProducts > 0 ||
                    state.criticalBatches.isNotEmpty) ...[
                  _HealthSummaryBar(
                    lowStockCount: state.inventory.lowStockProducts,
                    criticalBatchesCount: state.criticalBatches.length,
                  ),
                  const SizedBox(height: 16),
                ],

                // Subheader con selector de fecha y acciones rápidas
                _buildExecutiveSubheader(context, state, isDesktop: true),
                const SizedBox(height: 20),

                // Strip superior de 4 KPIs ejecutivos simétricos
                if (_visibleWidgets.contains('kpi_strip')) ...[
                  _buildTopKpiStrip(context, state),
                  const SizedBox(height: 24),
                ],

                // Bento Grid Principal Modulado
                if (!_hasAnyBodyWidgets(state))
                  _buildEmptyWidgetsPlaceholder()
                else
                  _buildDesktopBentoGrid(context, state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _hasAnyBodyWidgets(DashboardLoaded state) {
    return _visibleWidgets.contains('profit_spline') ||
        _visibleWidgets.contains('best_sellers') ||
        (_visibleWidgets.contains('customer_segments') &&
            state.topCustomers.isNotEmpty) ||
        _visibleWidgets.contains('weekly_activity') ||
        _visibleWidgets.contains('radial_goal') ||
        (_visibleWidgets.contains('expiring_batches') &&
            state.criticalBatches.isNotEmpty);
  }

  Widget _buildDesktopBentoGrid(BuildContext context, DashboardLoaded state) {
    final leftWidgets = <Widget>[
      if (_visibleWidgets.contains('profit_spline'))
        DashboardSplineChartCard(
          sales: state.sales,
          inventory: state.inventory,
        ),
      if (_visibleWidgets.contains('best_sellers'))
        DashboardBestSellersTable(
          bestSellers: state.sales.bestSellers,
          criticalBatches: state.criticalBatches,
        ),
      if (_visibleWidgets.contains('customer_segments') &&
          state.topCustomers.isNotEmpty)
        TopCustomersCard(
          customers: state.topCustomers,
          displayMode: TopCustomersDisplayMode.desktop,
        ),
    ];

    final rightWidgets = <Widget>[
      if (_visibleWidgets.contains('weekly_activity'))
        DashboardWeeklyActivityCard(
          sales: state.sales,
        ),
      if (_visibleWidgets.contains('radial_goal'))
        const _DashboardAdminGoalCard(),
      if (_visibleWidgets.contains('expiring_batches') &&
          state.criticalBatches.isNotEmpty)
        ExpiringBatchesCard(
          batches: state.criticalBatches,
        ),
    ];

    if (leftWidgets.isEmpty && rightWidgets.isEmpty) {
      return _buildEmptyWidgetsPlaceholder();
    }

    if (leftWidgets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacers(rightWidgets, 20),
      );
    }

    if (rightWidgets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacers(leftWidgets, 20),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacers(leftWidgets, 20),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacers(rightWidgets, 20),
          ),
        ),
      ],
    );
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

  Widget _buildEmptyWidgetsPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.dashboard_customize_outlined,
                size: 28,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lienzo de Dashboard Vacío',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Has ocultado los componentes del lienzo. Personaliza tu vista añadiendo widgets clave.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openAddWidgetSheet,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLET: HYBRID EFFICIENCY (2-COLUMN RESPONSIVE)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(BuildContext context, DashboardLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.inventory.lowStockProducts > 0 ||
                    state.criticalBatches.isNotEmpty) ...[
                  _HealthSummaryBar(
                    lowStockCount: state.inventory.lowStockProducts,
                    criticalBatchesCount: state.criticalBatches.length,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildExecutiveSubheader(context, state, isDesktop: false),
                const SizedBox(height: 16),
                if (_visibleWidgets.contains('kpi_strip')) ...[
                  _buildTabletKpiGrid(context, state),
                  const SizedBox(height: 20),
                ],
                if (!_hasAnyBodyWidgets(state))
                  _buildEmptyWidgetsPlaceholder()
                else
                  _buildDesktopBentoGrid(context, state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE: APPLE HIG / IOS PREMIUM (THUMB-ZONE FIRST + FLUID SCROLL)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, DashboardLoaded state) {
    final mobileWidgets = <Widget>[
      if (state.inventory.lowStockProducts > 0 ||
          state.criticalBatches.isNotEmpty) ...[
        _HealthSummaryBar(
          lowStockCount: state.inventory.lowStockProducts,
          criticalBatchesCount: state.criticalBatches.length,
        ),
      ],
      _buildExecutiveSubheader(context, state, isDesktop: false),
      if (_visibleWidgets.contains('kpi_strip'))
        _buildTabletKpiGrid(context, state),
      if (_visibleWidgets.contains('profit_spline'))
        DashboardSplineChartCard(
          sales: state.sales,
          inventory: state.inventory,
        ),
      if (_visibleWidgets.contains('customer_segments') &&
          state.topCustomers.isNotEmpty)
        TopCustomersCard(
          customers: state.topCustomers,
          displayMode: TopCustomersDisplayMode.mobile,
        ),
      if (_visibleWidgets.contains('weekly_activity'))
        DashboardWeeklyActivityCard(
          sales: state.sales,
        ),
      if (_visibleWidgets.contains('radial_goal'))
        const _DashboardAdminGoalCard(),
      if (_visibleWidgets.contains('best_sellers'))
        DashboardBestSellersTable(
          bestSellers: state.sales.bestSellers,
          criticalBatches: state.criticalBatches,
        ),
      if (_visibleWidgets.contains('expiring_batches') &&
          state.criticalBatches.isNotEmpty)
        ExpiringBatchesCard(
          batches: state.criticalBatches,
        ),
      if (!_hasAnyWidgetsVisible(state))
        _buildEmptyWidgetsPlaceholder(),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _withSpacers(mobileWidgets, 16),
            ),
          ),
        ),
      ],
    );
  }

  bool _hasAnyWidgetsVisible(DashboardLoaded state) {
    return _visibleWidgets.contains('kpi_strip') || _hasAnyBodyWidgets(state);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SELECTOR DE FECHAS Y RANGOS PERSONALIZADOS (SHOPEERS STYLE)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _openCustomDatePicker(
    BuildContext context,
    DashboardLoaded state,
  ) async {
    final now = DateTime.now();
    final initialRange = (state.customStartDate != null && state.customEndDate != null)
        ? DateTimeRange(start: state.customStartDate!, end: state.customEndDate!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2022),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SELECCIONAR RANGO DE FECHAS',
      cancelText: 'CANCELAR',
      confirmText: 'APLICAR',
      saveText: 'APLICAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 30, amplitude: 64);
      }
      if (context.mounted) {
        context.read<DashboardCubit>().updateSalesFilter(
          SalesTimeFilter.custom,
          customStartDate: picked.start,
          customEndDate: picked.end,
        );
      }
    }
  }

  Widget _buildShopeersDateRangePill(
    BuildContext context,
    DashboardLoaded state, {
    required bool isDesktop,
  }) {
    final now = DateTime.now();
    String rangeLabel = '';
    String presetLabel = '';

    switch (state.salesFilter) {
      case SalesTimeFilter.today:
        rangeLabel = DateFormat('d MMM, yyyy', 'es').format(now);
        presetLabel = 'Hoy';
        break;
      case SalesTimeFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        rangeLabel =
            '${DateFormat('d MMM', 'es').format(startOfWeek)} - ${DateFormat('d MMM, yyyy', 'es').format(endOfWeek)}';
        presetLabel = isDesktop ? 'Esta semana' : 'Semana';
        break;
      case SalesTimeFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final nextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final endOfMonth = nextMonth.subtract(const Duration(days: 1));
        rangeLabel =
            '${DateFormat('d MMM', 'es').format(startOfMonth)} - ${DateFormat('d MMM, yyyy', 'es').format(endOfMonth)}';
        presetLabel = isDesktop ? 'Este mes' : 'Mes';
        break;
      case SalesTimeFilter.allTime:
        rangeLabel = 'Todo el histórico';
        presetLabel = isDesktop ? 'Histórico' : 'Hist';
        break;
      case SalesTimeFilter.custom:
        if (state.customStartDate != null && state.customEndDate != null) {
          rangeLabel =
              '${DateFormat('d MMM', 'es').format(state.customStartDate!)} - ${DateFormat('d MMM, yyyy', 'es').format(state.customEndDate!)}';
        } else {
          rangeLabel = 'Personalizado';
        }
        presetLabel = isDesktop ? 'Personalizado' : 'Pers';
        break;
    }

    return Container(
      height: isDesktop ? 38 : 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left: Calendar Picker Trigger
          Flexible(
            child: InkWell(
              onTap: () => _openCustomDatePicker(context, state),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        rangeLabel,
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: isDesktop ? 18 : 16,
            color: const Color(0xFFE2E8F0),
          ),

          // Right: Presets Dropdown
          PopupMenuButton<SalesTimeFilter>(
            tooltip: 'Filtro por fecha (Atajos: 1-4)',
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            elevation: 8,
            onSelected: (filter) {
              if (filter == SalesTimeFilter.custom) {
                _openCustomDatePicker(context, state);
              } else {
                if (!kIsWeb) {
                  Vibration.vibrate(duration: 30, amplitude: 64);
                }
                context.read<DashboardCubit>().updateSalesFilter(filter);
              }
            },
            itemBuilder: (context) => [
              _buildFilterMenuItem(
                value: SalesTimeFilter.today,
                label: 'Hoy',
                shortcut: '1',
                isSelected: state.salesFilter == SalesTimeFilter.today,
              ),
              _buildFilterMenuItem(
                value: SalesTimeFilter.thisWeek,
                label: 'Esta semana',
                shortcut: '2',
                isSelected: state.salesFilter == SalesTimeFilter.thisWeek,
              ),
              _buildFilterMenuItem(
                value: SalesTimeFilter.thisMonth,
                label: 'Este mes',
                shortcut: '3',
                isSelected: state.salesFilter == SalesTimeFilter.thisMonth,
              ),
              _buildFilterMenuItem(
                value: SalesTimeFilter.allTime,
                label: 'Histórico',
                shortcut: '4',
                isSelected: state.salesFilter == SalesTimeFilter.allTime,
              ),
              const PopupMenuDivider(height: 1),
              _buildFilterMenuItem(
                value: SalesTimeFilter.custom,
                label: 'Personalizado...',
                icon: Icons.date_range_outlined,
                isSelected: state.salesFilter == SalesTimeFilter.custom,
              ),
            ],
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    presetLabel,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SalesTimeFilter> _buildFilterMenuItem({
    required SalesTimeFilter value,
    required String label,
    String? shortcut,
    IconData? icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<SalesTimeFilter>(
      value: value,
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (shortcut != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          if (isSelected && shortcut == null)
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }
}

class _HealthSummaryBar extends StatefulWidget {
  final int lowStockCount;
  final int criticalBatchesCount;

  const _HealthSummaryBar({
    required this.lowStockCount,
    required this.criticalBatchesCount,
  });

  @override
  State<_HealthSummaryBar> createState() => _HealthSummaryBarState();
}

class _HealthSummaryBarState extends State<_HealthSummaryBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 3),
    ]).animate(_controller);

    if (widget.lowStockCount > 0 || widget.criticalBatchesCount > 0) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HealthSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lowStockCount > 0 || widget.criticalBatchesCount > 0) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lowStockCount == 0 && widget.criticalBatchesCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Text(
              'Inventario y Lotes Saludables · Cero Alertas Críticas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final totalAlerts = widget.lowStockCount + widget.criticalBatchesCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalAlerts Alertas de Salud Operativa',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.lowStockCount} stock bajo · ${widget.criticalBatchesCount} lotes próximos a vencer',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (widget.criticalBatchesCount > 0) {
                context.push('/inventory/batches');
              } else {
                context.push('/inventory');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(44, 38),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Revisar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpiringBatchesCard extends StatelessWidget {
  final List<Map<String, dynamic>> batches;
  final VoidCallback? onHide;

  const ExpiringBatchesCard({super.key, required this.batches, this.onHide});

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) return const SizedBox.shrink();

    final urgent = batches.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        boxShadow: AppColors.cardShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timelapse_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lotes Críticos por Vencer (FEFO)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${batches.length} lote(s) requieren rotación prioritaria',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: urgent.length,
            separatorBuilder:
                (context, index) =>
                    const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final b = urgent[index];
              final days = b['days_until_expiration'] as int? ?? 0;
              final code = b['batch_code'] as String? ?? 'N/A';
              final prod = b['product_name'] as String? ?? 'Producto';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Lote: $code',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            days <= 7
                                ? AppColors.error.withValues(alpha: 0.12)
                                : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        days <= 0
                            ? 'Vencido'
                            : days == 1
                            ? '1 día'
                            : '$days días',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: days <= 7 ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (batches.length > 3) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => context.push('/inventory/batches'),
                child: Text(
                  'Ver todos los lotes (${batches.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardAdminGoalCard extends StatelessWidget {
  const _DashboardAdminGoalCard();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppConfigCubit, AppConfigState, (double, double)>(
      selector: (_) {
        final config = context.read<AppConfigCubit>();
        return (
          config.getDouble('admin_goal_current', 0.0),
          config.getDouble('admin_goal_target', 2600.0),
        );
      },
      builder: (context, goal) {
        return DashboardRadialGoalCard(
          currentAmount: goal.$1,
          targetAmount: goal.$2,
          onConfigure:
              () => _DashboardScreenContent._openGoalDialog(
                context,
                goal.$1,
                goal.$2,
              ),
        );
      },
    );
  }
}
