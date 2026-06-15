import 'dart:async';
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
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Widgets extraídos
import 'package:inventory_store_app/screens/admin/widgets/catalog_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_category_chips.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_grid_view.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_add_to_cart_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_dialogs.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_status_states.dart';
import 'package:inventory_store_app/screens/admin/widgets/catalog_fab_buttons.dart';

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
    try {
      final categories = await _catalogService.loadCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
    }
  }

  Future<List<ProductModel>> _loadProducts() async {
    try {
      if (_searchByIngredient) {
        if (_searchCtrl.text.trim().isNotEmpty) {
          final result = await _catalogService.loadProductsByIngredient(
            searchTerm: _searchCtrl.text.trim(),
            categoryId: _selectedCategoryId,
            isAdmin: true,
          );
          _matchedIngredients = result.matches;
          return result.products;
        } else {
          _matchedIngredients = {};
          return [];
        }
      }

      final products = await _catalogService.loadProducts(
        categoryId: _selectedCategoryId,
        searchTerm: _searchCtrl.text,
        isAdmin: true,
      );
      return products;
    } catch (e) {
      debugPrint('Error loading products: $e');
      rethrow;
    }
  }

  Future<void> _exportCatalogPdf() async {
    if (_isExportingPdf) return;
    try {
      final allProducts = await _loadProducts();
      if (!mounted) return;

      final visibleProducts =
          allProducts.skip(_currentPage * _pageSize).take(_pageSize).toList();

      final max50Products = allProducts.take(50).toList();

      if (max50Products.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos para exportar.',
          type: SnackbarType.error,
        );
        return;
      }

      final options = await CatalogDialogs.showExportOptionsDialog(
        context,
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
    final confirm = await CatalogDialogs.showToggleProductActiveDialog(
      context,
      product,
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
          _refreshProducts();
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
    final delay = _searchByIngredient ? 800 : 500;
    _debounce = Timer(Duration(milliseconds: delay), () {
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

  Future<void> _forceSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_admin_categories');
    await prefs.remove('cached_admin_products');

    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: 'Caché limpiada. Sincronizando catálogo...',
      type: SnackbarType.success,
    );
    _fetchCategories();
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
      settingsActions: const [
        PopupMenuItem(value: 'export', child: Text('Exportar')),
        PopupMenuItem(value: 'sync', child: Text('Forzar Sincronización')),
      ],
      onSettingsSelected: (value) {
        switch (value) {
          case 'export':
            _exportCatalogPdf();
            break;
          case 'sync':
            _forceSync();
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
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 280,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AppShimmer(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: AppColors.radiusLg,
                        ),
                        childCount: 8,
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
                    child: CatalogErrorState(message: '${snapshot.error}'),
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
                    child: CatalogEmptyState(
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
              return CatalogPosCartButton(
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
          CatalogAddProductFab(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
              if (result == true) {
                setState(() => _currentPage = 0);
                _refreshProducts();
              }
            },
          ),
        ],
      ),
    );
  }
}
