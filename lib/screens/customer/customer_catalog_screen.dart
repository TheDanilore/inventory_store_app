import 'dart:async';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';

class CustomerCatalogScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const CustomerCatalogScreen({super.key, this.onTabSelected});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen>
    with SingleTickerProviderStateMixin {
  Timer? _debounce;
  static const int _pageSize = 8;

  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();
  List<String> _searchHistory = [];
  bool _isSearchMode = false; // CAMBIA ESTA VARIABLE

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  List<ProductModel> _products = [];
  bool _isInitialLoad = true;
  bool _isLoadingProducts = false;
  bool _hasMoreProducts = true;
  int _currentPage = 0;
  String? _productsError;

  // Recomendaciones
  final List<ProductModel> _recommended = [];
  final List<ProductModel> _topSelling = [];
  final bool _loadingRecs = false;
  final bool _loadingTop = false;

  static const Map<String, IconData> _categoryIcons = {
    'Bebidas': Icons.local_drink_outlined,
    'Snacks': Icons.cookie_outlined,
    'Lácteos': Icons.egg_outlined,
    'Carnes': Icons.set_meal_outlined,
    'Frutas': Icons.spa_outlined,
    'Limpieza': Icons.cleaning_services_outlined,
    'Panadería': Icons.bakery_dining_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadSearchHistory(); // Carga el historial al iniciar

    // Escucha cuando el teclado se abre
    _searchFocusNode.addListener(() {
      // SOLO LO ENCIENDE, NO LO APAGA CUANDO PIERDE EL FOCO
      if (_searchFocusNode.hasFocus && !_isSearchMode) {
        setState(() {
          _isSearchMode = true;
        });
      }
    });

    _fetchCategories();
    _refreshProducts();
    // _fetchTopSelling();
  }

  // ─── RECOMENDACIONES ────────────────────────────────────────────────────────

  // Future<void> _fetchTopSelling() async {
  //   setState(() => _loadingTop = true);
  //   try {
  //     final response = await _supabase
  //         .from('mv_top_selling_products')
  //         .select('*, product_images(*)')
  //         .limit(10);

  //     final rows = List<Map<String, dynamic>>.from(response);

  //     // 1. Extraer los IDs de los productos top
  //     final ids =
  //         rows.map((e) => e['id'] as String?).whereType<String>().toList();

  //     // 2. Consultar el stock real para estos IDs específicos
  //     final stock = await _loadStockByProductIds(ids);

  //     if (!mounted) return;

  //     // 3. Asignar el stock al convertir el JSON al modelo Product
  //     setState(() {
  //       _topSelling =
  //           rows
  //               .map(ProductModel.fromJson)
  //               .map((p) => p.copyWith(totalStock: (stock[p.id] ?? 0)))
  //               .toList();
  //     });
  //   } catch (e) {
  //     debugPrint('Top selling error: $e');
  //   } finally {
  //     if (mounted) setState(() => _loadingTop = false);
  //   }
  // }

  // ─── CATEGORÍAS ─────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _supabase
          .from('categories')
          .select('id, name')
          .eq('is_active', true);
      if (mounted) {
        setState(() => _categories = List<Map<String, dynamic>>.from(response));
      }
      await prefs.setString('cached_customer_categories', jsonEncode(response));
    } catch (e) {
      final cached = prefs.getString('cached_customer_categories');
      if (cached != null && mounted) {
        setState(
          () =>
              _categories = List<Map<String, dynamic>>.from(jsonDecode(cached)),
        );
      }
    }
  }

  // ─── PRODUCTOS ──────────────────────────────────────────────────────────────

  Future<void> _refreshProducts() async {
    setState(() {
      _currentPage = 0;
      _products = [];
      _hasMoreProducts = true;
      _productsError = null;
      _isInitialLoad = true;
    });
    await _loadMoreProducts();
  }

  /// Pull-to-refresh: recarga todo incluidas las recomendaciones
  Future<void> _onPullToRefresh() async {
    await Future.wait([
      _refreshProducts(),
      // _fetchTopSelling(),
      _fetchCategories(),
    ]);
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingProducts || !_hasMoreProducts) return;
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    final offset = _currentPage * _pageSize;
    final prefs = await SharedPreferences.getInstance();
    final searchTerm = _searchCtrl.text.trim();

    var query = _supabase
        .from('products')
        .select('*, product_images(*)')
        .eq('is_active', true);

    if (_selectedCategoryId != null) {
      query = query.eq('category_id', _selectedCategoryId!);
    }
    if (searchTerm.isNotEmpty) {
      query = query.ilike('name', '%$searchTerm%');
    }

    try {
      final response = await query
          .order('name')
          .range(offset, offset + _pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response);
      final ids =
          rows.map((e) => e['id'] as String?).whereType<String>().toList();
      final stock = await _loadStockByProductIds(ids);
      final fetched = rows
          .map(ProductModel.fromJson)
          .map((p) => p.copyWith(totalStock: (stock[p.id] ?? 0)))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _products.addAll(fetched);
        _products.sort((a, b) {
          final aOut = a.totalStock <= 0;
          final bOut = b.totalStock <= 0;
          if (!aOut && bOut) return -1;
          if (aOut && !bOut) return 1;
          return 0;
        });
        _currentPage++;
        _hasMoreProducts = fetched.length == _pageSize;
        _isLoadingProducts = false;
        _isInitialLoad = false;
      });

      if (_currentPage == 1 &&
          _selectedCategoryId == null &&
          searchTerm.isEmpty) {
        await prefs.setString(
          'cached_catalog_data',
          jsonEncode({'rows': rows, 'stock': stock}),
        );
      }
    } catch (e) {
      if (_currentPage == 0) {
        final cached = prefs.getString('cached_catalog_data');
        if (cached != null) {
          final decoded = jsonDecode(cached);
          final List rows = decoded['rows'];
          final Map stockMap = decoded['stock'];
          var offline =
              rows
                  .map(
                    (e) => ProductModel.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .map((p) => p.copyWith(totalStock: stockMap[p.id] ?? 0))
                  .toList();

          if (_selectedCategoryId != null) {
            offline =
                offline
                    .where((p) => p.categoryId == _selectedCategoryId)
                    .toList();
          }
          if (searchTerm.isNotEmpty) {
            final s = searchTerm.toLowerCase();
            offline =
                offline.where((p) => p.name.toLowerCase().contains(s)).toList();
          }
          if (mounted) {
            setState(() {
              _products = offline;
              _isLoadingProducts = false;
              _isInitialLoad = false;
              _hasMoreProducts = false;
            });
          }
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _productsError = 'Estás sin conexión a internet';
        _isLoadingProducts = false;
        _isInitialLoad = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _products.clear();
        _currentPage = 0;
        _hasMoreProducts = true;
        _isInitialLoad = true;
      });
      _loadMoreProducts();
    });
  }

  // ─── STOCK ──────────────────────────────────────────────────────────────────

  Future<Map<String, int>> _loadStockByProductIds(List<String> ids) async {
    if (ids.isEmpty) return {};

    try {
      // Se cambió available_quantity por total_stock
      final response = await _supabase
          .from('product_stock_summary')
          .select('product_id, total_stock')
          .inFilter('product_id', ids);

      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final pid = row['product_id'] as String?;
        if (pid == null) continue;
        // Se cambió available_quantity por total_stock
        final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
        map[pid] = (map[pid] ?? 0) + stock;
      }
      return map;
    } catch (e) {
      debugPrint('Error de código en _loadStockByProductIds: $e');
      return {};
    }
  }

  Future<Map<String, int>> _loadStockByVariant(String productId) async {
    try {
      // Se cambió available_quantity por total_stock
      final response = await _supabase
          .from('product_stock_summary')
          .select('variant_id, total_stock')
          .eq('product_id', productId);

      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final vid = row['variant_id'] as String?;
        if (vid == null) continue;
        // Se cambió available_quantity por total_stock
        final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
        map[vid] = (map[vid] ?? 0) + stock;
      }
      return map;
    } catch (e) {
      debugPrint('Error de código en _loadStockByVariant: $e');
      return {};
    }
  }

  Future<List<ProductVariantModel>> _loadActiveVariants(
    String productId,
  ) async {
    final response = await _supabase
        .from('product_variants')
        .select(
          'id, product_id, sku, product_images(id, image_url, is_main, display_order), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, variant_attribute_values(attribute_values(id, value, attributes(id, name)))',
        )
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      response,
    ).map(ProductVariantModel.fromJson).toList();
  }

  // ─── CARRITO ────────────────────────────────────────────────────────────────

  Future<void> _addProductToCart(ProductModel product) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    List<ProductVariantModel> variants = [];
    Map<String, int> stockByVar = {};

    try {
      variants = await _loadActiveVariants(product.id);
      if (variants.isNotEmpty) {
        stockByVar = await _loadStockByVariant(product.id);
      }
    } catch (_) {}

    if (variants.isNotEmpty) {
      ProductVariantModel? sel;
      for (final v in variants) {
        if ((stockByVar[v.id] ?? 0) > 0) {
          sel = v;
          break;
        }
      }
      sel ??= variants.first;
      final selStock = (stockByVar[sel.id] ?? 0);
      if (selStock <= 0) {
        if (mounted) {
          _showSnack('Sin stock disponible para este producto', isError: true);
        }
        return;
      }
      cart.addItem(
        product,
        variantId: sel.id,
        variantLabel: sel.label,
        unitPrice: sel.salePrice ?? product.salePrice,
        imageUrl:
            sel.images.isNotEmpty
                ? sel.images.first.imageUrl
                : (product.images.isNotEmpty
                    ? product.images.first.imageUrl
                    : null),
        sku: null,
        availableStock: selStock,
      );
    } else {
      // Cambiamos product.currentStock por product.totalStock
      cart.addItem(product, availableStock: product.totalStock);
    }
    if (mounted) _showSnack('${product.name} añadido al carrito');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.accent : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose(); // No olvides limpiar el nodo
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchTerm(String term) async {
    if (term.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    // Removemos si ya existe para ponerla al inicio (hacerla la más reciente)
    _searchHistory.removeWhere(
      (item) => item.toLowerCase() == term.toLowerCase(),
    );
    _searchHistory.insert(0, term.trim());

    // Mantenemos solo las últimas 10 búsquedas
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }

    await prefs.setStringList('search_history', _searchHistory);
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory.clear();
    });
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final businessName = config.businessName;
    final userId = _supabase.auth.currentUser?.id;

    // AHORA USAMOS _isSearchMode
    final bool isSearching = _isSearchMode || _searchCtrl.text.isNotEmpty;

    // Obtenemos la altura del área segura (Status bar)
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomerLayout(
      onTabSelected: widget.onTabSelected,
      showAppBar: true,
      hideAppBarOnScroll: true,
      title: businessName.isNotEmpty ? businessName : 'Catálogo',
      body: RefreshIndicator(
        onRefresh: _onPullToRefresh,
        color: AppColors.primary,
        strokeWidth: 2.5,
        displacement: 60,
        child: NotificationListener<ScrollNotification>(
          onNotification: (info) {
            if (info.metrics.pixels >= info.metrics.maxScrollExtent - 280) {
              _loadMoreProducts();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── 1. Welcome banner (SE OCULTA AL BUSCAR) ──
              if (!isSearching) SliverToBoxAdapter(child: _WelcomeBanner()),

              // ── 2. Search bar (SIEMPRE VISIBLE) ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchDelegate(
                  child: _SearchBar(
                    ctrl: _searchCtrl,
                    focusNode: _searchFocusNode,
                    isSearching: isSearching,
                    onBack: () {
                      // AHORA APAGAMOS LA VISTA MANUALMENTE AQUÍ
                      setState(() {
                        _isSearchMode = false;
                      });
                      _searchCtrl.clear();
                      _searchFocusNode.unfocus();
                      _refreshProducts();
                    },
                    onClear: () {
                      _searchCtrl.clear();
                      _refreshProducts();
                    },
                    onChanged: _onSearchChanged,
                    onSubmitted: (term) {
                      _saveSearchTerm(term);
                      _searchFocusNode.unfocus();
                    },
                  ),
                  statusBarHeight: topPadding, // <-- PASAMOS LA ALTURA REAL
                ),
              ),

              // =========================================================
              // VISTA A: ESTÁ BUSCANDO (PERO AÚN NO ESCRIBE NADA) -> HISTORIAL
              // =========================================================
              if (isSearching && _searchCtrl.text.isEmpty) ...[
                SliverToBoxAdapter(
                  child:
                      _searchHistory.isEmpty
                          ? const SizedBox(height: 50)
                          : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Historial de búsqueda',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.textHint,
                                        size: 20,
                                      ),
                                      onPressed: _clearHistory,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      _searchHistory.map((term) {
                                        return ActionChip(
                                          label: Text(
                                            term,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          onPressed: () {
                                            _searchCtrl.text = term;
                                            _searchFocusNode.unfocus();
                                            _saveSearchTerm(term);
                                            _refreshProducts();
                                          },
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                ),
                // mostramos sugerencias debajo del historial
                if (!_loadingTop && _topSelling.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductRow(
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.info,
                      title: 'Sugerencias para ti',
                      subtitle: 'Lo más buscado esta semana',
                      products: _topSelling,
                      onAddToCart: _addProductToCart,
                    ),
                  ),
              ]
              // =========================================================
              // VISTA B: RESULTADOS DE BÚSQUEDA (CUANDO YA ESCRIBIÓ ALGO)
              // =========================================================
              else if (isSearching && _searchCtrl.text.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'Resultados para "${_searchCtrl.text}"',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ]
              // =========================================================
              // VISTA C: CATÁLOGO NORMAL (NO ESTÁ BUSCANDO NADA)
              // =========================================================
              else ...[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const _PromoBanner(),
                      const SizedBox(height: 20),
                      if (_categories.isNotEmpty) ...[
                        const _SectionTitle(text: 'Categorías', horizontal: 16),
                        const SizedBox(height: 10),
                        _CategoryList(
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          categoryIcons: _categoryIcons,
                          onSelected: (id) {
                            setState(() => _selectedCategoryId = id);
                            _refreshProducts();
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── Bloque 1: Lo más vendido ──────────────────────────────
                if (!_loadingTop && _topSelling.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductRow(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppColors.orange,
                      title: 'Lo más vendido',
                      subtitle: 'Tendencias esta semana',
                      products: _topSelling,
                      onAddToCart: _addProductToCart,
                    ),
                  ),
                if (_loadingTop)
                  const SliverToBoxAdapter(child: _HorizontalShimmer()),

                // ── Bloque 2: Recomendados (solo si hay usuario) ──────────
                if (userId != null && !_loadingRecs && _recommended.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductRow(
                      icon: Icons.stars_rounded,
                      iconColor: AppColors.amber,
                      title: 'Para ti',
                      subtitle: 'Novedades en tus categorías favoritas',
                      products: _recommended,
                      onAddToCart: _addProductToCart,
                    ),
                  ),
                if (userId != null && _loadingRecs)
                  const SliverToBoxAdapter(child: _HorizontalShimmer()),
                if (!_isInitialLoad &&
                    _productsError == null &&
                    _products.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _CatalogHeader(
                      total: _products.length,
                      selectedCategoryId: _selectedCategoryId,
                      categories: _categories,
                    ),
                  ),
              ],

              // ── LA GRILLA SE COMPARTE PARA LA VISTA B Y C ──────────────────
              if ((!isSearching) ||
                  (isSearching && _searchCtrl.text.isNotEmpty)) ...[
                if (_isInitialLoad)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: _LoadingState(),
                    ),
                  )
                else if (_productsError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: _ErrorState(onRetry: _refreshProducts),
                    ),
                  )
                else if (_products.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: _EmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _products.length) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          return ProductCard(
                            product: _products[index],
                            onAddToCart: _addProductToCart,
                          );
                        },
                        childCount:
                            _products.length + (_isLoadingProducts ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── WELCOME BANNER ──────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    // watch aquí garantiza que el banner se reconstruye cuando businessName cambia
    final config = context.watch<AppConfigProvider>();
    final businessName = config.businessName;
    final businessAddress = config.businessAddress;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Círculos decorativos
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Tienda Oficial',
                        style: TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido${businessName.isNotEmpty ? " a $businessName" : ""} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      businessAddress.isNotEmpty
                          ? businessAddress
                          : 'Los mejores productos al mejor precio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SEARCH BAR ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool isSearching; // Define si estamos en "Modo Vista Búsqueda"
  final VoidCallback onBack;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.ctrl,
    required this.focusNode,
    required this.isSearching,
    required this.onBack,
    required this.onClear,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // FLECHA DE ATRÁS O LUPA
          if (isSearching)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              onPressed: onBack,
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 10),
              child: Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),

          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
              decoration: const InputDecoration(
                // CAMBIO AQUÍ: Agrega padding horizontal para separar el texto del borde
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                hintText: 'Buscar productos…',
                hintStyle: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          // BOTÓN [X] PARA BORRAR TEXTO (Usa ValueListenable para ser instantáneo)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: ctrl,
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: onClear,
                );
              }
              return isSearching
                  ? const SizedBox(width: 48)
                  : const SizedBox(width: 16);
            },
          ),
        ],
      ),
    );
  }
}
// ─── PROMO BANNER ────────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ofertas del día',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Descubre nuestros mejores combos',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap:
                    () => AppSnackbar.show(
                      context,
                      message:
                          'Próximamente: Ofertas relámpago y descuentos exclusivos',
                      type: SnackbarType.error,
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ver',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CATEGORY LIST ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final double horizontal;
  const _SectionTitle({required this.text, this.horizontal = 16});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontal),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
  );
}

