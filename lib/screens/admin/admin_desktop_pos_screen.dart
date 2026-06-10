import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/screens/admin/admin_pos_checkout_screen.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminDesktopPosScreen
//  Vista TPV dedicada para desktop/web (≥ 900 px).
//  Tres columnas: categorías | productos | carrito+cobro
// ─────────────────────────────────────────────────────────────────────────────

class AdminDesktopPosScreen extends StatefulWidget {
  const AdminDesktopPosScreen({super.key});

  @override
  State<AdminDesktopPosScreen> createState() => _AdminDesktopPosScreenState();
}

class _AdminDesktopPosScreenState extends State<AdminDesktopPosScreen> {
  final _supabase = Supabase.instance.client;
  final _catalogService = CatalogService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // ── Catálogo ──────────────────────────────────────────────────────────────
  List<CategoryModel> _categories = [];
  String? _selectedCategoryId;
  Future<List<ProductModel>>? _productsFuture;
  bool _loadingCategories = true;

  // ── Producto seleccionado (panel de cantidad/variante) ────────────────────
  ProductModel? _focusedProduct;
  List<ProductVariantModel> _focusedVariants = [];
  Map<String, int> _focusedStock = {};
  ProductVariantModel? _focusedVariant;
  int _focusedQty = 1;
  bool _loadingFocused = false;

