// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS TIPADOS
// ══════════════════════════════════════════════════════════════════════════════

class _BatchModel {
  final String id;
  final String batchNumber;
  final String? expiryDate;
  final int availableQuantity;
  final String warehouseId;
  final String? warehouseName;
  final String? supplierId;
  final String? supplierName;
  final String variantId;
  final String productId;
  final String? productName;
  final String? variantAttrs;
  final String? sku;
  final bool usesBatches; 
  final String? imageUrl; 
  String status;
  int? daysRemaining;

  _BatchModel({
    required this.id,
    required this.batchNumber,
    this.expiryDate,
    required this.availableQuantity,
    required this.warehouseId,
    this.warehouseName,
    this.supplierId,
    this.supplierName,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantAttrs,
    this.sku,
    required this.usesBatches,
    this.imageUrl,
    this.status = 'sin_vencimiento',
    this.daysRemaining,
  });

  void computeExpiryStatus() {
    if (expiryDate == null) {
      status = 'sin_vencimiento';
      daysRemaining = null;
      return;
    }
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) {
      status = 'sin_vencimiento';
      return;
    }
    final diff = expiry.difference(DateTime.now()).inDays;
    daysRemaining = diff;
    if (diff < 0) {
      status = 'vencido';
    } else if (diff <= 30) {
      status = 'critico';
    } else if (diff <= 90) {
      status = 'proximo';
    } else {
      status = 'normal';
    }
  }
}

class _VariantStockItem {
  final String productId;
  final String productName;
  final String category;
  final String productType;
  final bool usesBatches;
  final bool stockControl;
  final double unitCost;
  final double salePrice;
  final double? wholesalePrice;
  final int wholesaleMinQty;
  final String variantId;
  final String? sku;
  final String attrsText; 
  final String? imageUrl; 
  final int reorderPoint;
  final int stock;
  final List<_BatchModel> batches;
  final bool isLowStock;

