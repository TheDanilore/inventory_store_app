import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/core/providers/app_config_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/dashboard/data/repositories/dashboard_service.dart';
import 'package:inventory_store_app/features/dashboard/presentation/screens/widgets/dashboard/dashboard_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/screens/widgets/dashboard/dashboard_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  bool _isLoading = true;
  bool _isSalesLoading = false;

  InventoryMetrics? _inventory;
  SalesMetrics? _sales;
  List<Map<String, dynamic>> _batches = [];
  int _criticalBatchesCount = 0;
  SalesTimeFilter _salesFilter = SalesTimeFilter.today;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _dashboardService.getInventoryMetrics(),
        _dashboardService.getSalesMetrics(_salesFilter),
        _dashboardService.getExpiringBatches(),
      ]);

      if (mounted) {
        setState(() {
          _inventory = results[0] as InventoryMetrics;
          _sales = results[1] as SalesMetrics;
          _batches = results[2] as List<Map<String, dynamic>>;

          final now = DateTime.now();
          _criticalBatchesCount =
              _batches.where((b) {
                final expiryDateStr = b['expiry_date'] as String?;
                if (expiryDateStr == null) return false;
                final expiry = DateTime.tryParse(expiryDateStr);
                if (expiry == null) return false;
                return expiry.isBefore(now) ||
                    expiry.difference(now).inDays <= 7;
              }).length;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onFilterChanged(SalesTimeFilter filter) async {
    if (_salesFilter == filter) return;

    if (!kIsWeb) {
      Vibration.vibrate(duration: 30, amplitude: 64);
    }

    setState(() {
      _salesFilter = filter;
      _isSalesLoading = true;
    });

    try {
      final newSales = await _dashboardService.getSalesMetrics(filter);
      if (mounted) {
        setState(() {
          _sales = newSales;
          _isSalesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSalesLoading = false);
      }
    }
  }

  String _filterName(SalesTimeFilter filter) {
    switch (filter) {
      case SalesTimeFilter.today:
        return 'Hoy';
      case SalesTimeFilter.thisWeek:
        return 'Esta Sem';
      case SalesTimeFilter.thisMonth:
        return 'Este Mes';
      case SalesTimeFilter.allTime:
        return 'Histórico';
    }
  }

  void _openGoalDialog(
    BuildContext context,
    double currentAmount,
    double targetAmount,
  ) {
    final config = context.read<AppConfigProvider>();
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
    final config = context.watch<AppConfigProvider>();
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
          await _loadAllData();
        },
        child:
            _isLoading
                ? const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: DashboardSkeleton(),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 720;
                    if (isTablet) {
                      return _buildTabletLayout(
                        adminGoalCurrent,
                        adminGoalTarget,
                      );
                    }
                    return _buildMobileLayout(
                      adminGoalCurrent,
                      adminGoalTarget,
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildTabletLayout(double goalCurrent, double goalTarget) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Alertas e Inventario
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_inventory != null)
                        _HealthSummaryBar(
                          lowStockCount: _inventory!.lowStockProducts,
                          criticalBatchesCount: _criticalBatchesCount,
                        ),
                      const SizedBox(height: 16),
                      AdminGoalCard(
                        currentAmount: goalCurrent,
                        targetAmount: goalTarget,
                        onAddPressed:
                            () => _openGoalDialog(
                              context,
                              goalCurrent,
                              goalTarget,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (_batches.isNotEmpty) ...[
                        ExpiringBatchesCard(batches: _batches),
                        const SizedBox(height: 24),
                      ],
                      const SectionHeader(
                        icon: Icons.inventory_2_rounded,
                        title: 'Inventario',
                        subtitle: 'Valorización y proyecciones de stock',
                      ),
                      const SizedBox(height: 12),
                      _buildInventoryContent(),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Columna Derecha: Ventas Registradas
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
                      _buildSalesFilters(),
                      const SizedBox(height: 16),
                      _buildSalesContent(),
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

  Widget _buildMobileLayout(double goalCurrent, double goalTarget) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_inventory != null)
                _HealthSummaryBar(
                  lowStockCount: _inventory!.lowStockProducts,
                  criticalBatchesCount: _criticalBatchesCount,
                ),
              const SizedBox(height: 16),
              AdminGoalCard(
                currentAmount: goalCurrent,
                targetAmount: goalTarget,
                onAddPressed:
                    () => _openGoalDialog(context, goalCurrent, goalTarget),
              ),
              const SizedBox(height: 24),
              if (_batches.isNotEmpty) ...[
                ExpiringBatchesCard(batches: _batches),
                const SizedBox(height: 24),
              ],
            ]),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: const SectionHeader(
              icon: Icons.inventory_2_rounded,
              title: 'Inventario',
              subtitle: 'Valorización y proyecciones de stock',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(child: _buildInventoryContent()),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: const SectionHeader(
              icon: Icons.point_of_sale_rounded,
              title: 'Ventas Registradas',
              subtitle: 'Órdenes con estado COMPLETADO',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildSalesFilters(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(child: _buildSalesContent()),
        ),
      ],
    );
  }

  Widget _buildSalesFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            SalesTimeFilter.values.map((filter) {
              final isSelected = _salesFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(_filterName(filter)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) _onFilterChanged(filter);
                  },
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side:
                      isSelected
                          ? BorderSide.none
                          : BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSalesContent() {
    if (_sales == null && _isSalesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_sales == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: IgnorePointer(
        key: ValueKey(_salesFilter),
        ignoring: _isSalesLoading,
        child: AnimatedOpacity(
          opacity: _isSalesLoading ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      title: 'Órdenes',
                      value: '${_sales!.totalSales}',
                      subtitle: 'Ventas completadas',
                      icon: Icons.shopping_bag_rounded,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      title: 'Ticket Prom.',
                      value: 'S/ ${_sales!.averageTicket.toStringAsFixed(2)}',
                      subtitle: 'Por orden vendida',
                      icon: Icons.receipt_long_rounded,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue,
                          Colors.blue.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KpiCardWide(
                title: 'Ingreso Total Bruto',
                value: 'S/ ${_sales!.totalRevenue.toStringAsFixed(2)}',
                subtitle: 'Facturado en caja',
                icon: Icons.monetization_on_rounded,
                color: AppColors.tealDark,
                rightLabel: 'Ganancia Neta',
                rightValue: 'S/ ${_sales!.totalProfit.toStringAsFixed(2)}',
                rightColor: AppColors.success,
                sparklineData: const [
                  1.2,
                  1.0,
                  1.8,
                  1.5,
                  2.5,
                  2.1,
                  3.2,
                  2.8,
                  3.8,
                  4.2,
                ],
              ),
              const SizedBox(height: 12),
              KpiCardWide(
                title: 'Fondo de Reposición',
                value: 'S/ ${_sales!.replacementFund.toStringAsFixed(2)}',
                subtitle: 'Costo unitario de lo vendido',
                icon: Icons.currency_exchange_rounded,
                color: AppColors.slate,
                rightLabel: '% del Ingreso',
                rightValue:
                    _sales!.totalRevenue > 0
                        ? '${((_sales!.replacementFund / _sales!.totalRevenue) * 100).toStringAsFixed(1)}%'
                        : '0.0%',
                rightColor: AppColors.slate,
                sparklineData: const [
                  4.2,
                  3.8,
                  2.8,
                  3.2,
                  2.1,
                  2.5,
                  1.5,
                  1.8,
                  1.0,
                  1.2,
                ],
              ),
              const SizedBox(height: 12),
              MargenBar(
                label: 'Margen Nivelado sobre ventas',
                percent: _sales!.salesMargin,
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryContent() {
    if (_inventory == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'Stock Total',
                value: '${_inventory!.totalStock}',
                subtitle: '${_inventory!.totalProducts} productos activos',
                icon: Icons.inventory_2_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue,
                    Colors.blue.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                title: 'Bajo Stock',
                value: '${_inventory!.lowStockProducts}',
                subtitle: 'Productos en alerta',
                icon: Icons.warning_amber_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.error,
                    AppColors.error.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        KpiCardWide(
          title: 'Valorización a Costo',
          value: 'S/ ${_inventory!.totalInvestment.toStringAsFixed(2)}',
          subtitle: 'Inversión en almacén',
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
          sparklineData: const [
            2.0,
            2.2,
            2.5,
            2.4,
            2.8,
            3.0,
            3.2,
            3.1,
            3.5,
            3.8,
          ],
          rightLabel: '',
          rightValue: '',
        ),
        const SizedBox(height: 8),
        GananciaBrutaCard(
          gananciaBruta: _inventory!.expectedMaxProfit,
          inversion: _inventory!.totalInvestment,
          margenPct: _inventory!.grossMargin,
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
                value: 'S/ ${_inventory!.expectedMaxProfit.toStringAsFixed(2)}',
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
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                title: 'G. Mayorista',
                value: 'S/ ${_inventory!.expectedMinProfit.toStringAsFixed(2)}',
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
