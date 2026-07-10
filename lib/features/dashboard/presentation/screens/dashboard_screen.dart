import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/enums/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_skeleton.dart';

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

  void _openGoalDialog(
    BuildContext context,
    double currentAmount,
    double targetAmount,
  ) {
    final config = context.read<AppConfigCubit>();
    double newCurrent = currentAmount;
    double newTarget = targetAmount;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Configurar Meta',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: targetAmount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Meta Total (S/)',
                  prefixText: 'S/ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged:
                    (val) => newTarget = double.tryParse(val) ?? newTarget,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: currentAmount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Ahorro Actual (S/)',
                  prefixText: 'S/ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged:
                    (val) => newCurrent = double.tryParse(val) ?? newCurrent,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await config.saveValue('admin_goal_target', newTarget);
                await config.saveValue('admin_goal_current', newCurrent);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final adminGoalTarget = config.getDouble('admin_goal_target', 2600.0);
    final adminGoalCurrent = config.getDouble('admin_goal_current', 0.0);

    return AdminLayout(
      title: 'Dashboard Financiero',
      showBackButton: true,
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
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.read<DashboardCubit>().loadDashboardData(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      )
                    ],
                  ),
                ),
              );
            }

            if (state is DashboardLoaded) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 720;
                  if (isTablet) {
                    return _buildTabletLayout(context, adminGoalCurrent, adminGoalTarget, state);
                  }
                  return _buildMobileLayout(context, adminGoalCurrent, adminGoalTarget, state);
                },
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, double goalCurrent, double goalTarget, DashboardLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HealthSummaryBar(
                        lowStockCount: state.inventory.lowStockProducts,
                        criticalBatchesCount: state.criticalBatches.length,
                      ),
                      const SizedBox(height: 16),
                      AdminGoalCard(
                        currentAmount: goalCurrent,
                        targetAmount: goalTarget,
                        onAddPressed: () => _openGoalDialog(context, goalCurrent, goalTarget),
                      ),
                      const SizedBox(height: 24),
                      if (state.criticalBatches.isNotEmpty) ...[
                        ExpiringBatchesCard(batches: state.criticalBatches),
                        const SizedBox(height: 24),
                      ],
                      const SectionHeader(
                        icon: Icons.inventory_2_rounded,
                        title: 'Inventario',
                        subtitle: 'Valorización y proyecciones de stock',
                      ),
                      const SizedBox(height: 12),
                      _buildInventoryContent(state.inventory),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        icon: Icons.point_of_sale_rounded,
                        title: 'Ventas Registradas',
                        subtitle: 'Órdenes con estado COMPLETADO',
                      ),
                      const SizedBox(height: 8),
                      _buildSalesFilters(context, state),
                      const SizedBox(height: 16),
                      _buildSalesContent(state.sales, state.isSalesLoading),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, double goalCurrent, double goalTarget, DashboardLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _HealthSummaryBar(
                lowStockCount: state.inventory.lowStockProducts,
                criticalBatchesCount: state.criticalBatches.length,
              ),
              const SizedBox(height: 16),
              AdminGoalCard(
                currentAmount: goalCurrent,
                targetAmount: goalTarget,
                onAddPressed: () => _openGoalDialog(context, goalCurrent, goalTarget),
              ),
              const SizedBox(height: 24),
              if (state.criticalBatches.isNotEmpty) ...[
                ExpiringBatchesCard(batches: state.criticalBatches),
                const SizedBox(height: 24),
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
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Ventas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Órdenes COMPLETADAS',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverToBoxAdapter(
            child: _buildSalesContent(state.sales, state.isSalesLoading),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesFilters(BuildContext context, DashboardLoaded state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SegmentedButton<SalesTimeFilter>(
          segments: const [
            ButtonSegment(value: SalesTimeFilter.today, label: Text('Hoy')),
            ButtonSegment(value: SalesTimeFilter.thisWeek, label: Text('Sem')),
            ButtonSegment(value: SalesTimeFilter.thisMonth, label: Text('Mes')),
            ButtonSegment(value: SalesTimeFilter.allTime, label: Text('Hist')),
          ],
          selected: {state.salesFilter},
          onSelectionChanged: (set) {
            if (!kIsWeb) {
              Vibration.vibrate(duration: 30, amplitude: 64);
            }
            context.read<DashboardCubit>().updateSalesFilter(set.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesContent(SalesMetricsEntity sales, bool isSalesLoading) {
    if (isSalesLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return Column(
      children: [
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
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: KpiCard(
                title: 'Ticket Promedio',
                value: 'S/ ',
                subtitle: 'Gasto por cliente',
                icon: Icons.calculate_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.teal, AppColors.teal.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCardWide(
                title: 'Ingresos Netos',
                value: 'S/ ',
                subtitle: 'Total facturado en el periodo',
                icon: Icons.attach_money_rounded,
                color: AppColors.success,
                rightLabel: 'Fondo Reposición',
                rightValue: 'S/ ',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GananciaBrutaCard(
          gananciaBruta: sales.totalProfit,
          inversion: sales.replacementFund,
          margenPct: sales.salesMargin,
          sparklineData: const [], 
        ),
      ],
    );
  }

  Widget _buildInventoryContent(InventoryMetricsEntity inventory) {
    return Column(
      children: [
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
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KpiCard(
                title: 'Stock Total',
                value: inventory.totalStock.toString(),
                subtitle: 'Unidades en tiendas',
                icon: Icons.widgets_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.teal, AppColors.teal.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        KpiCardWide(
          title: 'Valorización al Público',
          value: 'S/ ',
          subtitle: 'Precio total del stock actual',
          icon: Icons.storefront_rounded,
          color: AppColors.info,
          rightLabel: '',
          rightValue: '',
        ),
        const SizedBox(height: 8),
        GananciaBrutaCard(
          gananciaBruta: inventory.expectedMaxProfit,
          inversion: inventory.totalInvestment,
          margenPct: inventory.grossMargin,
          sparklineData: const [1.0, 1.5, 1.2, 2.0, 2.8, 2.4, 3.5, 4.0, 3.8, 5.0],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'G. Público',
                value: 'S/ ',
                subtitle: 'Aplicando precio al público',
                icon: Icons.trending_up_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.teal, AppColors.teal.withValues(alpha: 0.8)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                title: 'G. Mayorista',
                value: 'S/ ',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
              'Todo bajo control. No hay alertas para hoy.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atención requerida',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (widget.lowStockCount > 0)
                      '${widget.lowStockCount} bajo stock',
                    if (widget.criticalBatchesCount > 0)
                      '${widget.criticalBatchesCount} lotes críticos',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/admin/inventory'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: child,
    );
  }

  @override
  double get maxExtent => 70.0;

  @override
  double get minExtent => 70.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
