import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_executive_widgets.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/admin_goal_dialog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers_card.dart';
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

class _DashboardScreenContent extends StatelessWidget {
  const _DashboardScreenContent();

  bool _isTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    return primaryFocus != null && primaryFocus.context?.widget is EditableText;
  }

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
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: AppColors.surface,
            elevation: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                  // Drag handle
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
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
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Atajo R: Recargar Dashboard
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().loadDashboardData();
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
          _openGoalDialog(
            context,
            cfg.getDouble('admin_goal_current', 0.0),
            cfg.getDouble('admin_goal_target', 2600.0),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          if (_isTextFieldFocused()) return;
          final cfg = context.read<AppConfigCubit>();
          _openGoalDialog(
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
          actions: [
            // Botón rápido de recarga en el header con tooltip de atajo [R]
            Tooltip(
              message: 'Recargar métricas (Atajo: R)',
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async {
                  if (!kIsWeb) {
                    Vibration.vibrate(duration: 40, amplitude: 90);
                  }
                  await context.read<DashboardCubit>().loadDashboardData();
                },
              ),
            ),
          ],
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
    final now = DateTime.now();
    final dateStr = DateFormat('d MMM, yyyy', 'es').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Left: Screen Title & Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Métricas clave de rendimiento y control en tiempo real',
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Right: Date Range + Filters + Actions
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              // Date Range Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Segmented Pill
              _buildSalesFilters(context, state, isDesktop: isDesktop),

              // Reload Button with Shortcut Hint
              Tooltip(
                message: 'Recargar métricas (Atajo: R)',
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!kIsWeb) {
                        Vibration.vibrate(duration: 30, amplitude: 60);
                      }
                      context.read<DashboardCubit>().loadDashboardData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Actualizar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Export Button
              FilledButton.icon(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
            ],
          ),
        ],
      ),
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
                _buildTopKpiStrip(context, state),
                const SizedBox(height: 24),

                // Bento Grid Principal (60% / 40% Split)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda (Flex 7): Spline Chart + Best Sellers Table + Clientes Top
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DashboardSplineChartCard(
                            sales: state.sales,
                            inventory: state.inventory,
                          ),
                          const SizedBox(height: 20),
                          DashboardBestSellersTable(
                            criticalBatches: state.criticalBatches,
                          ),
                          if (state.topCustomers.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            TopCustomersCard(
                              customers: state.topCustomers,
                              displayMode: TopCustomersDisplayMode.desktop,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Columna Derecha (Flex 5): Actividad Semanal + Radial Goal + Asistente IA + Lotes
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DashboardWeeklyActivityCard(),
                          const SizedBox(height: 20),
                          const _DashboardAdminGoalCard(),
                          const SizedBox(height: 20),
                          const DashboardAiAssistantCard(),
                          if (state.criticalBatches.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            ExpiringBatchesCard(batches: state.criticalBatches),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
                _buildTabletKpiGrid(context, state),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DashboardSplineChartCard(
                            sales: state.sales,
                            inventory: state.inventory,
                          ),
                          const SizedBox(height: 20),
                          DashboardBestSellersTable(
                            criticalBatches: state.criticalBatches,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DashboardWeeklyActivityCard(),
                          const SizedBox(height: 16),
                          const _DashboardAdminGoalCard(),
                          if (state.criticalBatches.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ExpiringBatchesCard(batches: state.criticalBatches),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
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
              _buildTabletKpiGrid(context, state),
              const SizedBox(height: 16),
              DashboardSplineChartCard(
                sales: state.sales,
                inventory: state.inventory,
              ),
              const SizedBox(height: 16),
              const _DashboardAdminGoalCard(),
              const SizedBox(height: 16),
              const DashboardWeeklyActivityCard(),
              const SizedBox(height: 16),
              DashboardBestSellersTable(criticalBatches: state.criticalBatches),
              if (state.criticalBatches.isNotEmpty) ...[
                const SizedBox(height: 16),
                ExpiringBatchesCard(batches: state.criticalBatches),
              ],
              if (state.topCustomers.isNotEmpty) ...[
                const SizedBox(height: 16),
                TopCustomersCard(
                  customers: state.topCustomers,
                  displayMode: TopCustomersDisplayMode.mobile,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FILTROS DE TIEMPO CON INDICADORES DE TECLADO EN DESKTOP
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSalesFilters(
    BuildContext context,
    DashboardLoaded state, {
    bool isDesktop = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: SegmentedButton<SalesTimeFilter>(
        segments: [
          ButtonSegment(
            value: SalesTimeFilter.today,
            label: Text(isDesktop ? 'Hoy [1]' : 'Hoy'),
            tooltip: isDesktop ? 'Filtrar por hoy (Atajo: 1)' : null,
          ),
          ButtonSegment(
            value: SalesTimeFilter.thisWeek,
            label: Text(isDesktop ? 'Sem [2]' : 'Sem'),
            tooltip: isDesktop ? 'Filtrar por semana (Atajo: 2)' : null,
          ),
          ButtonSegment(
            value: SalesTimeFilter.thisMonth,
            label: Text(isDesktop ? 'Mes [3]' : 'Mes'),
            tooltip: isDesktop ? 'Filtrar por mes (Atajo: 3)' : null,
          ),
          ButtonSegment(
            value: SalesTimeFilter.allTime,
            label: Text(isDesktop ? 'Hist [4]' : 'Hist'),
            tooltip: isDesktop ? 'Filtrar histórico (Atajo: 4)' : null,
          ),
        ],
        selected: {state.salesFilter},
        showSelectedIcon: false,
        onSelectionChanged: (set) {
          if (!kIsWeb) {
            Vibration.vibrate(duration: 30, amplitude: 64);
          }
          context.read<DashboardCubit>().updateSalesFilter(set.first);
        },
        style: ButtonStyle(
          visualDensity:
              isDesktop ? VisualDensity.compact : VisualDensity.comfortable,
          tapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.textSecondary;
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
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
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              'Todo bajo control. No hay alertas de stock ni vencimiento para hoy.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    void onReview() {
      if (widget.lowStockCount > 0) {
        context.go('/inventory?filter=low_stock');
      } else if (widget.criticalBatchesCount > 0) {
        context.go('/inventory?tab=batches&filter=critico');
      } else {
        context.go('/inventory');
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onReview,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                RepaintBoundary(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Atención requerida en almacén',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (widget.lowStockCount > 0)
                            '${widget.lowStockCount} productos bajo stock',
                          if (widget.criticalBatchesCount > 0)
                            '${widget.criticalBatchesCount} lotes próximos a vencer',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onReview,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text(
                    'Revisar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
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
