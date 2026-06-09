import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    final response = await _supabase
        .from('products')
        .select('''
          id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, 
          product_variants(id, wholesale_price, wholesale_min_quantity, reorder_point, is_active),
          warehouse_stock_batches(variant_id, available_quantity)
        ''')
        .eq('is_active', true)
        .order('name');

    final products = List<Map<String, dynamic>>.from(response);

    for (final prod in products) {
      final variants = List<Map<String, dynamic>>.from(
        prod['product_variants'] ?? [],
      );

      final activeVariants =
          variants.where((v) => v['is_active'] == true).toList();
      final activeVariantIds = activeVariants.map((v) => v['id']).toSet();

      final batches = List<Map<String, dynamic>>.from(
        prod['warehouse_stock_batches'] ?? [],
      );

      int totalActiveStock = 0;

      for (final batch in batches) {
        if (activeVariantIds.contains(batch['variant_id'])) {
          totalActiveStock +=
              (batch['available_quantity'] as num?)?.toInt() ?? 0;
        }
      }

      prod['total_active_stock'] = totalActiveStock;
      prod['active_variants_list'] = activeVariants;
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _loadExpiringBatches() async {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));

    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('''
          id, batch_number, expiry_date, available_quantity,
          products(name),
          product_variants(sku, attributes),
          warehouses(name)
        ''')
        .not('expiry_date', 'is', null)
        .lte('expiry_date', in30Days.toIso8601String().substring(0, 10))
        .gte('expiry_date', now.toIso8601String().substring(0, 10))
        .gt('available_quantity', 0)
        .order('expiry_date');

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final adminGoalTarget = config.getDouble('admin_goal_target', 2600.0);
    final adminGoalCurrent = config.getDouble('admin_goal_current', 0.0);

    return AdminLayout(
      title: 'Dashboard Financiero',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Meta de Ahorro ─────────────────────────────────────────
            AdminGoalCard(
              currentAmount: adminGoalCurrent,
              targetAmount: adminGoalTarget,
              onAddPressed:
                  () => _configurarMetaDialog(
                    context,
                    adminGoalCurrent,
                    adminGoalTarget,
                  ),
            ),
            const SizedBox(height: 24),

            // ── Alertas: Lotes por Vencer ───────────────────────────────
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadExpiringBatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final batches = snapshot.data ?? [];
                if (batches.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExpiringBatchesCard(batches: batches),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // ── Inventario ─────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.inventory_2_rounded,
              title: 'Inventario',
              subtitle: 'Valorización y proyecciones de stock',
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingPlaceholder();
                }

                if (snapshot.hasError) {
                  return _ErrorCard(message: 'Error cargando inventario');
                }

                int totalStock = 0;
                double inversionTotal = 0;
                double valorVentaMinorista = 0;
                double gananciaEsperadaMax = 0;
                double gananciaEsperadaMin = 0;
                double gananciaBruta = 0;
                int productosBajoStock = 0;
                int totalProductos = 0;

                final products = snapshot.data ?? [];

                for (var row in products) {
                  final stock =
                      (row['total_active_stock'] as num?)?.toInt() ?? 0;

                  totalProductos++;
                  if (stock <= 0) continue;

                  final unitCost =
                      (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
                  final salePrice =
                      (row['sale_price'] as num?)?.toDouble() ?? 0.0;

                  final activeVariants =
                      row['active_variants_list']
                          as List<Map<String, dynamic>>? ??
                      [];

                  Map<String, dynamic>? pricingVariant =
                      activeVariants.isNotEmpty ? activeVariants.first : null;

                  final wholesalePrice =
                      (pricingVariant?['wholesale_price'] as num?)
                          ?.toDouble() ??
                      (row['wholesale_price'] as num?)?.toDouble();
                  final wholesaleMinQuantity =
                      (pricingVariant?['wholesale_min_quantity'] as num?)
                          ?.toInt() ??
                      (row['wholesale_min_quantity'] as num?)?.toInt() ??
                      3;
                  final reorderPoint =
                      (pricingVariant?['reorder_point'] as num?)?.toInt() ?? 3;

                  totalStock += stock;
                  inversionTotal += stock * unitCost;
                  valorVentaMinorista += stock * salePrice;

                  gananciaBruta += (stock * salePrice) - (stock * unitCost);
                  gananciaEsperadaMax +=
                      (stock * salePrice) - (stock * unitCost);

                  final canApplyWholesale =
                      wholesalePrice != null && stock >= wholesaleMinQuantity;
                  final effectiveWholesale =
                      canApplyWholesale ? wholesalePrice : salePrice;
                  gananciaEsperadaMin +=
                      (stock * effectiveWholesale) - (stock * unitCost);

                  if (stock <= reorderPoint) productosBajoStock++;
                }

                final margenBruto =
                    inversionTotal > 0
                        ? (gananciaBruta / valorVentaMinorista) * 100
                        : 0.0;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Stock Total',
                            value: '$totalStock',
                            subtitle: '$totalProductos productos activos',
                            icon: Icons.inventory_2_rounded,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.blue,
                                AppColors.blue.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            title: 'Bajo Stock',
                            value: '$productosBajoStock',
                            subtitle: 'Productos en alerta',
                            icon: Icons.warning_amber_rounded,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.warning,
                                AppColors.warning.withValues(alpha: 0.8),
                              ],
                            ),
                            badge: productosBajoStock > 0 ? '!' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KpiCardWide(
                      title: 'Inversión en Inventario',
                      value: 'S/ ${inversionTotal.toStringAsFixed(2)}',
                      subtitle: 'Valor al precio de compra',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.textSecondary,
                      rightLabel: 'Valor venta minorista',
                      rightValue:
                          'S/ ${valorVentaMinorista.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 12),
                    const _SubSectionLabel(
                      label: 'Indicadores de Ganancia Proyectada',
                    ),
                    const SizedBox(height: 8),
                    _GananciaBrutaCard(
                      gananciaBruta: gananciaBruta,
                      margenPct: margenBruto,
                      inversion: inversionTotal,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'G. Minorista',
                            value:
                                'S/ ${gananciaEsperadaMax.toStringAsFixed(2)}',
                            subtitle: 'Vendiendo al detalle',
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
                          child: _KpiCard(
                            title: 'G. Mayorista',
                            value:
                                'S/ ${gananciaEsperadaMin.toStringAsFixed(2)}',
                            subtitle: 'Aplicando precio por mayor',
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
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Ventas ─────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.point_of_sale_rounded,
              title: 'Ventas Registradas',
              subtitle: 'Órdenes con estado COMPLETADO',
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('orders')
                  .stream(primaryKey: ['id'])
                  .eq('status', 'COMPLETED'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingPlaceholder();
                }

                int totalVentas = 0;
                double ingresoTotal = 0;
                double gananciaTotal = 0;

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  for (var venta in snapshot.data!) {
                    totalVentas += 1;
                    // Según tu esquema DB, la tabla 'orders' almacena el ingreso (total_amount)
                    // y la ganancia (total_profit).
                    ingresoTotal += (venta['total_amount'] as num).toDouble();
                    gananciaTotal += (venta['total_profit'] as num).toDouble();
                  }
                }

                // CÁLCULO FONDO DE REPOSICIÓN:
                // Ingreso Total - Ganancia Neta = Costo de lo vendido (Capital a recuperar)
                final fondoReposicion = ingresoTotal - gananciaTotal;

                final ticketPromedio =
                    totalVentas > 0 ? ingresoTotal / totalVentas : 0.0;
                final margenVentas =
                    ingresoTotal > 0
                        ? (gananciaTotal / ingresoTotal) * 100
                        : 0.0;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Órdenes',
                            value: '$totalVentas',
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
                          child: _KpiCard(
                            title: 'Ticket Prom.',
                            value: 'S/ ${ticketPromedio.toStringAsFixed(2)}',
                            subtitle: 'Por orden vendida',
                            icon: Icons.receipt_long_rounded,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.blue,
                                AppColors.blue.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // CARD 1: Ingresos Generales vs Ganancia Neta
                    _KpiCardWide(
                      title: 'Ingreso Total Bruto',
                      value: 'S/ ${ingresoTotal.toStringAsFixed(2)}',
                      subtitle: 'Facturado en caja',
                      icon: Icons.monetization_on_rounded,
                      color: AppColors.tealDark,
                      rightLabel: 'Ganancia Neta',
                      rightValue: 'S/ ${gananciaTotal.toStringAsFixed(2)}',
                      rightColor: AppColors.success,
                    ),
                    const SizedBox(height: 12),

                    // CARD 2: NUEVA - Fondo de Reposición (Capital)
                    _KpiCardWide(
                      title: 'Fondo de Reposición',
                      value: 'S/ ${fondoReposicion.toStringAsFixed(2)}',
                      subtitle: 'Costo unitario de lo vendido',
                      icon: Icons.currency_exchange_rounded,
                      color: Colors.blueGrey.shade600,
                      rightLabel: '% del Ingreso',
                      rightValue:
                          ingresoTotal > 0
                              ? '${((fondoReposicion / ingresoTotal) * 100).toStringAsFixed(1)}%'
                              : '0.0%',
                      rightColor: Colors.blueGrey.shade600,
                    ),
                    const SizedBox(height: 12),

                    _MargenBar(
                      label: 'Margen Nivelado sobre ventas',
                      percent: margenVentas,
                      color: AppColors.success,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Gastos ─────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.money_off_rounded,
              title: 'Egresos / Gastos',
              subtitle: 'Control de gastos registrados',
              iconColor: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('expenses').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingPlaceholder();
                }

                double gastosTotales = 0;
                int cantGastos = 0;
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  cantGastos = snapshot.data!.length;
                  for (var g in snapshot.data!) {
                    gastosTotales += (g['amount'] as num).toDouble();
                  }
                }

                return _EgresosCard(total: gastosTotales, cantidad: cantGastos);
              },
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: 'Registrar Nuevo Gasto',
              onPressed: () => _registrarGastoDialog(context),
              icon: const Icon(Icons.add_card, color: Colors.white),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────── Dialogs ──────────────────────────────

  Future<void> _registrarGastoDialog(BuildContext context) async {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Registrar Gasto / Egreso'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del gasto',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto Gastado (S/.)',
                    prefixIcon: Icon(Icons.money_off),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  final amt = double.tryParse(montoCtrl.text);
                  if (descCtrl.text.trim().isEmpty || amt == null || amt <= 0) {
                    AppSnackbar.show(
                      context,
                      message: 'Ingresa datos válidos',
                      backgroundColor: AppColors.error,
                    );
                    return;
                  }
                  await _supabase.from('expenses').insert({
                    'description': descCtrl.text.trim(),
                    'amount': amt,
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Guardar Gasto',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _configurarMetaDialog(
    BuildContext context,
    double current,
    double target,
  ) async {
    final addCtrl = TextEditingController();
    final currentCtrl = TextEditingController(text: current.toStringAsFixed(2));
    final targetCtrl = TextEditingController(
      text: target > 0 ? target.toStringAsFixed(2) : '',
    );

    final configProvider = context.read<AppConfigProvider>();

    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Configurar Meta de Ahorro'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Abonar a la meta (Suma)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto a sumar (S/.)',
                      hintText: 'Ej. 100',
                      prefixIcon: Icon(
                        Icons.add_circle_outline,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Saldo Actual Exacto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Corregir saldo (S/.)',
                      prefixIcon: Icon(Icons.edit_note, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Modificar meta total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nueva Meta Total (S/.)',
                      prefixIcon: Icon(
                        Icons.flag_outlined,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                ),
                onPressed: () async {
                  final baseCurrent =
                      double.tryParse(currentCtrl.text.trim()) ?? current;
                  final added = double.tryParse(addCtrl.text.trim()) ?? 0.0;
                  final newTarget =
                      double.tryParse(targetCtrl.text.trim()) ?? target;
                  final newCurrent = baseCurrent + added;

                  if (newTarget <= 0) {
                    AppSnackbar.show(
                      dialogContext,
                      message: 'La meta debe ser mayor a 0',
                      backgroundColor: AppColors.error,
                    );
                    return;
                  }

                  try {
                    await configProvider.saveValue(
                      'admin_goal_current',
                      newCurrent,
                      description: 'Progreso actual del ahorro',
                    );
                    await configProvider.saveValue(
                      'admin_goal_target',
                      newTarget,
                      description: 'Meta de ahorro del administrador',
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      AppSnackbar.show(
                        context,
                        message: '¡Meta actualizada con éxito!',
                        backgroundColor: AppColors.success,
                      );
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      AppSnackbar.show(
                        dialogContext,
                        message: 'Error al actualizar meta: $e',
                        backgroundColor: AppColors.error,
                      );
                    }
                  }
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS DE UI (SIN ALTERACIONES ESTRUCTURALES)
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  final String label;
  const _SubSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.teal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? badge;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              if (badge != null)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradient.colors.last,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _KpiCardWide extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String rightLabel;
  final String rightValue;
  final Color? rightColor;

  const _KpiCardWide({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.rightLabel,
    required this.rightValue,
    this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            width: 1,
            color: color.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rightLabel,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                rightValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: rightColor ?? color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GananciaBrutaCard extends StatelessWidget {
  final double gananciaBruta;
  final double margenPct;
  final double inversion;

  const _GananciaBrutaCard({
    required this.gananciaBruta,
    required this.margenPct,
    required this.inversion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealDark, AppColors.success],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.price_check_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'GANANCIA BRUTA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'vs precio de compra',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${gananciaBruta.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Inversión: S/ ${inversion.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Margen Bruto',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${margenPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (margenPct / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MargenBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _MargenBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.percent_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EgresosCard extends StatelessWidget {
  final double total;
  final int cantidad;

  const _EgresosCard({required this.total, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_down_rounded,
              color: AppColors.danger,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Egresos Históricos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'S/ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
              Text(
                'registros',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.danger.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiringBatchesCard extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  const _ExpiringBatchesCard({required this.batches});

  @override
  State<_ExpiringBatchesCard> createState() => _ExpiringBatchesCardState();
}

class _ExpiringBatchesCardState extends State<_ExpiringBatchesCard> {
  bool _expanded = false;

  String _daysLabel(String? expiryDateStr) {
    if (expiryDateStr == null) return '';
    final expiry = DateTime.tryParse(expiryDateStr);
    if (expiry == null) return '';
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff == 0) return 'Vence hoy';
    if (diff == 1) return 'Vence mañana';
    return 'Vence en $diff días';
  }

  Color _urgencyColor(String? expiryDateStr) {
    if (expiryDateStr == null) return AppColors.warning;
    final expiry = DateTime.tryParse(expiryDateStr);
    if (expiry == null) return AppColors.warning;
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff <= 7) return AppColors.danger;
    if (diff <= 15) return AppColors.warning;
    return Colors.orange.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final batches = widget.batches;
    final criticalCount =
        batches.where((b) {
          final expiry = DateTime.tryParse(b['expiry_date'] ?? '');
          return expiry != null &&
              expiry.difference(DateTime.now()).inDays <= 7;
        }).length;

    final visibleBatches = _expanded ? batches : batches.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade900.withValues(alpha: 0.15),
            Colors.red.shade900.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lotes Próximos a Vencer',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.danger,
                        ),
                      ),
                      Text(
                        '${batches.length} lote${batches.length != 1 ? 's' : ''} en los próximos 30 días'
                        '${criticalCount > 0 ? ' · $criticalCount crítico${criticalCount != 1 ? 's' : ''}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${batches.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...visibleBatches.map((batch) {
            final productName =
                (batch['products'] as Map?)?['name'] as String? ?? '–';
            final warehouseName =
                (batch['warehouses'] as Map?)?['name'] as String? ?? '–';
            final variantAttrs =
                (batch['product_variants'] as Map?)?['attributes'] as Map? ??
                {};
            final sku = (batch['product_variants'] as Map?)?['sku'] as String?;
            final batchNumber = batch['batch_number'] as String? ?? '–';
            final qty = (batch['available_quantity'] as num?)?.toInt() ?? 0;
            final expiryStr = batch['expiry_date'] as String?;
            final urgencyColor = _urgencyColor(expiryStr);
            final daysLabel = _daysLabel(expiryStr);

            final attrsDesc = variantAttrs.entries
                .map((e) => '${e.value}')
                .join(' · ');

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (attrsDesc.isNotEmpty) attrsDesc,
                            if (sku != null && sku.isNotEmpty) 'SKU: $sku',
                            'Lote: $batchNumber',
                            warehouseName,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          daysLabel,
                          style: TextStyle(
                            color: urgencyColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$qty uds.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (batches.length > 3)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver ${batches.length - 3} más...',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

class AdminGoalCard extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final VoidCallback? onAddPressed;

  const AdminGoalCard({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final rawProgress = targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final int percentage = (rawProgress * 100).clamp(0, 100).toInt();
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0,
      double.infinity,
    );
    final hasReachedGoal = currentAmount >= targetAmount && targetAmount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasReachedGoal
                        ? Colors.greenAccent.shade400
                        : Colors.amber.shade400,
                  ),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'MI META DE AHORRO',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'S/ ${currentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  'de S/ ${targetAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasReachedGoal
                      ? '🎉 ¡Meta cumplida! Excelente trabajo.'
                      : 'Faltan S/ ${remainingAmount.toStringAsFixed(2)} para tu meta',
                  style: TextStyle(
                    color:
                        hasReachedGoal
                            ? Colors.greenAccent.shade100
                            : Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message:
                onAddPressed == null
                    ? 'Configura esta acción para abonar a la meta.'
                    : 'Configurar Meta',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: onAddPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
