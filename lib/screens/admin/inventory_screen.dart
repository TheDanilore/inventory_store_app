import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

// ══════════════════════════════════════════════════════════════════════════════
// INVENTORY SCREEN — Pantalla principal con tabs
// ══════════════════════════════════════════════════════════════════════════════

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<Map<String, dynamic>>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inventoryFuture = _loadInventoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadInventoryData() async {
    return await Supabase.instance.client
        .from('warehouse_stock_batches')
        .select();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Inventario',
      showBackButton: true,
      body: Column(
        children: [
          // ── Tab Bar ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2_rounded, size: 18),
                  text: 'Stock General',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.event_busy_rounded, size: 18),
                  text: 'Estado de Lotes',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_StockTab(), _BatchesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1: STOCK GENERAL
// Solo productos con stock > 0. Muestra variantes con stock real.
// ══════════════════════════════════════════════════════════════════════════════

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String _searchText = '';
  String _filterCategory = 'Todos';
  List<String> _categories = ['Todos'];

  Future<List<Map<String, dynamic>>> _loadStock() async {
    final response = await _supabase
        .from('products')
        .select('''
    id, name, sale_price, unit_cost, wholesale_price, wholesale_min_quantity,
    uses_batches, stock_control, product_type,
    categories(name),
    product_variants!inner(
      id, sku, attributes, sale_price, wholesale_price,
      wholesale_min_quantity, reorder_point, is_active
    ),
    warehouse_stock_batches!variant_id(
      variant_id, available_quantity, expiry_date, batch_number
    )
  ''') // Nota: Añadí !variant_id para evitar error de relación ambigua si falla la query
        .eq('is_active', true)
        .eq('product_variants.is_active', true);

    debugPrint('Productos cargados: ${response.length}');

    // 1. Mapear la respuesta de Supabase de manera segura a tus Modelos de Dart
    final List<ProductModel> products =
        (response as List)
            .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();

    final List<Map<String, dynamic>> result = [];
    final Set<String> cats = {};

    for (final prod in products) {
      // 2. Extraer propiedades directamente desde el modelo de forma segura
      final usesBatches = prod.usesBatches;
      final stockControl = prod.stockControl;

      // Asumiendo que tu ProductModel parsea la categoría o la maneja internamente
      final catName = prod.categoryName ?? 'Sin categoría';
      cats.add(catName);

      // Acceder a la lista de variantes ya casteada por tu modelo
      final variants = prod.productVariants ?? [];
      // Acceder a la lista de lotes ya casteada por tu modelo
      final batches = prod.warehouseStockBatches ?? [];

      for (final variant in variants) {
        final variantId = variant.id;
        int stock = 0;

        if (stockControl) {
          // Filtrar los lotes utilizando las propiedades del modelo de lote
          final variantBatches =
              batches.where((b) => b.variantId == variantId).toList();

          stock = variantBatches.fold<int>(
            0,
            (sum, b) => sum + (b.availableQuantity?.toInt() ?? 0),
          );

          // Solo incluir si tiene stock
          if (stock <= 0) continue;
        }

        final reorderPoint = variant.reorderPoint ?? 3;
        final variantBatches =
            batches.where((b) => b.variantId == variantId).toList();

        // Convertir los objetos del lote de vuelta a mapa para tu 'result' final si la vista lo requiere
        final mappedBatches = variantBatches.map((b) => b.toJson()).toList();

        result.add({
          'product_id': prod.id,
          'product_name': prod.name,
          'category': catName,
          'product_type': prod.productType,
          'uses_batches': usesBatches,
          'stock_control': stockControl,
          'unit_cost': prod.unitCost ?? 0.0,
          'sale_price': variant.salePrice ?? prod.salePrice ?? 0.0,
          'wholesale_price': variant.wholesalePrice ?? prod.wholesalePrice,
          'wholesale_min_qty':
              variant.wholesaleMinQuantity ?? prod.wholesaleMinQuantity ?? 3,
          'variant_id': variantId,
          'sku': variant.sku,
          'attributes': variant.attributes ?? {},
          'reorder_point': reorderPoint,
          'stock': stock,
          'batches': mappedBatches,
          'is_low_stock': stockControl && stock <= reorderPoint,
        });
      }
    }

    // Ordenar: bajo stock primero, luego alfabético
    result.sort((a, b) {
      final aLow = a['is_low_stock'] as bool;
      final bLow = b['is_low_stock'] as bool;
      if (aLow && !bLow) return -1;
      if (!aLow && bLow) return 1;
      return (a['product_name'] as String).compareTo(
        b['product_name'] as String,
      );
    });

    if (mounted) {
      setState(() {
        _categories = ['Todos', ...cats.toList()..sort()];
      });
    }

    debugPrint('Variantes con stock: ${result.length}');
    return result;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    return data.where((item) {
      final name = (item['product_name'] as String).toLowerCase();
      final sku = ((item['sku'] as String?) ?? '').toLowerCase();
      final search = _searchText.toLowerCase();
      final matchesSearch =
          search.isEmpty || name.contains(search) || sku.contains(search);
      final matchesCat =
          _filterCategory == 'Todos' || item['category'] == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadStock(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final items = _applyFilters(allItems);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalStock = allItems.fold<int>(
          0,
          (s, i) => s + ((i['stock'] as int?) ?? 0),
        );
        final lowStockCount = allItems.where((i) => i['is_low_stock']).length;
        final totalProducts = allItems.length;

        return Column(
          children: [
            // ── Resumen ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _SummaryChip(
                    label: 'Variantes',
                    value: '$totalProducts',
                    color: AppColors.primary,
                    icon: Icons.layers_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Stock total',
                    value: '$totalStock',
                    color: AppColors.teal,
                    icon: Icons.inventory_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Bajo stock',
                    value: '$lowStockCount',
                    color:
                        lowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),
            ),

            // ── Búsqueda + Filtro categoría ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto o SKU...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon:
                            _searchText.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchText = '');
                                  },
                                )
                                : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryDropdown(
                    categories: _categories,
                    selected: _filterCategory,
                    onChanged: (v) => setState(() => _filterCategory = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Lista ─────────────────────────────────────────────
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                      ? const _EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'No hay productos con stock disponible',
                      )
                      : RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: items.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _StockItemCard(item: items[i]),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

// ── Card de item de stock ─────────────────────────────────────────────────────

class _StockItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _StockItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] as String;
    final sku = item['sku'] as String?;
    final stock = item['stock'] as int;
    final reorderPoint = item['reorder_point'] as int;
    final salePrice = item['sale_price'] as double;
    final unitCost = item['unit_cost'] as double;
    final wholesalePrice = item['wholesale_price'] as double?;
    final wholesaleMinQty = item['wholesale_min_qty'] as int;
    final isLowStock = item['is_low_stock'] as bool;
    final usesBatches = item['uses_batches'] as bool;
    final attrs = item['attributes'] as Map;
    final category = item['category'] as String;
    final batches = item['batches'] as List<Map<String, dynamic>>;

    final attrsText = attrs.entries.map((e) => '${e.value}').join(' · ');
    final profit = salePrice - unitCost;
    final margin = unitCost > 0 ? (profit / salePrice) * 100 : 0.0;

    // Color de stock
    Color stockColor;
    if (stock <= 0) {
      stockColor = AppColors.danger;
    } else if (isLowStock) {
      stockColor = AppColors.warning;
    } else {
      stockColor = AppColors.success;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            isLowStock
                ? Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                  width: 1.5,
                )
                : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock indicator circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$stock',
                      style: TextStyle(
                        color: stockColor,
                        fontWeight: FontWeight.w900,
                        fontSize: stock > 99 ? 12 : 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLowStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⚠ Bajo stock',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          category,
                          if (attrsText.isNotEmpty) attrsText,
                          if (sku != null && sku.isNotEmpty) 'SKU: $sku',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Precios
                      Row(
                        children: [
                          _PriceTag(
                            label: 'Venta',
                            value: 'S/ ${salePrice.toStringAsFixed(2)}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          _PriceTag(
                            label: 'Costo',
                            value: 'S/ ${unitCost.toStringAsFixed(2)}',
                            color: AppColors.textSecondary,
                          ),
                          if (wholesalePrice != null) ...[
                            const SizedBox(width: 8),
                            _PriceTag(
                              label: 'Mayor×$wholesaleMinQty',
                              value: 'S/ ${wholesalePrice.toStringAsFixed(2)}',
                              color: AppColors.teal,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Margen
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${margin.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color:
                            margin >= 30
                                ? AppColors.success
                                : margin >= 15
                                ? AppColors.warning
                                : AppColors.danger,
                      ),
                    ),
                    Text(
                      'margen',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Footer: reorder point + lotes si aplica ─────────────────
          if (usesBatches && batches.isNotEmpty)
            _BatchMiniList(batches: batches),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Punto de reorden: $reorderPoint uds.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (usesBatches)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.batch_prediction_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${batches.length} lote${batches.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchMiniList extends StatelessWidget {
  final List<Map<String, dynamic>> batches;
  const _BatchMiniList({required this.batches});

  @override
  Widget build(BuildContext context) {
    // Solo los lotes con stock
    final activeBatches =
        batches
            .where((b) => ((b['available_quantity'] as num?)?.toInt() ?? 0) > 0)
            .toList();
    if (activeBatches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            activeBatches.map((b) {
              final batchNum = b['batch_number'] as String? ?? '–';
              final qty = (b['available_quantity'] as num?)?.toInt() ?? 0;
              final expiryStr = b['expiry_date'] as String?;
              Color expiryColor = AppColors.textSecondary;
              String expiryLabel = 'Sin vencimiento';

              if (expiryStr != null) {
                final expiry = DateTime.tryParse(expiryStr);
                if (expiry != null) {
                  final diff = expiry.difference(DateTime.now()).inDays;
                  if (diff < 0) {
                    expiryColor = AppColors.danger;
                    expiryLabel = 'Vencido';
                  } else if (diff <= 30) {
                    expiryColor = AppColors.warning;
                    expiryLabel = 'Vence en $diff días';
                  } else {
                    expiryColor = AppColors.success;
                    expiryLabel =
                        '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: expiryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lote $batchNum',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$qty uds.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      expiryLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: expiryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2: ESTADO DE LOTES (solo productos uses_batches = true)
// Lista completa de lotes ordenados por fecha de vencimiento.
// ══════════════════════════════════════════════════════════════════════════════

class _BatchesTab extends StatefulWidget {
  const _BatchesTab();

  @override
  State<_BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<_BatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  String _filterStatus = 'Todos'; // Todos | Vencido | Crítico | Normal
  String _searchText = '';
  final _searchCtrl = TextEditingController();

  Future<List<Map<String, dynamic>>> _loadBatches() async {
    // Traemos todos los lotes de productos que usan lotes, con stock > 0
    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('''
          id, batch_number, expiry_date, available_quantity, updated_at,
          products!inner(name, uses_batches),
          product_variants(sku, attributes),
          warehouses(name),
          suppliers(name)
        ''')
        .eq('products.uses_batches', true)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);

    // También traemos lotes sin fecha de vencimiento (nullsFirst: false los deja al final)
    final allBatches = List<Map<String, dynamic>>.from(response);

    // Enriquecer con estado
    for (final b in allBatches) {
      final expiryStr = b['expiry_date'] as String?;
      if (expiryStr == null) {
        b['_status'] = 'sin_vencimiento';
        b['_days_remaining'] = null;
      } else {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry == null) {
          b['_status'] = 'sin_vencimiento';
          b['_days_remaining'] = null;
        } else {
          final diff = expiry.difference(DateTime.now()).inDays;
          b['_days_remaining'] = diff;
          if (diff < 0) {
            b['_status'] = 'vencido';
          } else if (diff <= 30) {
            b['_status'] = 'critico';
          } else if (diff <= 90) {
            b['_status'] = 'proximo';
          } else {
            b['_status'] = 'normal';
          }
        }
      }
    }

    return allBatches;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    return data.where((b) {
      final productName =
          ((b['products'] as Map?)?['name'] as String? ?? '').toLowerCase();
      final batchNum = (b['batch_number'] as String? ?? '').toLowerCase();
      final search = _searchText.toLowerCase();
      final matchSearch =
          search.isEmpty ||
          productName.contains(search) ||
          batchNum.contains(search);

      bool matchStatus = true;
      switch (_filterStatus) {
        case 'Vencido':
          matchStatus = b['_status'] == 'vencido';
          break;
        case 'Crítico':
          matchStatus = b['_status'] == 'critico';
          break;
        case 'Próximo':
          matchStatus = b['_status'] == 'proximo';
          break;
        case 'Normal':
          matchStatus = b['_status'] == 'normal';
          break;
      }

      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadBatches(),
      builder: (context, snapshot) {
        final allBatches = snapshot.data ?? [];
        final batches = _applyFilters(allBatches);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final vencidos =
            allBatches.where((b) => b['_status'] == 'vencido').length;
        final criticos =
            allBatches.where((b) => b['_status'] == 'critico').length;
        final proximos =
            allBatches.where((b) => b['_status'] == 'proximo').length;
        final normales =
            allBatches.where((b) => b['_status'] == 'normal').length;

        return Column(
          children: [
            // ── Contador de estados ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _StatusChip(
                    label: 'Vencido',
                    count: vencidos,
                    color: AppColors.danger,
                    selected: _filterStatus == 'Vencido',
                    onTap:
                        () => setState(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Vencido'
                                      ? 'Todos'
                                      : 'Vencido',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤30d',
                    count: criticos,
                    color: AppColors.warning,
                    selected: _filterStatus == 'Crítico',
                    onTap:
                        () => setState(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Crítico'
                                      ? 'Todos'
                                      : 'Crítico',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤90d',
                    count: proximos,
                    color: Colors.orange.shade400,
                    selected: _filterStatus == 'Próximo',
                    onTap:
                        () => setState(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Próximo'
                                      ? 'Todos'
                                      : 'Próximo',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: 'Normal',
                    count: normales,
                    color: AppColors.success,
                    selected: _filterStatus == 'Normal',
                    onTap:
                        () => setState(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Normal'
                                      ? 'Todos'
                                      : 'Normal',
                        ),
                  ),
                ],
              ),
            ),

            // ── Búsqueda ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchText = v),
                decoration: InputDecoration(
                  hintText: 'Buscar producto o número de lote...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon:
                      _searchText.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchText = '');
                            },
                          )
                          : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Lista de lotes ────────────────────────────────────────
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : batches.isEmpty
                      ? const _EmptyState(
                        icon: Icons.event_available_rounded,
                        message: 'No hay lotes con stock disponible',
                      )
                      : RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: batches.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _BatchCard(batch: batches[i]),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

// ── Card de lote ──────────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _BatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final productName = (batch['products'] as Map?)?['name'] as String? ?? '–';
    final batchNumber = batch['batch_number'] as String? ?? '–';
    final qty = (batch['available_quantity'] as num?)?.toInt() ?? 0;
    final warehouseName =
        (batch['warehouses'] as Map?)?['name'] as String? ?? '–';
    final supplierName = (batch['suppliers'] as Map?)?['name'] as String?;
    final variantAttrs =
        (batch['product_variants'] as Map?)?['attributes'] as Map? ?? {};
    final sku = (batch['product_variants'] as Map?)?['sku'] as String?;
    final expiryStr = batch['expiry_date'] as String?;
    final status = batch['_status'] as String;
    final daysRemaining = batch['_days_remaining'] as int?;

    final attrsText = variantAttrs.entries.map((e) => '${e.value}').join(' · ');

    // Color y label según estado
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'vencido':
        statusColor = AppColors.danger;
        statusLabel = 'VENCIDO';
        statusIcon = Icons.block_rounded;
        break;
      case 'critico':
        statusColor = AppColors.warning;
        final d = daysRemaining!;
        statusLabel =
            d == 0
                ? 'HOY'
                : d == 1
                ? 'MAÑANA'
                : 'EN $d DÍAS';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'proximo':
        statusColor = Colors.orange.shade400;
        statusLabel = 'EN $daysRemaining DÍAS';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'normal':
        statusColor = AppColors.success;
        final expiry = DateTime.tryParse(expiryStr ?? '');
        statusLabel =
            expiry != null
                ? '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}'
                : 'NORMAL';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = 'SIN VTO.';
        statusIcon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (attrsText.isNotEmpty) attrsText,
                          if (sku != null && sku.isNotEmpty) 'SKU: $sku',
                          warehouseName,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Estado badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Detalle del lote
            Row(
              children: [
                _DetailPill(
                  icon: Icons.numbers_rounded,
                  label: 'Lote: $batchNumber',
                ),
                const SizedBox(width: 6),
                _DetailPill(
                  icon: Icons.inventory_2_rounded,
                  label: '$qty uds.',
                  color: AppColors.primary,
                ),
                if (supplierName != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: _DetailPill(
                      icon: Icons.business_rounded,
                      label: supplierName,
                      maxWidth: true,
                    ),
                  ),
                ],
              ],
            ),

            if (expiryStr != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Vence: ${expiryStr.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: selected ? Colors.white : color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color:
                      selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          icon: const Icon(Icons.tune_rounded, size: 16),
          items:
              categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PriceTag({
    required this.label,
    required this.value,
    this.color = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool maxWidth;

  const _DetailPill({
    required this.icon,
    required this.label,
    this.color,
    this.maxWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: maxWidth ? MainAxisSize.min : MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return pill;
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
