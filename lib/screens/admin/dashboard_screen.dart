import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

import 'package:inventory_store_app/services/admin/dashboard_service.dart';
import 'package:inventory_store_app/screens/admin/widgets/dashboard/dashboard_cards.dart';
import 'package:inventory_store_app/screens/admin/widgets/dashboard/admin_goal_dialog.dart';
import 'package:inventory_store_app/screens/admin/widgets/dashboard/dashboard_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = DashboardService();

  bool _isLoading = true;
  bool _isSalesLoading = false;
  SalesTimeFilter _salesFilter = SalesTimeFilter.thisMonth;

  InventoryMetrics? _inventory;
  SalesMetrics? _sales;
  List<Map<String, dynamic>> _batches = [];

  int get _criticalBatchesCount =>
      _batches.where((b) {
        final expiry = DateTime.tryParse(b['expiry_date'] ?? '');
        return expiry != null && expiry.difference(DateTime.now()).inDays <= 7;
      }).length;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final inventoryFuture = _service.getInventoryMetrics();
      final batchesFuture = _service.getExpiringBatches();
      final salesFuture = _service.getSalesMetrics(_salesFilter);

      final results = await Future.wait([
        inventoryFuture,
        batchesFuture,
        salesFuture,
      ]);

      _inventory = results[0] as InventoryMetrics;
      _batches = results[1] as List<Map<String, dynamic>>;
      _sales = results[2] as SalesMetrics;
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar el dashboard: $e',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSalesData() async {
    setState(() => _isSalesLoading = true);
    try {
      _sales = await _service.getSalesMetrics(_salesFilter);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar ventas: $e',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSalesLoading = false);
      }
    }
  }

  void _onFilterChanged(SalesTimeFilter? newFilter) {
    if (newFilter != null && newFilter != _salesFilter) {
      setState(() => _salesFilter = newFilter);
      _loadSalesData();
    }
  }

  String _filterName(SalesTimeFilter filter) {
    switch (filter) {
      case SalesTimeFilter.today:
        return 'Hoy';
      case SalesTimeFilter.thisWeek:
        return 'Esta Semana';
      case SalesTimeFilter.thisMonth:
        return 'Este Mes';
      case SalesTimeFilter.allTime:
        return 'Histórico';
    }
  }

  Future<void> _openGoalDialog(
    BuildContext context,
    double current,
    double target,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) =>
              AdminGoalDialog(currentAmount: current, targetAmount: target),
    );

    if (result == true && mounted) {
      // Re-trigger build with new config values
      setState(() {});
    }
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
          HapticFeedback.lightImpact();
          await _loadAllData();
        },
        child:
            _isLoading
                ? const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: DashboardSkeleton(),
                )
                : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Meta de Ahorro ─────────────────────────────────────────
                          AdminGoalCard(
                            currentAmount: adminGoalCurrent,
                            targetAmount: adminGoalTarget,
                            onAddPressed:
                                () => _openGoalDialog(
                                  context,
                                  adminGoalCurrent,
                                  adminGoalTarget,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // ── Resumen ejecutivo: ¿necesito actuar hoy? ────────────────
                          if (_inventory != null)
                            _HealthSummaryBar(
                              lowStockCount: _inventory!.productosBajoStock,
                              criticalBatchesCount: _criticalBatchesCount,
                            ),
                          const SizedBox(height: 24),

                          // ── Alertas: Lotes por Vencer ───────────────────────────────
                          if (_batches.isNotEmpty) ...[
                            ExpiringBatchesCard(batches: _batches),
                            const SizedBox(height: 24),
                          ],
                        ]),
                      ),
                    ),

                    // ── Inventario ─────────────────────────────────────────────
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
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            if (_inventory != null)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: KpiCard(
                                          title: 'Stock Total',
                                          value: '${_inventory!.totalStock}',
                                          subtitle:
                                              '${_inventory!.totalProductos} productos activos',
                                          icon: Icons.inventory_2_rounded,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.blue,
                                              AppColors.blue.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: KpiCard(
                                          title: 'Bajo Stock',
                                          value:
                                              '${_inventory!.productosBajoStock}',
                                          subtitle: 'Productos en alerta',
                                          icon: Icons.warning_amber_rounded,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.warning,
                                              AppColors.warning.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                          badge:
                                              _inventory!.productosBajoStock > 0
                                                  ? '!'
                                                  : null,
                                          onTap:
                                              () => context.push(
                                                '/admin/inventory',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  KpiCardWide(
                                    title: 'Inversión en Inventario',
                                    value:
                                        'S/ ${_inventory!.inversionTotal.toStringAsFixed(2)}',
                                    subtitle: 'Valor al precio de compra',
                                    icon: Icons.account_balance_wallet_rounded,
                                    color: AppColors.textSecondary,
                                    rightLabel: 'Valor venta minorista',
                                    rightValue:
                                        'S/ ${_inventory!.valorVentaMinorista.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(height: 12),
                                  const SubSectionLabel(
                                    label: 'Indicadores de Ganancia Proyectada',
                                  ),
                                  const SizedBox(height: 8),
                                  GananciaBrutaCard(
                                    gananciaBruta: _inventory!.gananciaBruta,
                                    margenPct: _inventory!.margenBruto,
                                    inversion: _inventory!.inversionTotal,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: KpiCard(
                                          title: 'G. Minorista',
                                          value:
                                              'S/ ${_inventory!.gananciaEsperadaMax.toStringAsFixed(2)}',
                                          subtitle: 'Vendiendo al detalle',
                                          icon: Icons.trending_up_rounded,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.teal,
                                              AppColors.teal.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: KpiCard(
                                          title: 'G. Mayorista',
                                          value:
                                              'S/ ${_inventory!.gananciaEsperadaMin.toStringAsFixed(2)}',
                                          subtitle:
                                              'Aplicando precio por mayor',
                                          icon: Icons.people_alt_rounded,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.primary,
                                              AppColors.primaryDark,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Ventas ─────────────────────────────────────────────────
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: SalesTimeFilter.values.map((filter) {
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
                                  side: isSelected ? BorderSide.none : BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child:
                            _sales == null && _isSalesLoading
                                ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                                : _sales != null
                                ? AnimatedOpacity(
                                  opacity: _isSalesLoading ? 0.4 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: IgnorePointer(
                                    ignoring: _isSalesLoading,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: KpiCard(
                                                title: 'Órdenes',
                                                value: '${_sales!.totalVentas}',
                                                subtitle: 'Ventas completadas',
                                                icon:
                                                    Icons.shopping_bag_rounded,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primary
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: KpiCard(
                                                title: 'Ticket Prom.',
                                                value:
                                                    'S/ ${_sales!.ticketPromedio.toStringAsFixed(2)}',
                                                subtitle: 'Por orden vendida',
                                                icon:
                                                    Icons.receipt_long_rounded,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    AppColors.blue,
                                                    AppColors.blue.withValues(
                                                      alpha: 0.85,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        KpiCardWide(
                                          title: 'Ingreso Total Bruto',
                                          value:
                                              'S/ ${_sales!.ingresoTotal.toStringAsFixed(2)}',
                                          subtitle: 'Facturado en caja',
                                          icon: Icons.monetization_on_rounded,
                                          color: AppColors.tealDark,
                                          rightLabel: 'Ganancia Neta',
                                          rightValue:
                                              'S/ ${_sales!.gananciaTotal.toStringAsFixed(2)}',
                                          rightColor: AppColors.success,
                                        ),
                                        const SizedBox(height: 12),

                                        KpiCardWide(
                                          title: 'Fondo de Reposición',
                                          value:
                                              'S/ ${_sales!.fondoReposicion.toStringAsFixed(2)}',
                                          subtitle:
                                              'Costo unitario de lo vendido',
                                          icon: Icons.currency_exchange_rounded,
                                          color: Colors.blueGrey.shade600,
                                          rightLabel: '% del Ingreso',
                                          rightValue:
                                              _sales!.ingresoTotal > 0
                                                  ? '${((_sales!.fondoReposicion / _sales!.ingresoTotal) * 100).toStringAsFixed(1)}%'
                                                  : '0.0%',
                                          rightColor: Colors.blueGrey.shade600,
                                        ),
                                        const SizedBox(height: 12),

                                        MargenBar(
                                          label: 'Margen Nivelado sobre ventas',
                                          percent: _sales!.margenVentas,
                                          color: AppColors.success,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _HealthSummaryBar extends StatelessWidget {
  final int lowStockCount;
  final int criticalBatchesCount;

  const _HealthSummaryBar({
    required this.lowStockCount,
    required this.criticalBatchesCount,
  });

  @override
  Widget build(BuildContext context) {
    if (lowStockCount == 0 && criticalBatchesCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
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
        color: Colors.white,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
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
                    if (lowStockCount > 0) '$lowStockCount bajo stock',
                    if (criticalBatchesCount > 0) '$criticalBatchesCount lotes críticos',
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
              minimumSize: const Size(0, 36),
            ),
            icon: const Text('Revisar', style: TextStyle(fontWeight: FontWeight.w700)),
            label: const Icon(Icons.chevron_right_rounded, size: 18),
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