class _CategoryList extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final Map<String, IconData> categoryIcons;
  final ValueChanged<String?> onSelected;

  const _CategoryList({
    required this.categories,
    required this.selectedCategoryId,
    required this.categoryIcons,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CategoryChip(
            id: null,
            name: 'Todos',
            icon: Icons.apps_rounded,
            isSelected: selectedCategoryId == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map(
            (cat) => _CategoryChip(
              id: cat['id'] as String?,
              name: cat['name'] as String,
              icon: categoryIcons[cat['name']] ?? Icons.category_rounded,
              isSelected: selectedCategoryId == cat['id'],
              onTap: () => onSelected(cat['id'] as String?),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String? id;
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.id,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HORIZONTAL PRODUCT ROW (Recomendaciones / Top Selling) ──────────────────

class _HorizontalProductRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<ProductModel> products;
  final Future<void> Function(ProductModel) onAddToCart;

  const _HorizontalProductRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scroll horizontal de cards
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: products.length,
            itemBuilder:
                (context, index) => _HorizontalProductCard(
                  product: products[index],
                  onAddToCart: onAddToCart,
                ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _HorizontalProductCard extends StatelessWidget {
  final ProductModel product;
  final Future<void> Function(ProductModel) onAddToCart;

  const _HorizontalProductCard({
    required this.product,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isAgotado = product.totalStock <= 0;
    final imageUrl =
        product.images.isNotEmpty
            ? product.images
                .firstWhere((i) => i.isMain, orElse: () => product.images.first)
                .imageUrl
            : null;

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.cardShadow(),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppColors.radius),
                    ),
                    child:
                        imageUrl != null
                            ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, _) => const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (_, _, _) => Container(
                                    color: AppColors.bg,
                                    child: const Icon(
                                      Icons.image_rounded,
                                      color: AppColors.textMuted,
                                      size: 28,
                                    ),
                                  ),
                            )
                            : Container(
                              color: AppColors.bg,
                              child: const Icon(
                                Icons.image_rounded,
                                color: AppColors.textMuted,
                                size: 28,
                              ),
                            ),
                  ),
                  if (isAgotado)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppColors.radius),
                      ),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.75),
                        child: const Center(
                          child: Text(
                            'Agotado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'S/ ${product.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      if (!isAgotado)
                        GestureDetector(
                          onTap: () => onAddToCart(product),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
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

// ─── HORIZONTAL SHIMMER ──────────────────────────────────────────────────────

class _HorizontalShimmer extends StatefulWidget {
  const _HorizontalShimmer();
  @override
  State<_HorizontalShimmer> createState() => _HorizontalShimmerState();
}

class _HorizontalShimmerState extends State<_HorizontalShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AnimatedBuilder(
              animation: _anim,
              builder:
                  (_, _) => Container(
                    width: 160,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: _anim.value),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              itemBuilder:
                  (_, _) => AnimatedBuilder(
                    animation: _anim,
                    builder:
                        (_, _) => Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(
                              alpha: _anim.value,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppColors.radius,
                            ),
                          ),
                        ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CATALOG HEADER ──────────────────────────────────────────────────────────

class _CatalogHeader extends StatelessWidget {
  final int total;
  final String? selectedCategoryId;
  final List<Map<String, dynamic>> categories;

  const _CatalogHeader({
    required this.total,
    required this.selectedCategoryId,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final catName =
        selectedCategoryId == null
            ? 'Todo el catálogo'
            : (categories.firstWhere(
                      (c) => c['id'] == selectedCategoryId,
                      orElse: () => {'name': ''},
                    )['name']
                    as String? ??
                '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                if (catName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    catName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total productos',
              style: const TextStyle(
                color: AppColors.tealDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ESTADOS VACÍO / ERROR / CARGANDO ────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      color: AppColors.primary,
      strokeWidth: 2.5,
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

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
                Icons.wifi_off_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin conexión',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifica tu conexión e intenta de nuevo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Prueba con otra búsqueda o categoría',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── PRODUCT CARD (Grilla principal) ─────────────────────────────────────────

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final Future<void> Function(ProductModel) onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isCardHovered = false;
  bool _isButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isAgotado = product.totalStock <= 0;

    final imageUrl =
        product.images.isNotEmpty
            ? product.images
                .firstWhere(
                  (img) => img.isMain,
                  orElse: () => product.images.first,
                )
                .imageUrl
            : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isCardHovered = true),
      onExit: (_) => setState(() => _isCardHovered = false),
      child: GestureDetector(
        onTap: () => context.push('/product/${product.id}', extra: product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isCardHovered ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: _isCardHovered ? 0.12 : 0.07,
                ),
                blurRadius: _isCardHovered ? 20 : 14,
                offset: Offset(0, _isCardHovered ? 6 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Imagen ──────────────────────────────────────────────
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child:
                            imageUrl != null
                                ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (_, _) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                  errorWidget: (_, _, _) => _buildPlaceholder(),
                                )
                                : _buildPlaceholder(),
                      ),
                    ),

                    // Overlay agotado
                    if (isAgotado)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.75),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_shopping_cart_outlined,
                                    size: 28,
                                    color: AppColors.textHint,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Agotado',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Badge últimas unidades
                    if (!isAgotado && product.totalStock <= 5)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '¡Últimas ${product.totalStock}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Info ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                        height: 1.25,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'S/ ${product.salePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        MouseRegion(
                          cursor:
                              isAgotado
                                  ? SystemMouseCursors.basic
                                  : SystemMouseCursors.click,
                          onEnter:
                              (_) => setState(() => _isButtonHovered = true),
                          onExit:
                              (_) => setState(() => _isButtonHovered = false),
                          child: GestureDetector(
                            onTap:
                                isAgotado
                                    ? null
                                    : () => widget.onAddToCart(product),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color:
                                    isAgotado
                                        ? AppColors.background
                                        : _isButtonHovered
                                        ? AppColors.primary.withValues(
                                          alpha: 0.8,
                                        )
                                        : AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color:
                                    isAgotado
                                        ? AppColors.textHint
                                        : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
    color: AppColors.background,
    child: const Center(
      child: Icon(Icons.image_outlined, size: 36, color: Color(0xFFD0D5E8)),
    ),
  );
}

// ─── STICKY SEARCH DELEGATE ───────────────────────────────────────────────────

class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double statusBarHeight;

  const _StickySearchDelegate({
    required this.child,
    required this.statusBarHeight,
  });

  // Sumamos la altura del status bar al tamaño original (68.0)
  @override
  double get minExtent => 68.0 + statusBarHeight;
  @override
  double get maxExtent => 68.0 + statusBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: maxExtent,
          alignment: Alignment.bottomCenter, // Asegura que se alinee abajo
          color: Colors.white.withValues(alpha: 0.82),
          // Sumamos statusBarHeight al padding superior (9 + statusBarHeight)
          padding: EdgeInsets.fromLTRB(16, 9 + statusBarHeight, 16, 9),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate old) =>
      old.statusBarHeight != statusBarHeight || old.child != child;
}