  const _VariantStockItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.productType,
    required this.usesBatches,
    required this.stockControl,
    required this.unitCost,
    required this.salePrice,
    this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.variantId,
    this.sku,
    required this.attrsText,
    this.imageUrl,
    required this.reorderPoint,
    required this.stock,
    required this.batches,
    required this.isLowStock,
  });

  double get profit => salePrice - unitCost;
  double get margin => unitCost > 0 ? (profit / salePrice) * 100 : 0;
}

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.1,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2_rounded, size: 17),
                  text: 'Stock General',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.event_busy_rounded, size: 17),
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

  static const int _pageSize = 8;
  int _currentPage = 0;

  late Future<List<_VariantStockItem>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _stockFuture = _loadStock();
  }

  void _refresh() {
    setState(() {
      _currentPage = 0;
      _stockFuture = _loadStock();
    });
  }

  void _onFilterChanged(VoidCallback fn) {
    setState(() {
      fn();
      _currentPage = 0;
    });
  }

  Future<List<_VariantStockItem>> _loadStock() async {
    final response = await _supabase
        .from('products')
        .select('''
          id, name, sale_price, unit_cost, wholesale_price, wholesale_min_quantity,
          uses_batches, stock_control, product_type,
          categories(name),
          product_images(image_url, is_main, variant_id),
          product_variants!inner(
            id, sku, sale_price, unit_cost, wholesale_price,
            wholesale_min_quantity, reorder_point, is_active,
            variant_attribute_values(attribute_values(value)),
            warehouse_stock_batches(
              id, variant_id, product_id, available_quantity, expiry_date,
              batch_number, warehouse_id, supplier_id,
              warehouses(name),
              suppliers(name)
            )
          )
        ''')
        .eq('is_active', true)
        .eq('product_variants.is_active', true);

    final List<_VariantStockItem> result = [];
    final Set<String> cats = {};

    for (final rawProd in (response as List)) {
      final prod = rawProd as Map<String, dynamic>;
      final usesBatches = prod['uses_batches'] as bool? ?? false;
      final stockControl = prod['stock_control'] as bool? ?? true;
      final catName =
          (prod['categories'] as Map<String, dynamic>?)?['name'] as String? ??
          'Sin categoría';
      cats.add(catName);

      final double unitCost = (prod['unit_cost'] as num).toDouble();
      final double prodSalePrice = (prod['sale_price'] as num).toDouble();
      final double? prodWholesalePrice =
          (prod['wholesale_price'] as num?)?.toDouble();
      final int prodWholesaleMinQty =
          (prod['wholesale_min_quantity'] as int?) ?? 1;

      final imagesList = prod['product_images'] as List<dynamic>? ?? [];

      for (final rawVariant in (prod['product_variants'] as List? ?? [])) {
        final variant = rawVariant as Map<String, dynamic>;
        final variantId = variant['id'] as String;

        // Extraer atributos relacionales
        final vavList =
            variant['variant_attribute_values'] as List<dynamic>? ?? [];
        final List<String> attrValues = [];
        for (var vav in vavList) {
          final av = vav['attribute_values'] as Map<String, dynamic>?;
          if (av != null && av['value'] != null) {
            attrValues.add(av['value'].toString());
          }
        }
        final attrsText = attrValues.join(' · ');

        // Determinar imagen
        String? finalImageUrl;
        if (imagesList.isNotEmpty) {
          final variantImage = imagesList
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (img) => img['variant_id'] == variantId,
                orElse: () => <String, dynamic>{},
              );
          if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
            finalImageUrl = variantImage['image_url'] as String;
          } else {
            final mainImage = imagesList
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (img) => img['is_main'] == true,
                  orElse:
                      () =>
                          imagesList.isNotEmpty
                              ? imagesList.first as Map<String, dynamic>
                              : <String, dynamic>{},
                );
            finalImageUrl = mainImage['image_url'] as String?;
          }
        }

        final batches =
            ((variant['warehouse_stock_batches'] as List?) ?? []).map((b) {
              final m = Map<String, dynamic>.from(b as Map);
              final wh = m['warehouses'] as Map<String, dynamic>?;
              final sup = m['suppliers'] as Map<String, dynamic>?;
              return _BatchModel(
                id: m['id'] as String,
                batchNumber: m['batch_number'] as String? ?? 'DEFAULT',
                expiryDate: m['expiry_date'] as String?,
                availableQuantity:
                    (m['available_quantity'] as num?)?.toInt() ?? 0,
                warehouseId: m['warehouse_id'] as String,
                warehouseName: wh?['name'] as String?,
                supplierId: m['supplier_id'] as String?,
                supplierName: sup?['name'] as String?,
                variantId: variantId,
                productId: prod['id'] as String,
                productName: prod['name'] as String,
                variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
                sku: variant['sku'] as String?,
                usesBatches: usesBatches,
                imageUrl: finalImageUrl,
              );
            }).toList();

        int stock = 0;
        if (stockControl) {
          stock = batches.fold(0, (s, b) => s + b.availableQuantity);
          if (stock <= 0) continue;
        }

        final reorderPoint = (variant['reorder_point'] as int?) ?? 3;
        final double variantUnitCost =
            ((variant['unit_cost'] as num?)?.toDouble() ?? 0) > 0
                ? (variant['unit_cost'] as num).toDouble()
                : unitCost;
        final double variantSalePrice =
            (variant['sale_price'] as num?)?.toDouble() ?? prodSalePrice;
        final double? variantWholesalePrice =
            (variant['wholesale_price'] as num?)?.toDouble() ??
            prodWholesalePrice;
        final int variantWholesaleMinQty =
            (variant['wholesale_min_quantity'] as int?) ?? prodWholesaleMinQty;

        result.add(
          _VariantStockItem(
            productId: prod['id'] as String,
            productName: prod['name'] as String,
            category: catName,
            productType: prod['product_type'] as String? ?? 'good',
            usesBatches: usesBatches,
            stockControl: stockControl,
            unitCost: variantUnitCost,
            salePrice: variantSalePrice,
            wholesalePrice: variantWholesalePrice,
            wholesaleMinQty: variantWholesaleMinQty,
            variantId: variantId,
            sku: variant['sku'] as String?,
            attrsText: attrsText.isNotEmpty ? attrsText : 'Única',
            imageUrl: finalImageUrl,
            reorderPoint: reorderPoint,
            stock: stock,
            batches: batches,
            isLowStock: stockControl && stock <= reorderPoint,
          ),
        );
      }
    }

    result.sort((a, b) {
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;
      return a.productName.compareTo(b.productName);
    });

    if (mounted) {
      setState(() {
        _categories = ['Todos', ...cats.toList()..sort()];
      });
    }

    return result;
  }

  List<_VariantStockItem> _applyFilters(List<_VariantStockItem> data) {
    return data.where((item) {
      final name = item.productName.toLowerCase();
      final sku = (item.sku ?? '').toLowerCase();
      final search = _searchText.toLowerCase();
      final matchesSearch =
          search.isEmpty || name.contains(search) || sku.contains(search);
      final matchesCat =
          _filterCategory == 'Todos' || item.category == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<_VariantStockItem>>(
      future: _stockFuture,
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final filteredItems = _applyFilters(allItems);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalStock = allItems.fold<int>(0, (s, i) => s + i.stock);
        final lowStockCount = allItems.where((i) => i.isLowStock).length;
        final totalVariants = allItems.length;

        final totalPages =
            filteredItems.isEmpty
                ? 1
                : (filteredItems.length / _pageSize).ceil();
        final safePage = _currentPage >= totalPages ? 0 : _currentPage;
        final pageStart = safePage * _pageSize;
        final pageEnd = (pageStart + _pageSize).clamp(0, filteredItems.length);
        final items = filteredItems.sublist(pageStart, pageEnd);
        final showing = filteredItems.length;

        return Column(
          children: [
            // ── Métricas ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _MetricCard(
                    label: 'Variantes',
                    value: '$totalVariants',
                    icon: Icons.layers_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Stock total',
                    value: '$totalStock',
                    icon: Icons.inventory_rounded,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Bajo stock',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color:
                        lowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                    highlight: lowStockCount > 0,
                  ),
                ],
              ),
            ),

            // ── Búsqueda + Filtro ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: _searchCtrl,
                      hint: 'Buscar producto o SKU...',
                      onChanged: (v) => _onFilterChanged(() => _searchText = v),
                      onClear: () {
                        _searchCtrl.clear();
                        _onFilterChanged(() => _searchText = '');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryDropdown(
                    categories: _categories,
                    selected: _filterCategory,
                    onChanged:
                        (v) => _onFilterChanged(() => _filterCategory = v),
                  ),
                ],
              ),
            ),

            if (!isLoading && filteredItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mostrando ${pageStart + 1}–$pageEnd de $showing variantes',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                      : filteredItems.isEmpty
                      ? const _EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'No hay productos con stock disponible',
                      )
                      : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => _refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _StockItemCard(item: items[i]),
                        ),
                      ),
            ),

            if (!isLoading && totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: AdminPageBlocks(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPageChanged: (page) => setState(() => _currentPage = page),
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
  final _VariantStockItem item;
  const _StockItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color stockColor;
    if (item.stock <= 0) {
      stockColor = AppColors.danger;
    } else if (item.isLowStock) {
      stockColor = AppColors.warning;
    } else {
      stockColor = AppColors.success;
    }

    final double stockRatio =
        item.stockControl && item.reorderPoint > 0
            ? (item.stock / (item.reorderPoint * 4)).clamp(0.0, 1.0)
            : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            item.isLowStock
                ? Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                  width: 1.5,
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── CACHED IMAGE ─────────────────────────────────────
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child:
                        item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey.shade50,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey.shade50,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey.shade50,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 22,
                                color: Colors.grey.shade400,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Stock badge ──────────────────────────────────────
                _StockBadge(
                  stock: item.stock,
                  color: stockColor,
                  isLowStock: item.isLowStock,
                ),
                const SizedBox(width: 12),

                // ── Info principal ───────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isLowStock) ...[
                            const SizedBox(width: 6),
                            _Badge(
                              label: '⚠ Bajo stock',
                              color: AppColors.warning,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          item.category,
                          if (item.attrsText.isNotEmpty &&
                              item.attrsText != 'Única')
                            item.attrsText,
                          if (item.sku != null && item.sku!.isNotEmpty)
                            'SKU: ${item.sku}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Precios
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _PriceTag(
                            label: 'Venta',
                            value: 'S/ ${item.salePrice.toStringAsFixed(2)}',
                            color: AppColors.primary,
                          ),
                          _PriceTag(
                            label: 'Costo',
                            value: 'S/ ${item.unitCost.toStringAsFixed(2)}',
                            color: AppColors.textSecondary,
                          ),
                          if (item.wholesalePrice != null)
                            _PriceTag(
                              label: 'Mayor×${item.wholesaleMinQty}',
                              value:
                                  'S/ ${item.wholesalePrice!.toStringAsFixed(2)}',
                              color: AppColors.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Margen ───────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.margin.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color:
                            item.margin >= 30
                                ? AppColors.success
                                : item.margin >= 15
                                ? AppColors.warning
                                : AppColors.danger,
                      ),
                    ),
                    Text(
                      'margen',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (item.stockControl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stockRatio,
                      backgroundColor: stockColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(stockColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

          if (item.usesBatches && item.batches.isNotEmpty)
            _BatchMiniList(batches: item.batches),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Reorden: ${item.reorderPoint} uds.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (item.usesBatches)
                  _Badge(
                    icon: Icons.batch_prediction_rounded,
                    label:
                        '${item.batches.length} lote${item.batches.length != 1 ? 's' : ''}',
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stock Badge ───────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final int stock;
  final Color color;
  final bool isLowStock;

  const _StockBadge({
    required this.stock,
    required this.color,
    required this.isLowStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$stock',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize:
                    stock > 999
                        ? 11
                        : stock > 99
                        ? 14
                        : 18,
              ),
            ),
            Text(
              'uds.',
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BatchMiniList ─────────────────────────────────────────────────────────────

class _BatchMiniList extends StatelessWidget {
  final List<_BatchModel> batches;
  const _BatchMiniList({required this.batches});

  @override
  Widget build(BuildContext context) {
    final active = batches.where((b) => b.availableQuantity > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            active.map((b) {
              Color expiryColor = AppColors.textSecondary;
              String expiryLabel = 'Sin vencimiento';

              if (b.expiryDate != null) {
                final expiry = DateTime.tryParse(b.expiryDate!);
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
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: expiryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      b.batchNumber == 'DEFAULT'
                          ? 'Sin lote'
                          : 'Lote ${b.batchNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${b.availableQuantity} uds.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (b.warehouseName != null) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '· ${b.warehouseName}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
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
// TAB 2: ESTADO DE LOTES
// ══════════════════════════════════════════════════════════════════════════════

class _BatchesTab extends StatefulWidget {
  const _BatchesTab();

  @override
  State<_BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<_BatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  String _filterStatus = 'Todos';
  String _searchText = '';
  final _searchCtrl = TextEditingController();

  static const int _pageSize = 8;
  int _currentPage = 0;

  // Conteos globales por estado (cargados una vez)
  int _countVencido = 0;
  int _countCritico = 0;
  int _countProximo = 0;
  int _countNormal = 0;

  late Future<List<_BatchModel>> _batchesFuture;

  @override
  void initState() {
    super.initState();
    _batchesFuture = _loadBatches();
  }

  void _refresh() {
    setState(() {
      _currentPage = 0;
      _batchesFuture = _loadBatches();
    });
  }

  void _onFilterChanged(VoidCallback fn) {
    setState(() {
      fn();
      _currentPage = 0;
      _batchesFuture = _loadBatches();
    });
  }

  Future<List<_BatchModel>> _loadBatches() async {
    var baseQuery = _supabase
        .from('warehouse_stock_batches')
        .select('''
          id, batch_number, expiry_date, available_quantity,
          variant_id, warehouse_id, product_id, supplier_id,
          products!inner(id, name, uses_batches, product_images(image_url, is_main, variant_id)),
          product_variants(id, sku, variant_attribute_values(attribute_values(value))),
          warehouses(name),
          suppliers(name)
        ''')
        .gt('available_quantity', 0);

    if (_searchText.isNotEmpty) {
      baseQuery = baseQuery.ilike('batch_number', '%$_searchText%');
    }

    final response = await baseQuery.order(
      'expiry_date',
      ascending: true,
      nullsFirst: false,
    );

    final allRaw =
        (response as List)
            .where(
              (raw) =>
                  ((raw['products'] as Map?)?['uses_batches'] as bool?) == true,
            )
            .map((b) {
              final m = Map<String, dynamic>.from(b as Map);
              final prod = m['products'] as Map<String, dynamic>?;
              final variant = m['product_variants'] as Map<String, dynamic>?;
              final variantId = m['variant_id'] as String;
              final usesBatches = prod?['uses_batches'] == true;

              String? finalImageUrl;
              final imagesList =
                  prod?['product_images'] as List<dynamic>? ?? [];
              if (imagesList.isNotEmpty) {
                final variantImage = imagesList
                    .cast<Map<String, dynamic>>()
                    .firstWhere(
                      (img) => img['variant_id'] == variantId,
                      orElse: () => <String, dynamic>{},
                    );
                if (variantImage.isNotEmpty &&
                    variantImage['image_url'] != null) {
                  finalImageUrl = variantImage['image_url'] as String;
                } else {
                  final mainImage = imagesList
                      .cast<Map<String, dynamic>>()
                      .firstWhere(
                        (img) => img['is_main'] == true,
                        orElse:
                            () =>
                                imagesList.isNotEmpty
                                    ? imagesList.first as Map<String, dynamic>
                                    : <String, dynamic>{},
                      );
                  finalImageUrl = mainImage['image_url'] as String?;
                }
              }

              final vavList =
                  variant?['variant_attribute_values'] as List<dynamic>? ?? [];
              final List<String> attrValues = [];
              for (var vav in vavList) {
                final av = vav['attribute_values'] as Map<String, dynamic>?;
                if (av != null && av['value'] != null) {
                  attrValues.add(av['value'].toString());
                }
              }
              final attrsText = attrValues.join(' · ');

              final wh = m['warehouses'] as Map<String, dynamic>?;
              final sup = m['suppliers'] as Map<String, dynamic>?;

              return _BatchModel(
                id: m['id'] as String,
                batchNumber: m['batch_number'] as String? ?? 'DEFAULT',
                expiryDate: m['expiry_date'] as String?,
                availableQuantity:
                    (m['available_quantity'] as num?)?.toInt() ?? 0,
                warehouseId: m['warehouse_id'] as String,
                warehouseName: wh?['name'] as String?,
                supplierId: m['supplier_id'] as String?,
                supplierName: sup?['name'] as String?,
                variantId: variantId,
                productId: m['product_id'] as String,
                productName: prod?['name'] as String?,
                variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
                sku: variant?['sku'] as String?,
                usesBatches: usesBatches,
                imageUrl: finalImageUrl,
              );
            })
            .toList();

    for (final b in allRaw) {
      b.computeExpiryStatus();
    }

    _countVencido = allRaw.where((b) => b.status == 'vencido').length;
    _countCritico = allRaw.where((b) => b.status == 'critico').length;
    _countProximo = allRaw.where((b) => b.status == 'proximo').length;
    _countNormal = allRaw.where((b) => b.status == 'normal').length;

    final filtered =
        _filterStatus == 'Todos'
            ? allRaw
            : allRaw.where((b) {
              switch (_filterStatus) {
                case 'Vencido':
                  return b.status == 'vencido';
                case 'Crítico':
                  return b.status == 'critico';
                case 'Próximo':
                  return b.status == 'proximo';
                case 'Normal':
                  return b.status == 'normal';
                default:
                  return true;
              }
            }).toList();

    return filtered;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<_BatchModel>>(
      future: _batchesFuture,
      builder: (context, snapshot) {
        final allFiltered = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalPages =
            allFiltered.isEmpty ? 1 : (allFiltered.length / _pageSize).ceil();
        final safePage = _currentPage >= totalPages ? 0 : _currentPage;
        final pageStart = safePage * _pageSize;
        final pageEnd = (pageStart + _pageSize).clamp(0, allFiltered.length);
        final pageBatches = allFiltered.sublist(pageStart, pageEnd);

        return Column(
          children: [
            // ── Chips de estado ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _StatusChip(
                    label: 'Vencido',
                    count: _countVencido,
                    color: AppColors.danger,
                    selected: _filterStatus == 'Vencido',
                    onTap:
                        () => _onFilterChanged(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Vencido'
                                      ? 'Todos'
                                      : 'Vencido',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤30 días',
                    count: _countCritico,
                    color: AppColors.warning,
                    selected: _filterStatus == 'Crítico',
                    onTap:
                        () => _onFilterChanged(
                          () =>
                              _filterStatus =
                                  _filterStatus == 'Crítico'
                                      ? 'Todos'
                                      : 'Crítico',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤90 días',
                    count: _countProximo,
                    color: Colors.orange.shade400,
                    selected: _filterStatus == 'Próximo',
                    onTap:
                        () => _onFilterChanged(
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
                    count: _countNormal,
                    color: AppColors.success,
                    selected: _filterStatus == 'Normal',
                    onTap:
                        () => _onFilterChanged(
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

            // ── Búsqueda ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SearchField(
                controller: _searchCtrl,
                hint: 'Buscar producto o lote...',
                onChanged: (v) => _onFilterChanged(() => _searchText = v),
                onClear: () {
                  _searchCtrl.clear();
                  _onFilterChanged(() => _searchText = '');
                },
              ),
            ),

            if (!isLoading && allFiltered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mostrando ${allFiltered.isEmpty ? 0 : pageStart + 1}–$pageEnd de ${allFiltered.length} lotes',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                      : allFiltered.isEmpty
                      ? const _EmptyState(
                        icon: Icons.event_available_rounded,
                        message: 'No hay lotes con stock disponible',
                      )
                      : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => _refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: pageBatches.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, i) => _BatchCard(batch: pageBatches[i]),
                        ),
                      ),
            ),

            if (!isLoading && totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: AdminPageBlocks(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPageChanged: (page) => setState(() => _currentPage = page),
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
  final _BatchModel batch;

  const _BatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (batch.status) {
      case 'vencido':
        statusColor = AppColors.danger;
        statusLabel = 'VENCIDO';
        statusIcon = Icons.block_rounded;
        break;
      case 'critico':
        statusColor = AppColors.warning;
        final d = batch.daysRemaining!;
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
        statusLabel = 'EN ${batch.daysRemaining} DÍAS';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'normal':
        statusColor = AppColors.success;
        final expiry = DateTime.tryParse(batch.expiryDate ?? '');
        statusLabel =
            expiry != null
                ? '${expiry.day.toString().padLeft(2, '0')}/'
                    '${expiry.month.toString().padLeft(2, '0')}/'
                    '${expiry.year}'
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
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child:
                        batch.imageUrl != null && batch.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: batch.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey.shade50,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey.shade50,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey.shade50,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 22,
                                color: Colors.grey.shade400,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.productName ??
                            'Producto ${batch.productId.substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (batch.variantAttrs != null &&
                              batch.variantAttrs!.isNotEmpty &&
                              batch.variantAttrs != 'Única')
                            batch.variantAttrs!,
                          if (batch.sku != null && batch.sku!.isNotEmpty)
                            'SKU: ${batch.sku}',
                          if (batch.warehouseName != null) batch.warehouseName!,
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
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
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

            const SizedBox(height: 10),

            // ── Pills de detalle ───────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _DetailPill(
                  icon: Icons.numbers_rounded,
                  label:
                      batch.batchNumber == 'DEFAULT'
                          ? 'Sin lote'
                          : 'Lote: ${batch.batchNumber}',
                ),
                _DetailPill(
                  icon: Icons.inventory_2_rounded,
                  label: '${batch.availableQuantity} uds.',
                  color: AppColors.primary,
                ),
                if (batch.supplierName != null)
                  _DetailPill(
                    icon: Icons.business_rounded,
                    label: batch.supplierName!,
                  ),
                if (batch.expiryDate != null)
                  _DetailPill(
                    icon: Icons.calendar_today_rounded,
                    label: 'Vence: ${batch.expiryDate!.substring(0, 10)}',
                    color: statusColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool highlight;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: highlight ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              highlight
                  ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5)
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.75),
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon:
            controller.text.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: onClear,
                )
                : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppColors.surface,
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                selected
                    ? null
                    : Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
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
                textAlign: TextAlign.center,
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
        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
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
              fontSize: 12,
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

  const _DetailPill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 34,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
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
