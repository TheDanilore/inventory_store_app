import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/screens/admin/pos_checkout_screen.dart';
import 'package:inventory_store_app/services/admin/catalog_pdf_generator.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/data/admin/products_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Widgets extraídos
import 'package:inventory_store_app/screens/admin/widgets/catalog_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_category_chips.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_grid_view.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_add_to_cart_sheet.dart';

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
  final _productsRepo = ProductsRepository();

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
      // _catalogService.loadProducts YA inyecta el totalStock ahora
      final productsWithStock = await _catalogService.loadProducts(
        categoryId: _selectedCategoryId,
        searchTerm: _searchCtrl.text,
        isAdmin: true,
      );

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
        .inFilter('id', uniqueProductIds);

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

    // Uso de fetchProductStock() que ya optimizamos en _productsRepo
    final stockByProduct = await _productsRepo.fetchProductStock(
      productIds: uniqueProductIds,
    );

    return productsList
        .map((p) => p.copyWith(totalStock: stockByProduct[p.id] ?? 0))
        .toList();
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
      final variantsByProduct = await _catalogService.loadVariantsByProductIds(
        productIds,
      );
      final allVariantIds =
          variantsByProduct.values
              .expand((v) => v)
              .map((v) => v.id)
              .whereType<String>()
              .toList();
      final stockByVariant = await _catalogService.loadVariantStockByVariantIds(
        allVariantIds,
      );

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
      builder: (_) => AdminAddToCartSheet(product: product),
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
