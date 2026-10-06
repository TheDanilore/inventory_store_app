import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/admin_goal_dialog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers_card.dart';
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
          context.read<DashboardCubit>().updateSalesFilter(SalesTimeFilter.today);
        },
        const SingleActivator(LogicalKeyboardKey.digit2): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(SalesTimeFilter.thisWeek);
        },
        const SingleActivator(LogicalKeyboardKey.digit3): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(SalesTimeFilter.thisMonth);
        },
        const SingleActivator(LogicalKeyboardKey.digit4): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(SalesTimeFilter.allTime);
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
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Dashboard',
          showBackButton: true,
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
                            onPressed: () => context
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
                        return _buildDesktopLayout(
                          context,
                          state,
                        );
                      }
                      if (isTablet) {
                        return _buildTabletLayout(
                          context,
                          state,
                        );
                      }
                      return _buildMobileLayout(
                        context,
                        state,
                      );
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
  // DESKTOP: PRO POWER-USER ERP TOOL (HERO 4-KPIS + BALANCED 2-COL + TOP CLIENTS)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(
    BuildContext context,
    DashboardLoaded state,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HealthSummaryBar(
                  lowStockCount: state.inventory.lowStockProducts,
                  criticalBatchesCount: state.criticalBatches.length,
                ),
                const SizedBox(height: 20),

                // FILA HERO SUPERIOR (4 KPIs ejecutivos con balance visual)
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Ventas Totales',
                        value: state.sales.totalSales.toString(),
                        subtitle: 'Órdenes en período',
                        icon: Icons.receipt_long_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KpiCard(
                        title: 'Ticket Promedio',
                        value: 'S/ ${state.sales.averageTicket.toStringAsFixed(2)}',
                        subtitle: 'Gasto medio por orden',
                        icon: Icons.calculate_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.teal,
                            AppColors.teal.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KpiCard(
                        title: 'Stock Total',
                        value: state.inventory.totalStock.toString(),
                        subtitle: '${state.inventory.totalProducts} productos activos',
                        icon: Icons.inventory_2_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.info,
                            AppColors.info.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _DashboardAdminGoalCard(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // CUERPO PRINCIPAL (Simetría balanceada 6:6)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Tracción de Ventas y Clientes VIP
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SectionHeader(
                                icon: Icons.point_of_sale_rounded,
                                title: 'Ventas Registradas',
                                subtitle: 'Facturación con estado COMPLETADO',
                              ),
                              _buildSalesFilters(context, state, isDesktop: true),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildSalesContent(
                            state.sales,
                            state.isSalesLoading,
                            showKpiRow: false,
                          ),
                          const SizedBox(height: 24),
                          // NUEVA SECCIÓN ESTELAR: CLIENTES QUE MÁS COMPRAN
                          TopCustomersCard(
                            customers: state.topCustomers,
                            displayMode: TopCustomersDisplayMode.desktop,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Columna Derecha: Inventario, Lotes y Proyecciones de Margen
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.criticalBatches.isNotEmpty) ...[
                            ExpiringBatchesCard(batches: state.criticalBatches),
                            const SizedBox(height: 20),
                          ],
                          const SectionHeader(
                            icon: Icons.bar_chart_rounded,
                            title: 'Inventario & Proyecciones',
                            subtitle: 'Valorización y margen bruto estimado',
                          ),
                          const SizedBox(height: 14),
                          _buildInventoryContent(
                            state.inventory,
                            showKpiRow: false,
                          ),
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
  // TABLET: HYBRID EFFICIENCY (BALANCED 2-COL + MODALS CONSTRAINED)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(
    BuildContext context,
    DashboardLoaded state,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HealthSummaryBar(
                  lowStockCount: state.inventory.lowStockProducts,
                  criticalBatchesCount: state.criticalBatches.length,
                ),
                const SizedBox(height: 16),
                const _DashboardAdminGoalCard(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            icon: Icons.point_of_sale_rounded,
                            title: 'Ventas',
                            subtitle: 'Órdenes completadas',
                          ),
                          const SizedBox(height: 12),
                          _buildSalesFilters(context, state),
                          const SizedBox(height: 14),
                          _buildSalesContent(state.sales, state.isSalesLoading),
                          const SizedBox(height: 20),
                          TopCustomersCard(
                            customers: state.topCustomers,
                            displayMode: TopCustomersDisplayMode.tablet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.criticalBatches.isNotEmpty) ...[
                            ExpiringBatchesCard(batches: state.criticalBatches),
                            const SizedBox(height: 20),
                          ],
                          const SectionHeader(
                            icon: Icons.inventory_2_rounded,
                            title: 'Inventario',
                            subtitle: 'Stock y márgenes',
                          ),
                          const SizedBox(height: 12),
                          _buildInventoryContent(state.inventory),
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
  // MOBILE: APPLE HIG / IOS PREMIUM (THUMB-ZONE FIRST + BOTTOMSHEET GESTURES)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    DashboardLoaded state,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _HealthSummaryBar(
                lowStockCount: state.inventory.lowStockProducts,
                criticalBatchesCount: state.criticalBatches.length,
              ),
              const SizedBox(height: 16),
              const _DashboardAdminGoalCard(),
              const SizedBox(height: 20),
              if (state.criticalBatches.isNotEmpty) ...[
                ExpiringBatchesCard(batches: state.criticalBatches),
                const SizedBox(height: 20),
              ],
              const SectionHeader(
                icon: Icons.inventory_2_rounded,
                title: 'Inventario',
                subtitle: 'Valorización y proyecciones de stock',
              ),
              const SizedBox(height: 12),
              _buildInventoryContent(state.inventory),
            ]),
          ),
        ),
        // Sticky Header de Ventas con Filtros táctiles optimizados
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ventas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Órdenes COMPLETADAS',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSalesFilters(context, state),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSalesContent(state.sales, state.isSalesLoading),
              const SizedBox(height: 24),
              // Clientes destacados en móvil
              TopCustomersCard(
                customers: state.topCustomers,
                displayMode: TopCustomersDisplayMode.mobile,
              ),
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
          visualDensity: isDesktop ? VisualDensity.compact : VisualDensity.comfortable,
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

  Widget _buildSalesContent(
    SalesMetricsEntity sales,
    bool isSalesLoading, {
    bool showKpiRow = true,
  }) {
    if (isSalesLoading) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return Column(
      children: [
        if (showKpiRow) ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: KpiCard(
                  title: 'Ventas Totales',
                  value: sales.totalSales.toString(),
                  subtitle: 'Órdenes despachadas',
                  icon: Icons.receipt_long_rounded,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: KpiCard(
                  title: 'Ticket Promedio',
                  value: 'S/ ${sales.averageTicket.toStringAsFixed(2)}',
                  subtitle: 'Gasto por cliente',
                  icon: Icons.calculate_rounded,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.teal,
                      AppColors.teal.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: KpiCardWide(
                title: 'Ingresos Netos',
                value: 'S/ ${sales.totalRevenue.toStringAsFixed(2)}',
                subtitle: 'Total facturado en el periodo',
                icon: Icons.attach_money_rounded,
                color: AppColors.success,
                rightLabel: 'Fondo Reposición',
                rightValue: 'S/ ${sales.replacementFund.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GananciaBrutaCard(
          gananciaBruta: sales.totalProfit,
          inversion: sales.replacementFund,
          margenPct: sales.salesMargin,
          sparklineData: const [],
        ),
      ],
    );
  }

  Widget _buildInventoryContent(
    InventoryMetricsEntity inventory, {
    bool showKpiRow = true,
  }) {
    return Column(
      children: [
        if (showKpiRow) ...[
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: 'Catálogo',
                  value: inventory.totalProducts.toString(),
                  subtitle: 'Productos activos',
                  icon: Icons.category_rounded,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  title: 'Stock Total',
                  value: inventory.totalStock.toString(),
                  subtitle: 'Unidades en tiendas',
                  icon: Icons.widgets_rounded,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.teal,
                      AppColors.teal.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        KpiCardWide(
          title: 'Valorización al Público',
          value: 'S/ ${inventory.retailValue.toStringAsFixed(2)}',
          subtitle: 'Precio total del stock actual',
          icon: Icons.storefront_rounded,
          color: AppColors.info,
          rightLabel: 'Inversión Total',
          rightValue: 'S/ ${inventory.totalInvestment.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 10),
        GananciaBrutaCard(
          gananciaBruta: inventory.expectedMaxProfit,
          inversion: inventory.totalInvestment,
          margenPct: inventory.grossMargin,
          sparklineData: const [
            1.0,
            1.5,
            1.2,
            2.0,
            2.8,
            2.4,
            3.5,
            4.0,
            3.8,
            5.0,
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'G. Público',
                value: 'S/ ${inventory.expectedMaxProfit.toStringAsFixed(2)}',
                subtitle: 'Aplicando precio al público',
                icon: Icons.trending_up_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.teal,
                    AppColors.teal.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                title: 'G. Mayorista',
                value: 'S/ ${inventory.expectedMinProfit.toStringAsFixed(2)}',
                subtitle: 'Aplicando precio por mayor',
                icon: Icons.people_alt_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
            ),
          ],
        ),
      ],
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _StickyHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: child,
    );
  }

  @override
  double get maxExtent => 68.0;

  @override
  double get minExtent => 68.0;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
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
        return AdminGoalCard(
          currentAmount: goal.$1,
          targetAmount: goal.$2,
          onAddPressed: () => _DashboardScreenContent._openGoalDialog(
            context,
            goal.$1,
            goal.$2,
          ),
        );
      },
    );
  }
}