  // ── Checkout ──────────────────────────────────────────────────────────────
  List<WarehouseModel> _warehouseList = [];
  List<Map<String, dynamic>> _accountsList = [];
  String? _selectedAccountId;
  Map<String, dynamic>? _activeShift;

  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();
  List<Map<String, dynamic>> _clientMatches = [];
  bool _searchingClients = false;
  int _clientSearchVersion = 0;
  Timer? _clientDebounce;
  Map<String, dynamic>? _creditInfo;
  bool _isDiscountPercentage = false;
  final bool _isProcessingSale = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _refreshProducts();
    final pos = context.read<PosProvider>();
    _clienteCtrl.text = pos.selectedClientName ?? '';
    _puntosCtrl.text = pos.puntosAUsar.toString();
    _loadCheckoutData(pos);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clienteCtrl.dispose();
    _puntosCtrl.dispose();
    _descuentoCtrl.dispose();
    _debounce?.cancel();
    _clientDebounce?.cancel();
    super.dispose();
  }

  // ── Catálogo ──────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    try {
      final cats = await _catalogService.loadCategories();
      if (mounted) {
        setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _loadProducts();
      _focusedProduct = null; // limpiar selección al refrescar
    });
  }

  Future<List<ProductModel>> _loadProducts() async {
    try {
      final products = await _catalogService.loadProducts(
        categoryId: _selectedCategoryId,
        searchTerm: _searchCtrl.text,
        isAdmin: true,
      );
      if (products.isEmpty) return products;

      final productIds = products.map((p) => p.id).toList();
      final stockResp = await _supabase
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
      return products.map((p) => p.copyWith(totalStock: stockByProduct[p.id] ?? 0)).toList();
    } catch (_) {
      return [];
    }
  }

  void _onSearchChanged(String _) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _productsFuture = _loadProducts());
    });
  }

  // ── Foco de producto (panel central derecho) ──────────────────────────────

  Future<void> _focusProduct(ProductModel product) async {
    setState(() {
      _focusedProduct = product;
      _focusedVariants = [];
      _focusedStock = {};
      _focusedVariant = null;
      _focusedQty = 1;
      _loadingFocused = true;
    });

    try {
      final varResp = await _supabase
          .from('product_variants')
          .select('*, product_images(*)')
          .eq('product_id', product.id)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final variants = List<Map<String, dynamic>>.from(varResp)
          .map(ProductVariantModel.fromJson)
          .toList();

      final stockMap = <String, int>{};
      if (variants.isNotEmpty) {
        final ids = variants.map((v) => v.id).toList();
        final invResp = await _supabase
            .from('warehouse_stock_batches')
            .select('variant_id, available_quantity')
            .inFilter('variant_id', ids);
        for (final row in List<Map<String, dynamic>>.from(invResp)) {
          final vid = row['variant_id'] as String?;
          if (vid != null) {
            final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
            stockMap[vid] = (stockMap[vid] ?? 0) + qty;
          }
        }
      }

      if (mounted) {
        setState(() {
          _focusedVariants = variants;
          _focusedStock = stockMap;
          _focusedVariant = variants.isNotEmpty
              ? variants.firstWhere((v) => (stockMap[v.id] ?? 0) > 0, orElse: () => variants.first)
              : null;
          _loadingFocused = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFocused = false);
    }
  }

  int get _focusedCurrentStock {
    if (_focusedVariants.isEmpty) return _focusedProduct?.totalStock ?? 0;
    if (_focusedVariant == null) return 0;
    return _focusedStock[_focusedVariant!.id] ?? 0;
  }

  double get _focusedCurrentPrice {
    if (_focusedVariants.isEmpty) return _focusedProduct?.salePrice ?? 0;
    return _focusedVariant?.salePrice ?? _focusedProduct?.salePrice ?? 0;
  }

  void _addFocusedToCart() {
    final product = _focusedProduct;
    if (product == null) return;
    final stock = _focusedCurrentStock;
    if (stock <= 0) {
      AppSnackbar.show(context, message: 'Sin stock disponible', type: SnackbarType.error);
      return;
    }
    final imageUrl = _focusedVariant?.images.isNotEmpty == true
        ? _focusedVariant!.images.first.imageUrl
        : product.primaryImageUrl;

    context.read<PosProvider>().addProductToPos(
      product: product,
      quantity: _focusedQty,
      variantId: _focusedVariant?.id,
      variantLabel: _focusedVariant?.label,
      unitPrice: _focusedCurrentPrice,
      wholesalePrice: _focusedVariant?.wholesalePrice ?? product.wholesalePrice,
      imageUrl: imageUrl,
      sku: _focusedVariant?.sku,
      availableStock: stock,
    );

    AppSnackbar.show(context, message: '${product.name} añadido', type: SnackbarType.success);

    // Resetear cantidad para el siguiente item
    setState(() => _focusedQty = 1);
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<void> _loadCheckoutData(PosProvider pos) async {
    try {
      final whRes = await _supabase.from('warehouses').select().eq('is_active', true).order('name');
      final list = (whRes as List).map((w) => WarehouseModel.fromJson(w)).toList();

      final accRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('type')
          .order('name');
      final accs = List<Map<String, dynamic>>.from(accRes);

      if (!mounted) return;
      setState(() {
        _warehouseList = list;
        if (pos.selectedWarehouseId == null && list.isNotEmpty) pos.setWarehouse(list.first.id);
        _accountsList = accs;
        if (accs.isNotEmpty) {
          final firstAcc = accs.firstWhere((a) => a['type'] == 'CAJA', orElse: () => accs.first);
          _selectedAccountId = firstAcc['id'] as String;
          if (pos.paymentMethod != 'CRÉDITO') pos.setPaymentMethod(firstAcc['name'] as String);
          _checkActiveShift();
        }
      });
    } catch (_) {}
  }

  Future<void> _checkActiveShift() async {
    if (_selectedAccountId == null) return;
    try {
      final acc = _accountsList.firstWhere((a) => a['id'] == _selectedAccountId, orElse: () => {});
      if (acc['type'] != 'CAJA') {
        if (mounted) setState(() => _activeShift = null);
        return;
      }
      final res = await _supabase
          .from('cash_shifts')
          .select('id, status')
          .eq('account_id', _selectedAccountId!)
          .eq('status', 'OPEN')
          .maybeSingle();
      if (mounted) setState(() => _activeShift = res);
    } catch (_) {}
  }

  void _onClientSearchChanged(String query) {
    final pos = context.read<PosProvider>();
    if (pos.selectedClientId != null) {
      pos.setClient(null, null, 0);
      _puntosCtrl.text = '0';
      setState(() => _creditInfo = null);
    }
    if (_clientDebounce?.isActive ?? false) _clientDebounce!.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 500), () => _searchClients(query));
  }

  Future<void> _searchClients(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      if (mounted) setState(() { _clientMatches = []; _searchingClients = false; });
      return;
    }
    final version = ++_clientSearchVersion;
    if (mounted) setState(() => _searchingClients = true);
    try {
      final resp = await _supabase
          .from('profiles')
          .select('id, full_name, phone, document_number, wallet_balance')
          .or('full_name.ilike.%$text%,phone.ilike.%$text%,document_number.ilike.%$text%')
          .eq('is_active', true)
          .limit(8);
      if (mounted && version == _clientSearchVersion) {
        setState(() { _clientMatches = List<Map<String, dynamic>>.from(resp); _searchingClients = false; });
      }
    } catch (_) {
      if (mounted && version == _clientSearchVersion) setState(() => _searchingClients = false);
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    final pos = context.read<PosProvider>();
    pos.setClient(client['id'], client['full_name'], (client['wallet_balance'] as num?)?.toInt() ?? 0);
    _clienteCtrl.text = client['full_name'] as String;
    setState(() => _clientMatches = []);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _TopBar(onClose: () => Navigator.maybePop(context)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Col 1 — Categorías (sidebar angosto)
                _CategorySidebar(
                  categories: _categories,
                  loading: _loadingCategories,
                  selectedId: _selectedCategoryId,
                  onSelect: (id) {
                    setState(() {
                      _selectedCategoryId = id;
                      _currentPage = 0;
                    });
                    _refreshProducts();
                  },
                ),

                // Col 2 — Grid de productos
                Expanded(
                  flex: 55,
                  child: _ProductsPanel(
                    searchCtrl: _searchCtrl,
                    onSearchChanged: _onSearchChanged,
                    productsFuture: _productsFuture,
                    focusedProduct: _focusedProduct,
                    currentPage: _currentPage,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    onProductTap: _focusProduct,
                  ),
                ),

                // Col 3 — Panel derecho (producto seleccionado + carrito + cobro)
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      // Producto seleccionado
                      _FocusedProductPanel(
                        product: _focusedProduct,
                        variants: _focusedVariants,
                        stockByVariant: _focusedStock,
                        selectedVariant: _focusedVariant,
                        quantity: _focusedQty,
                        loading: _loadingFocused,
                        onVariantChanged: (v) => setState(() { _focusedVariant = v; _focusedQty = 1; }),
                        onQtyChanged: (q) => setState(() => _focusedQty = q),
                        onAdd: _addFocusedToCart,
                      ),
                      // Carrito + cobro
                      Expanded(
                        child: _CartAndCheckoutPanel(
                          supabase: _supabase,
                          warehouseList: _warehouseList,
                          accountsList: _accountsList,
                          selectedAccountId: _selectedAccountId,
                          activeShift: _activeShift,
                          clienteCtrl: _clienteCtrl,
                          puntosCtrl: _puntosCtrl,
                          descuentoCtrl: _descuentoCtrl,
                          clientMatches: _clientMatches,
                          searchingClients: _searchingClients,
                          creditInfo: _creditInfo,
                          isDiscountPercentage: _isDiscountPercentage,
                          isProcessingSale: _isProcessingSale,
                          onClientSearchChanged: _onClientSearchChanged,
                          onClientSelect: _selectClient,
                          onClientClear: () {
                            context.read<PosProvider>().setClient(null, null, 0);
                            _clienteCtrl.clear();
                            setState(() { _clientMatches = []; _creditInfo = null; });
                          },
                          onAccountChanged: (id) {
                            setState(() => _selectedAccountId = id);
                            if (id != null) {
                              final acc = _accountsList.firstWhere((a) => a['id'] == id, orElse: () => {});
                              context.read<PosProvider>().setPaymentMethod(acc['name'] as String? ?? '');
                            }
                            _checkActiveShift();
                          },
                          onDiscountTypeToggle: (v) => setState(() => _isDiscountPercentage = v),
                          onSaleCompleted: () {
                            _refreshProducts();
                            setState(() => _focusedProduct = null);
                          },
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

  int _currentPage = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.point_of_sale_rounded, size: 16, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          const Text('Caja POS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          Consumer<PosProvider>(
            builder: (_, pos, __) => pos.itemCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${pos.itemCount} producto${pos.itemCount != 1 ? 's' : ''} en caja',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal)),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
            tooltip: 'Cerrar POS',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final bool loading;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategorySidebar({
    required this.categories,
    required this.loading,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8EFF5))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EFF5))),
            ),
            child: const Text('Categorías',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted,
                    letterSpacing: 0.5)),
          ),
          // "Todos"
          _CatItem(
            label: 'Todos',
            icon: Icons.grid_view_rounded,
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                itemBuilder: (_, i) => _CatItem(
                  label: categories[i].name,
                  icon: Icons.label_rounded,
                  selected: selectedId == categories[i].id,
                  onTap: () => onSelect(categories[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CatItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.teal : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? AppColors.teal : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.teal : AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRODUCTS PANEL
// ─────────────────────────────────────────────────────────────────────────────

const int _kPageSize = 15;

class _ProductsPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final Future<List<ProductModel>>? productsFuture;
  final ProductModel? focusedProduct;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ProductModel> onProductTap;

  const _ProductsPanel({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.productsFuture,
    required this.focusedProduct,
    required this.currentPage,
    required this.onPageChanged,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE8EFF5))),
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8EFF5))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8EFF5))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EFF5)),

          // Grid
          Expanded(
            child: FutureBuilder<List<ProductModel>>(
              future: productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)));
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textHint),
                      SizedBox(height: 8),
                      Text('Sin productos', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                  );
                }

                final total = products.length;
                final totalPages = (total / _kPageSize).ceil();
                final safeCurrentPage = currentPage >= totalPages ? totalPages - 1 : currentPage;
                final start = safeCurrentPage * _kPageSize;
                final end = (start + _kPageSize).clamp(0, total);
                final pageItems = products.sublist(start, end);

                return Column(
                  children: [
                    // Contador
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Text('$total producto${total != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (totalPages > 1)
                          Text('Pág. ${safeCurrentPage + 1} / $totalPages',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ]),
                    ),
                    // Grid de cards
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: pageItems.length,
                        itemBuilder: (_, i) => _PosProductCard(
                          product: pageItems[i],
                          isSelected: focusedProduct?.id == pageItems[i].id,
                          onTap: () => onProductTap(pageItems[i]),
                        ),
                      ),
                    ),
                    // Paginación
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: safeCurrentPage > 0 ? () => onPageChanged(safeCurrentPage - 1) : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                              style: IconButton.styleFrom(foregroundColor: AppColors.teal),
                            ),
                            ...List.generate(totalPages, (i) => _PageDot(
                              page: i,
                              current: safeCurrentPage,
                              onTap: () => onPageChanged(i),
                            )),
                            IconButton(
                              onPressed: safeCurrentPage < totalPages - 1 ? () => onPageChanged(safeCurrentPage + 1) : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                              style: IconButton.styleFrom(foregroundColor: AppColors.teal),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PosProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isSelected;
  final VoidCallback onTap;

  const _PosProductCard({required this.product, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.totalStock <= 0;

    return GestureDetector(
      onTap: outOfStock ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.teal.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.teal : const Color(0xFFE8EFF5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.teal.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: Stack(fit: StackFit.expand, children: [
                  product.primaryImageUrl != null
                      ? Image.network(product.primaryImageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _NoImagePlaceholder())
                      : const _NoImagePlaceholder(),
                  // Badge de stock
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: outOfStock ? AppColors.danger : Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        outOfStock ? 'Agotado' : '${product.totalStock}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (outOfStock)
                    Container(color: Colors.white.withValues(alpha: 0.55)),
                ]),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: outOfStock ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('S/ ${product.salePrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: outOfStock ? AppColors.textMuted : AppColors.teal,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF1F5F9),
    child: const Icon(Icons.image_not_supported_rounded, color: AppColors.textHint, size: 28),
  );
}

class _PageDot extends StatelessWidget {
  final int page, current;
  final VoidCallback onTap;
  const _PageDot({required this.page, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = page == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: sel ? 20 : 8, height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: sel ? AppColors.teal : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOCUSED PRODUCT PANEL  (columna derecha — sección superior)
// ─────────────────────────────────────────────────────────────────────────────

class _FocusedProductPanel extends StatelessWidget {
  final ProductModel? product;
  final List<ProductVariantModel> variants;
  final Map<String, int> stockByVariant;
  final ProductVariantModel? selectedVariant;
  final int quantity;
  final bool loading;
  final ValueChanged<ProductVariantModel?> onVariantChanged;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onAdd;

  const _FocusedProductPanel({
    required this.product,
    required this.variants,
    required this.stockByVariant,
    required this.selectedVariant,
    required this.quantity,
    required this.loading,
    required this.onVariantChanged,
    required this.onQtyChanged,
    required this.onAdd,
  });

  double get _price => selectedVariant?.salePrice ?? product?.salePrice ?? 0;
  int get _stock {
    if (variants.isEmpty) return product?.totalStock ?? 0;
    if (selectedVariant == null) return 0;
    return stockByVariant[selectedVariant!.id] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Sin producto seleccionado
    if (product == null) {
      return Container(
        height: 180,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE8EFF5))),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_rounded, size: 32, color: AppColors.textHint),
            SizedBox(height: 8),
            Text('Toca un producto para agregarlo',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
    }

    final imageUrl = selectedVariant?.images.isNotEmpty == true
        ? selectedVariant!.images.first.imageUrl
        : product!.primaryImageUrl;
    final stock = _stock;
    final outOfStock = stock <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EFF5))),
      ),
      padding: const EdgeInsets.all(14),
      child: loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Producto info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _NoImagePlaceholder())
                          : const SizedBox(width: 60, height: 60, child: _NoImagePlaceholder()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product!.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('S/ ${_price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.teal)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: outOfStock ? AppColors.dangerLight : AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        outOfStock ? 'Agotado' : '$stock',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: outOfStock ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                if (variants.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ProductVariantModel>(
                    value: selectedVariant,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE8EFF5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE8EFF5))),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                    ),
                    items: variants.map((v) {
                      final s = stockByVariant[v.id] ?? 0;
                      return DropdownMenuItem(
                        value: v,
                        child: Text('${v.label} · S/ ${(v.salePrice ?? product!.salePrice).toStringAsFixed(2)} ($s u)',
                            style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: onVariantChanged,
                  ),
                ],
                const SizedBox(height: 10),
                // Stepper + botón Añadir
                Row(
                  children: [
                    // Qty stepper
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8EFF5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _SmallQtyBtn(
                          icon: Icons.remove_rounded,
                          enabled: quantity > 1,
                          onTap: () => onQtyChanged(quantity - 1),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final ctrl = TextEditingController(text: quantity.toString());
                            final result = await showDialog<int>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Cantidad', textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  autofocus: true, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    helperText: 'Máx: $stock',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                                    onPressed: () {
                                      final n = int.tryParse(ctrl.text.trim());
                                      Navigator.pop(context, n);
                                    },
                                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (result != null && result > 0) {
                              onQtyChanged(result.clamp(1, stock));
                            }
                            ctrl.dispose();
                          },
                          child: Container(
                            width: 44, alignment: Alignment.center,
                            color: AppColors.teal.withValues(alpha: 0.06),
                            child: Text('$quantity',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.teal)),
                          ),
                        ),
                        _SmallQtyBtn(
                          icon: Icons.add_rounded,
                          enabled: quantity < stock,
                          onTap: () => onQtyChanged(quantity + 1),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    // Botón añadir
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: outOfStock ? null : onAdd,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            disabledBackgroundColor: const Color(0xFFE8EFF5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          label: Text(
                            outOfStock ? 'Sin stock' : 'Añadir · S/ ${(_price * quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SmallQtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _SmallQtyBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(7),
    child: SizedBox(width: 34, height: 40,
        child: Icon(icon, size: 16, color: enabled ? AppColors.textSecondary : AppColors.textHint)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART + CHECKOUT PANEL  (columna derecha — sección inferior)
// ─────────────────────────────────────────────────────────────────────────────

class _CartAndCheckoutPanel extends StatelessWidget {
  final SupabaseClient supabase;
  final List<WarehouseModel> warehouseList;
  final List<Map<String, dynamic>> accountsList;
  final String? selectedAccountId;
  final Map<String, dynamic>? activeShift;
  final TextEditingController clienteCtrl;
  final TextEditingController puntosCtrl;
  final TextEditingController descuentoCtrl;
  final List<Map<String, dynamic>> clientMatches;
  final bool searchingClients;
  final Map<String, dynamic>? creditInfo;
  final bool isDiscountPercentage;
  final bool isProcessingSale;
  final ValueChanged<String> onClientSearchChanged;
  final ValueChanged<Map<String, dynamic>> onClientSelect;
  final VoidCallback onClientClear;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<bool> onDiscountTypeToggle;
  final VoidCallback onSaleCompleted;

  const _CartAndCheckoutPanel({
    required this.supabase,
    required this.warehouseList,
    required this.accountsList,
    required this.selectedAccountId,
    required this.activeShift,
    required this.clienteCtrl,
    required this.puntosCtrl,
    required this.descuentoCtrl,
    required this.clientMatches,
    required this.searchingClients,
    required this.creditInfo,
    required this.isDiscountPercentage,
    required this.isProcessingSale,
    required this.onClientSearchChanged,
    required this.onClientSelect,
    required this.onClientClear,
    required this.onAccountChanged,
    required this.onDiscountTypeToggle,
    required this.onSaleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // El carrito + cobro se delega al AdminPosCheckoutScreen en modo embebido.
    // Esto reutiliza toda la lógica de negocio existente (processSale, crédito, puntos, etc.)
    // sin duplicarla.
    return AdminPosCheckoutScreen(
      embeddedMode: true,
      onSaleCompleted: onSaleCompleted,
    );
  }
}

// ignore: unused_import — necesario para acceder a _BatchAssignment
// desde la misma pantalla cuando se requiera en futuras extensiones.
