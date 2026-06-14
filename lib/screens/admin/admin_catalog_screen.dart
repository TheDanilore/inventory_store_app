import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/screens/admin/pos_checkout_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/shared/product_detail_screen.dart';
import 'package:inventory_store_app/services/admin/catalog_pdf_generator.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  Timer? _debounce;

  Map<String, String> _matchedIngredients = {};

  static const int _pageSize = 8;
  final _catalogService = CatalogService();

  List<CategoryModel> _categories = [];
  String? _selectedCategoryId;
  int _currentPage = 0;
  bool _isExportingPdf = false;
  Future<List<ProductModel>>? _productsFuture;

  final _searchCtrl = TextEditingController();

  // ── Búsqueda por ingrediente activo ───────────────────────────────────────
  bool _searchByIngredient = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _refreshProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _loadProducts();
    });
  }

  Future<void> _fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final categories = await _catalogService.loadCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
      final cacheData =
          categories
              .map(
                (c) => {
                  'id': c.id,
                  'name': c.name,
                  'description': c.description,
                  'is_active': c.isActive,
                },
              )
              .toList();
      await prefs.setString('cached_admin_categories', jsonEncode(cacheData));
    } catch (e) {
      final cached = prefs.getString('cached_admin_categories');
      if (cached != null) {
        final List decoded = jsonDecode(cached);
        final offlineCategories =
            decoded
                .map(
                  (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
        if (mounted) setState(() => _categories = offlineCategories);
      }
    }
  }

  Future<List<ProductModel>> _loadProducts() async {
    // ── Modo ingrediente activo ─────────────────────────────────────────────
    if (_searchByIngredient && _searchCtrl.text.trim().isNotEmpty) {
      return _loadProductsByIngredient(_searchCtrl.text.trim());
    }

    // ── Modo normal ─────────────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    try {
      final products = await _catalogService.loadProducts(
        categoryId: _selectedCategoryId,
        searchTerm: _searchCtrl.text,
        isAdmin: true,
      );

      // Inyectar totalStock desde warehouse_stock_batches
      final productsWithStock = await _injectTotalStock(products);

      if (_selectedCategoryId == null && _searchCtrl.text.trim().isEmpty) {
        await prefs.setString(
          'cached_admin_products',
          jsonEncode(productsWithStock.map((p) => p.toJson()).toList()),
        );
      }
      return productsWithStock;
    } catch (e) {
      final cached = prefs.getString('cached_admin_products');
      if (cached != null) {
        final List decoded = jsonDecode(cached);
        var offlineProducts =
            decoded
                .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
                .toList();
        if (_selectedCategoryId != null) {
          offlineProducts =
              offlineProducts
                  .where((p) => p.categoryId == _selectedCategoryId)
                  .toList();
        }
        final searchTerm = _searchCtrl.text.trim().toLowerCase();
        if (searchTerm.isNotEmpty) {
          offlineProducts =
              offlineProducts
                  .where((p) => p.name.toLowerCase().contains(searchTerm))
                  .toList();
        }
        return offlineProducts;
      }
      throw Exception(
        'Estás sin conexión a internet y no hay catálogo guardado en este dispositivo.',
      );
    }
  }

  /// Consulta warehouse_stock_batches y devuelve los productos con totalStock inyectado.
  Future<List<ProductModel>> _injectTotalStock(
    List<ProductModel> products,
  ) async {
    if (products.isEmpty) return products;
    final supabase = Supabase.instance.client;
    final productIds = products.map((p) => p.id).toList();

    try {
      final stockResp = await supabase
          .from('warehouse_stock_batches')
          .select('product_id, available_quantity')
          .inFilter('product_id', productIds);

      final stockByProduct = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(stockResp)) {
        final pId = row['product_id'] as String?;
        if (pId == null) continue;
        final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
        stockByProduct[pId] = (stockByProduct[pId] ?? 0) + qty;
      }

      return products
          .map((p) => p.copyWith(totalStock: stockByProduct[p.id] ?? 0))
          .toList();
    } catch (_) {
      // Si falla la consulta de stock, devolvemos con totalStock = 0
      return products;
    }
  }

  Future<List<ProductModel>> _loadProductsByIngredient(String term) async {
    final supabase = Supabase.instance.client;

    // 1. RPC: buscar ingredient_ids. La función devuelve TABLE(id text).
    final List<dynamic> aiResp = await supabase.rpc(
      'search_ingredients_unaccent',
      params: {'search_term': term},
    );

    final ingredientIds =
        (aiResp)
            .map((r) => (r as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

    if (ingredientIds.isEmpty) return [];

    // 2. Buscar product_ids y los datos reales de los ingredientes
    final ingResp = await supabase
        .from('product_active_ingredients')
        .select('product_id, concentration, unit, active_ingredients(name)')
        .inFilter('ingredient_id', ingredientIds);

    final productIds = <String>[];
    final newMatches = <String, String>{};

    for (final e in ingResp as List) {
      final row = e as Map<String, dynamic>;
      final pId = row['product_id']?.toString();
      if (pId == null || pId.isEmpty) continue;

      productIds.add(pId);

      final aiMap = row['active_ingredients'] as Map<String, dynamic>?;
      final name = aiMap?['name']?.toString() ?? 'Desconocido';
      final conc = row['concentration'];
      final unit = row['unit']?.toString().trim();

      String label = name;
      if (conc != null) {
        final concStr =
            (conc is num && conc == conc.toInt())
                ? conc.toInt().toString()
                : conc.toString();
        label += ' $concStr';
      }
      if (unit != null && unit.isNotEmpty) {
        if (unit.startsWith('%')) {
          label += unit; // Ej: 48%
        } else {
          label += ' $unit'; // Ej: 480 g/L
        }
      }

      // Si un producto tiene más de un ingrediente que coincide, los sumamos
      if (newMatches.containsKey(pId)) {
        newMatches[pId] = '${newMatches[pId]} + $label';
      } else {
        newMatches[pId] = label;
      }
    }

    _matchedIngredients = newMatches;

    final uniqueProductIds = productIds.toSet().toList();
    if (uniqueProductIds.isEmpty) return [];

    var query = supabase
        .from('products')
        .select('''
          id, name, unit_cost, sale_price, wholesale_price,
          wholesale_min_quantity, is_active, description,
          category_id, details, created_at, updated_at,
          stock_control, uses_batches, product_type,
          categories(name),
          product_images(*)
        ''')
        .inFilter('id', productIds);

    if (_selectedCategoryId != null) {
      query = query.eq('category_id', _selectedCategoryId!);
    }

    final resp = await query.order('name');

    final productsList = <ProductModel>[];
    for (final e in resp as List) {
      try {
        final row = Map<String, dynamic>.from(e as Map);
        if (row['id'] == null || row['name'] == null) continue;
        productsList.add(ProductModel.fromJson(row));
      } catch (err) {
        debugPrint('⚠️ Producto saltado en búsqueda por ingrediente: $err');
      }
    }

    final stockResp = await supabase
        .from('warehouse_stock_batches')
        .select('product_id, available_quantity')
        .inFilter('product_id', productIds);

    final stockByProduct = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(stockResp)) {
      final pId = row['product_id']?.toString();
      if (pId == null || pId.isEmpty) continue;
      final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
      stockByProduct[pId] = (stockByProduct[pId] ?? 0) + qty;
    }

    return productsList
        .map((p) => p.copyWith(totalStock: stockByProduct[p.id] ?? 0))
        .toList();
  }

  Future<Map<String, List<ProductVariantModel>>> _loadVariantsByProductIds(
    List<String> productIds,
  ) async {
    return _catalogService.loadVariantsByProductIds(productIds);
  }

  Future<Map<String, int>> _loadVariantStockByVariantIds(
    List<String> variantIds,
  ) async {
    return _catalogService.loadVariantStockByVariantIds(variantIds);
  }

  // ─── Export Dialog ───────────────────────────────────────────────────────

  Future<({int mode, Set<String> selectedIds})?> _showExportOptionsDialog(
    List<ProductModel> max50Products,
    int visibleCount,
  ) {
    return showDialog<({int mode, Set<String> selectedIds})>(
      context: context,
      builder: (context) {
        int selectedMode = 1;
        final selectedIds = <String>{};

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusXl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Exportar catálogo a PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _ExportRadioOption(
                      title: 'Solo esta página',
                      subtitle: '$visibleCount productos visibles',
                      value: 0,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),
                    const SizedBox(height: 8),

                    _ExportRadioOption(
                      title: 'Todos los productos',
                      subtitle: 'Máximo 50 productos (recomendado)',
                      value: 1,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),
                    const SizedBox(height: 8),

                    _ExportRadioOption(
                      title: 'Selección personalizada',
                      subtitle: 'Elige los productos a incluir',
                      value: 2,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),

                    if (selectedMode == 2) ...[
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(AppColors.radius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: max50Products.length,
                          itemBuilder: (context, index) {
                            final product = max50Products[index];
                            final productId = product.id;
                            final isSelected = selectedIds.contains(productId);
                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              activeColor: AppColors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusSm,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Stock: ${product.stockControl ? product.totalStock : "Libre"} · ${product.isActive ? "Activo" : "Inactivo"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              onChanged: (checked) {
                                setLocalState(() {
                                  if (checked == true) {
                                    selectedIds.add(productId);
                                  } else {
                                    selectedIds.remove(productId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                selectedMode == 2 && selectedIds.isEmpty
                                    ? null
                                    : () => Navigator.pop(context, (
                                      mode: selectedMode,
                                      selectedIds: selectedIds,
                                    )),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Generar PDF',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportCatalogPdf() async {
    if (_isExportingPdf) return;
    try {
      final allProducts = await _loadProducts();
      if (!mounted) return;

      final visibleProducts =
          allProducts
              .skip(_currentPage * _AdminCatalogScreenState._pageSize)
              .take(_AdminCatalogScreenState._pageSize)
              .toList();

      final max50Products = allProducts.take(50).toList();

      if (max50Products.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos para exportar.',
          type: SnackbarType.error,
        );
        return;
      }

      final options = await _showExportOptionsDialog(
        max50Products,
        visibleProducts.length,
      );

      if (!mounted || options == null) return;

      List<ProductModel> filteredProducts = [];

      if (options.mode == 0) {
        filteredProducts = visibleProducts;
      } else if (options.mode == 1) {
        filteredProducts = max50Products;
      } else if (options.mode == 2) {
        filteredProducts =
            max50Products
                .where((p) => options.selectedIds.contains(p.id))
                .toList();
      }

      if (filteredProducts.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos seleccionados para exportar.',
          type: SnackbarType.error,
        );
        return;
      }

      setState(() => _isExportingPdf = true);

      final productIds = filteredProducts.map((p) => p.id).toList();
      final variantsByProduct = await _loadVariantsByProductIds(productIds);
      final allVariantIds =
          variantsByProduct.values
              .expand((v) => v)
              .map((v) => v.id)
              .whereType<String>()
              .toList();
      final stockByVariant = await _loadVariantStockByVariantIds(allVariantIds);

      CatalogPdfGenerator.shareCatalog(
        products: filteredProducts,
        variantsByProduct: variantsByProduct,
        stockByVariant: stockByVariant,
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: 'No se pudo exportar el PDF: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _toggleProductoActivo(ProductModel product) async {
    final willActivate = !product.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusXl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          willActivate
                              ? AppColors.successLight
                              : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      willActivate
                          ? Icons.check_circle_rounded
                          : Icons.hide_source_rounded,
                      color:
                          willActivate ? AppColors.success : AppColors.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    willActivate ? 'Activar producto' : 'Desactivar producto',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    willActivate
                        ? '¿Volver a mostrar "${product.name}" en el catálogo?'
                        : '¿Ocultar "${product.name}" del catálogo?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                willActivate
                                    ? AppColors.success
                                    : AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                          child: Text(
                            willActivate ? 'Sí, activar' : 'Sí, desactivar',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirm == true) {
      try {
        await _catalogService.setProductActive(
          productId: product.id,
          isActive: willActivate,
        );
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                willActivate
                    ? 'Producto activado exitosamente'
                    : 'Producto desactivado exitosamente',
            type: willActivate ? SnackbarType.success : SnackbarType.warning,
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error: $e',
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  void _irAVenta(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminAddToCartSheet(product: product),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _currentPage = 0);
      _refreshProducts();
    });
  }

  void _toggleIngredientSearch(bool value) {
    setState(() {
      _searchByIngredient = value;
      _currentPage = 0;
      if (value) _selectedCategoryId = null;
    });
    _refreshProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Catálogo',
      showSettingsButton: true,
      settingsActions: [
        const PopupMenuItem(value: 'export', child: Text('Exportar')),
      ],
      onSettingsSelected: (value) {
        switch (value) {
          case 'export':
            _exportCatalogPdf();
            break;
        }
      },
      body: FutureBuilder<List<ProductModel>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          const double fabsBottomPadding = 54;

          final headerSliver = SliverToBoxAdapter(
            child: CatalogHeader(
              searchController: _searchCtrl,
              isExporting: _isExportingPdf,
              onExport: _exportCatalogPdf,
              onSearchChanged: _onSearchChanged,
              searchByIngredient: _searchByIngredient,
              onToggleIngredientSearch: _toggleIngredientSearch,
            ),
          );

          final chipsSliver =
              (_categories.isNotEmpty && !_searchByIngredient)
                  ? SliverToBoxAdapter(
                    child: CategoryChips(
                      categories: _categories,
                      selectedCategoryId: _selectedCategoryId,
                      onSelected: (id) {
                        setState(() {
                          _selectedCategoryId = id;
                          _currentPage = 0;
                        });
                        _refreshProducts();
                      },
                    ),
                  )
                  : null;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return RefreshIndicator(
              color: AppColors.teal,
              onRefresh: () async => _refreshProducts(),
              child: CustomScrollView(
                slivers: [
                  headerSliver,
                  if (chipsSliver != null) chipsSliver,
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.teal),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              color: AppColors.teal,
              onRefresh: () async => _refreshProducts(),
              child: CustomScrollView(
                slivers: [
                  headerSliver,
                  if (chipsSliver != null) chipsSliver,
                  SliverFillRemaining(
                    child: _ErrorState(message: '${snapshot.error}'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              color: AppColors.teal,
              onRefresh: () async => _refreshProducts(),
              child: CustomScrollView(
                slivers: [
                  headerSliver,
                  if (chipsSliver != null) chipsSliver,
                  SliverFillRemaining(
                    child: _EmptyState(
                      searchByIngredient: _searchByIngredient,
                      searchTerm: _searchCtrl.text.trim(),
                    ),
                  ),
                ],
              ),
            );
          }

          final allProducts = snapshot.data!;
          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async => _refreshProducts(),
            child: CatalogGridScrollView(
              products: allProducts,
              pageSize: _pageSize,
              currentPage: _currentPage,
              onPageChanged: (page) => setState(() => _currentPage = page),
              onSale: _irAVenta,
              onToggleActive: _toggleProductoActivo,
              searchByIngredient: _searchByIngredient,
              matchedIngredients: _matchedIngredients,
              bottomPadding: fabsBottomPadding,
              headerSliver: headerSliver,
              chipsSliver: chipsSliver,
              onEdit: (product) async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductFormScreen(productToEdit: product),
                  ),
                );
                if (result == true) _refreshProducts();
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Consumer<PosProvider>(
            builder: (posContext, pos, child) {
              if (pos.itemCount == 0) return const SizedBox.shrink();
              return _PosCartButton(
                itemCount: pos.itemCount,
                total: pos.totalAmount,
                onTap: () async {
                  final success = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminPosCheckoutScreen(),
                    ),
                  );
                  if (success == true) setState(() {});
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _AddProductFab(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
              if (result == true) setState(() => _currentPage = 0);
            },
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY / ERROR STATES ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool searchByIngredient;
  final String searchTerm;

  const _EmptyState({this.searchByIngredient = false, this.searchTerm = ''});

  @override
  Widget build(BuildContext context) {
    final isIngMode = searchByIngredient && searchTerm.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                    isIngMode ? const Color(0xFFECFDF5) : AppColors.tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isIngMode ? Icons.science_rounded : Icons.inventory_2_rounded,
                size: 36,
                color: isIngMode ? const Color(0xFF10B981) : AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isIngMode ? 'Sin resultados para "$searchTerm"' : 'Sin productos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isIngMode
                  ? 'Ningún producto tiene ese ingrediente activo registrado. '
                      'Verifica el nombre o agrégalo desde el formulario del producto.'
                  : 'No se encontraron productos\ncon los filtros actuales.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ocurrió un error',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FLOATING BUTTONS ─────────────────────────────────────────────────────

class _PosCartButton extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;
  const _PosCartButton({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Caja',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'S/ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProductFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddProductFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

// ─── EXPORT RADIO OPTION ─────────────────────────────────────────────────

class _ExportRadioOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final ValueChanged<int?> onChanged;

  const _ExportRadioOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : AppColors.bg,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.teal : AppColors.textMuted,
                  width: 2,
                ),
                color: selected ? AppColors.teal : Colors.transparent,
              ),
              child:
                  selected
                      ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? AppColors.tealDark : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.teal : AppColors.textMuted,
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

// ─── BOTTOM SHEET: AGREGAR AL POS ──────────────────────────────────────────

class _AdminAddToCartSheet extends StatefulWidget {
  final ProductModel product;
  const _AdminAddToCartSheet({required this.product});

  @override
  State<_AdminAddToCartSheet> createState() => _AdminAddToCartSheetState();
}

class _AdminAddToCartSheetState extends State<_AdminAddToCartSheet> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<ProductVariantModel> _variants = [];
  final Map<String, int> _stockByVariant = {};
  ProductVariantModel? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _fetchProductData();
  }

  Future<void> _fetchProductData() async {
    try {
      final varResp = await _supabase
          .from('product_variants')
          .select('*, product_images(*)')
          .eq('product_id', widget.product.id)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      _variants =
          List<Map<String, dynamic>>.from(
            varResp,
          ).map(ProductVariantModel.fromJson).toList();

      if (_variants.isNotEmpty) {
        final variantIds = _variants.map((v) => v.id).toList();
        final invResp = await _supabase
            .from('warehouse_stock_batches')
            .select('variant_id, available_quantity')
            .inFilter('variant_id', variantIds);

        for (final row in List<Map<String, dynamic>>.from(invResp)) {
          final vid = row['variant_id'] as String?;
          if (vid != null) {
            final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
            _stockByVariant[vid] = (_stockByVariant[vid] ?? 0) + qty;
          }
        }
      }

      if (_variants.isNotEmpty) {
        _selectedVariant = _variants.firstWhere(
          (v) => (_stockByVariant[v.id] ?? 0) > 0,
          orElse: () => _variants.first,
        );
      }
    } catch (e) {
      debugPrint('Error loading variants: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasStockControl => widget.product.stockControl;

  int get _currentStock {
    if (_variants.isEmpty) return widget.product.totalStock;
    if (_selectedVariant == null) return 0;
    return _stockByVariant[_selectedVariant!.id] ?? 0;
  }

  double get _currentPrice {
    if (_variants.isEmpty) return widget.product.salePrice;
    return _selectedVariant?.salePrice ?? widget.product.salePrice;
  }

  // Permite vender si:
  // 1. Hay una variante seleccionada (Requerido por DB)
  // 2. Y (No hay control de stock OR hay stock > 0)
  bool get _canSell =>
      _selectedVariant != null && (!_hasStockControl || _currentStock > 0);

  Future<void> _mostrarDialogoCantidad(
    BuildContext context,
    int cantidadActual,
    int maxStock,
  ) async {
    final qtyCtrl = TextEditingController(text: cantidadActual.toString());
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText:
                    _hasStockControl
                        ? 'Stock máximo disponible: $maxStock'
                        : 'Stock libre (Sin límite)',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      if (_hasStockControl) {
                        _quantity = newQty > maxStock ? maxStock : newQty;
                      } else {
                        _quantity = newQty;
                      }
                    });
                  }
                  Navigator.pop(dialogContext);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.teal),
          ),
        ),
      );
    }

    final stock = _currentStock;
    final String? imageUrl =
        _selectedVariant?.images.isNotEmpty == true
            ? _selectedVariant!.images.first.imageUrl
            : widget.product.primaryImageUrl;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header del producto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child:
                    imageUrl != null
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.image_rounded,
                                  color: AppColors.textMuted,
                                ),
                              ),
                        )
                        : Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.image_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'S/ ${_currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _hasStockControl
                                ? (stock > 0
                                    ? AppColors.successLight
                                    : AppColors.dangerLight)
                                : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        !_hasStockControl
                            ? 'Stock Libre'
                            : (stock > 0 ? '$stock disponibles' : 'Agotado'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              !_hasStockControl
                                  ? Colors.blue.shade800
                                  : (stock > 0
                                      ? AppColors.success
                                      : AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Variante',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProductVariantModel>(
                  value: _selectedVariant,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  items:
                      _variants.map((v) {
                        final vStock = _stockByVariant[v.id] ?? 0;
                        final stockLabel =
                            _hasStockControl
                                ? '($vStock en stock)'
                                : '(Stock Libre)';
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            '${v.label} · S/ ${(v.salePrice ?? widget.product.salePrice).toStringAsFixed(2)} $stockLabel',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedVariant = val;
                      _quantity = 1;
                    });
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Cantidad',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  enabled: _quantity > 1,
                  onTap: () => setState(() => _quantity--),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap:
                          () => _mostrarDialogoCantidad(
                            context,
                            _quantity,
                            stock,
                          ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  enabled:
                      !_hasStockControl ||
                      _quantity <
                          stock, // Permite incrementar infinito si es Stock Libre
                  onTap: () => setState(() => _quantity++),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón agregar
          GestureDetector(
            onTap:
                _canSell
                    ? () {
                      context.read<PosProvider>().addProductToPos(
                        product: widget.product,
                        quantity: _quantity,
                        variantId:
                            _selectedVariant!
                                .id, // Seguridad máxima: Ya garantizamos que no es null en _canSell
                        variantLabel: _selectedVariant!.label,
                        unitPrice:
                            _selectedVariant!.salePrice ??
                            widget.product.salePrice,
                        wholesalePrice:
                            _selectedVariant!.wholesalePrice ??
                            widget.product.wholesalePrice,
                        unitCost:
                            _selectedVariant!.unitCost ??
                            widget
                                .product
                                .unitCost, // Vital para el net_profit de la orden
                        imageUrl: imageUrl,
                        sku: _selectedVariant!.sku,
                        availableStock: _hasStockControl ? stock : 999999,
                      );
                      Navigator.pop(context);
                      AppSnackbar.show(
                        context,
                        message: 'Producto agregado a la caja',
                        type: SnackbarType.success,
                      );
                    }
                    : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient:
                    _canSell
                        ? const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color: !_canSell ? const Color(0xFFE2E8F0) : null,
                borderRadius: BorderRadius.circular(AppColors.radius),
                boxShadow:
                    _canSell
                        ? [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: _canSell ? Colors.white : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _canSell
                        ? 'Agregar · S/ ${(_currentPrice * _quantity).toStringAsFixed(2)}'
                        : (_selectedVariant == null
                            ? 'Sin variante activa'
                            : 'Sin stock disponible'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _canSell ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealLight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.teal : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ─── CATALOG HEADER ──────────────────────────────────────────────────────────

class CatalogHeader extends StatelessWidget {
  final TextEditingController searchController;
  final bool isExporting;
  final VoidCallback onExport;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;

  const CatalogHeader({
    super.key,
    required this.searchController,
    required this.isExporting,
    required this.onExport,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        searchByIngredient
                            ? const Color(0xFFECFDF5)
                            : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    border: Border.all(
                      color:
                          searchByIngredient
                              ? const Color(0xFF10B981)
                              : AppColors.border,
                      width: searchByIngredient ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          searchByIngredient
                              ? 'Ej: Glifosato, Clorpirifos...'
                              : 'Buscar producto...',
                      hintStyle: TextStyle(
                        color:
                            searchByIngredient
                                ? const Color(0xFF6EE7B7)
                                : AppColors.textMuted,
                        fontSize: 14,
                      ),
                      prefixIcon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          searchByIngredient
                              ? Icons.science_rounded
                              : Icons.search_rounded,
                          key: ValueKey(searchByIngredient),
                          color:
                              searchByIngredient
                                  ? const Color(0xFF10B981)
                                  : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onToggleIngredientSearch(!searchByIngredient),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:
                    searchByIngredient ? const Color(0xFFECFDF5) : AppColors.bg,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                  color:
                      searchByIngredient
                          ? const Color(0xFF10B981)
                          : AppColors.border,
                  width: searchByIngredient ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      searchByIngredient
                          ? Icons.science_rounded
                          : Icons.science_outlined,
                      key: ValueKey(searchByIngredient),
                      size: 16,
                      color:
                          searchByIngredient
                              ? const Color(0xFF059669)
                              : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          searchByIngredient
                              ? const Color(0xFF059669)
                              : AppColors.textSecondary,
                    ),
                    child: Text(
                      searchByIngredient
                          ? 'Buscando por ingrediente activo'
                          : 'Buscar por ingrediente activo',
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color:
                          searchByIngredient
                              ? const Color(0xFF10B981)
                              : AppColors.border,
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          left: searchByIngredient ? 17 : 2,
                          top: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child:
                searchByIngredient
                    ? Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(
                          color: const Color(0xFF6EE7B7),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Escribe el componente químico para ver todos los '
                              'productos que lo contienen. '
                              'Los filtros de categoría se desactivan en este modo.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065F46),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── CATEGORY CHIPS ──────────────────────────────────────────────────────────

class CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _CategoryChip(
                  label: 'Todos',
                  selected: selectedCategoryId == null,
                  onTap: () => onSelected(null),
                ),
                ...categories.map(
                  (cat) => _CategoryChip(
                    label: cat.name,
                    selected: selectedCategoryId == cat.id,
                    onTap: () => onSelected(cat.id),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CATALOG GRID SCROLL VIEW ─────────────────────────────────────────────────

class CatalogGridScrollView extends StatelessWidget {
  final List<ProductModel> products;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductModel) onSale;
  final void Function(ProductModel) onToggleActive;
  final void Function(ProductModel) onEdit;
  final bool searchByIngredient;
  final Map<String, String> matchedIngredients;
  final double bottomPadding;
  final Widget headerSliver;
  final Widget? chipsSliver;

  const CatalogGridScrollView({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    required this.headerSliver,
    this.chipsSliver,
    this.searchByIngredient = false,
    this.matchedIngredients = const {},
    this.bottomPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = products.length;
    final totalPages = total == 0 ? 1 : (total / pageSize).ceil();
    final safeCurrentPage =
        currentPage >= totalPages ? totalPages - 1 : currentPage;
    final start = safeCurrentPage * pageSize;
    final end = (start + pageSize) > total ? total : (start + pageSize);
    final pageItems = products.sublist(start, end);

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double aspectRatio = 0.70;

        if (constraints.maxWidth >= 1024) {
          crossAxisCount = 5;
          aspectRatio = 1;
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 3;
          aspectRatio = 0.85;
        } else {
          crossAxisCount = 2;
          aspectRatio = 0.80;
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            headerSliver,
            if (chipsSliver != null) chipsSliver!,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Pág. ${safeCurrentPage + 1} / $totalPages',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = pageItems[index];
                  return AdminProductCard(
                    product: product,
                    onSale: () => onSale(product),
                    onToggleActive: () => onToggleActive(product),
                    onEdit: () => onEdit(product),
                    highlightIngredient:
                        searchByIngredient
                            ? matchedIngredients[product.id]
                            : null,
                  );
                }, childCount: pageItems.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomPadding),
                child: AdminPageBlocks(
                  currentPage: safeCurrentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef CatalogGrid = CatalogGridScrollView;

// ─── PRODUCT CARD ─────────────────────────────────────────────────────────────

class AdminProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onSale;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final String? highlightIngredient;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    this.highlightIngredient,
  });

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Un producto solo está agotado si el control de stock está activado
    final isAgotado = product.stockControl && product.totalStock <= 0;
    final isDesactivado = !product.isActive;

    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ProductDetailScreen(product: product, isAdmin: true),
            ),
          ),
      child: Container(
        decoration: BoxDecoration(
          color: isDesactivado ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(
            color:
                isDesactivado
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFEDF2F7),
          ),
          boxShadow:
              isDesactivado
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─ Imagen ─
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppColors.radius),
                    ),
                    child: Opacity(
                      opacity: isDesactivado ? 0.45 : 1.0,
                      child:
                          product.images.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl:
                                    product.images
                                        .firstWhere(
                                          (img) => img.isMain,
                                          orElse: () => product.images.first,
                                        )
                                        .imageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.teal,
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 40,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                              )
                              : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  size: 40,
                                  color: AppColors.textMuted,
                                ),
                              ),
                    ),
                  ),

                  // Badges de estado
                  if (isDesactivado)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radius),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(
                            child: _StatusBadge(
                              label: 'INACTIVO',
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (isAgotado)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radius),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child: _StatusBadge(
                              label: 'AGOTADO',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (!isDesactivado && !isAgotado && product.stockControl)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.totalStock}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─ Info ─
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color:
                          isDesactivado
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                      decoration:
                          isDesactivado ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (highlightIngredient != null &&
                      highlightIngredient!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFF6EE7B7),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.science_rounded,
                            size: 9,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              highlightIngredient!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    'S/ ${product.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          isDesactivado ? AppColors.textMuted : AppColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // ─ Acciones ─
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _CardAction(
                    icon: Icons.point_of_sale_rounded,
                    enabled: !isAgotado && !isDesactivado,
                    activeColor: AppColors.teal,
                    tooltip: 'Vender',
                    onTap: (!isAgotado && !isDesactivado) ? onSale : null,
                  ),
                  _CardAction(
                    icon: Icons.edit_rounded,
                    enabled: true,
                    activeColor: AppColors.blue,
                    tooltip: 'Editar',
                    onTap: onEdit,
                  ),
                  _CardAction(
                    icon:
                        isDesactivado
                            ? Icons.check_circle_outline_rounded
                            : Icons.visibility_off_rounded,
                    enabled: true,
                    activeColor:
                        isDesactivado
                            ? AppColors.success
                            : AppColors.textSecondary,
                    tooltip: isDesactivado ? 'Activar' : 'Desactivar',
                    onTap: onToggleActive,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color activeColor;
  final String tooltip;
  final VoidCallback? onTap;

  const _CardAction({
    required this.icon,
    required this.enabled,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: enabled ? activeColor : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
