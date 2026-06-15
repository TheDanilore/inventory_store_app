// ignore_for_file: unused_element_parameter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/screens/shared/widgets/full_screen_gallery.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_admin_info_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_availability_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_batches_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_quick_decisions_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_reviews_card.dart';
import 'package:inventory_store_app/services/admin/product_pdf_generator.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final bool isAdmin;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isAdmin = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoadingExtra = true;
  bool _isWishlistLoading = true;
  bool _isWishlisted = false;
  bool _showVariantImage = false;

  List<dynamic> _warehouseStocks = [];
  List<Map<String, dynamic>> _batchesList = [];
  List<ProductImageModel> _images = [];
  List<ProductVariantModel> _variants = [];
  List<Map<String, dynamic>> _reviewsList = [];
  List<Map<String, dynamic>> _activeIngredients = [];

  // Para Decisiones Rápidas
  int _totalSold = 0;
  double _reinvestmentNeeded = 0.0;
  double _inventoryValue = 0.0;
  double _totalRevenue = 0.0;
  List<VariantFinancialSummary> _variantSummaries = [];

  double _averageRating = 0.0;

  int _selectedQty = 1;
  int _selectedImageIndex = 0;
  String? _selectedVariantId;
  final Map<String, String> _selectedAttributes = {};
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchWishlistState();
    _fetchExtraData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── DATA ─────────────────────────────────────────────────────────────────

  Future<void> _fetchWishlistState() async {
    if (widget.isAdmin) {
      if (mounted) setState(() => _isWishlistLoading = false);
      return;
    }
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isWishlistLoading = false);
      return;
    }
    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final pid = profile?['id'] as String?;
      if (pid == null) {
        if (mounted) setState(() => _isWishlistLoading = false);
        return;
      }
      final wish =
          await _supabase
              .from('wishlist')
              .select('id')
              .eq('profile_id', pid)
              .eq('product_id', widget.product.id)
              .maybeSingle();
      if (!mounted) return;
      setState(() {
        _isWishlisted = wish != null;
        _isWishlistLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isWishlistLoading = false);
    }
  }

  Future<void> _toggleWishlist() async {
    if (widget.isAdmin) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Inicia sesión para usar favoritos.');
      return;
    }
    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final pid = profile?['id'] as String?;
      if (pid == null) return;
      if (_isWishlisted) {
        await _supabase
            .from('wishlist')
            .delete()
            .eq('profile_id', pid)
            .eq('product_id', widget.product.id);
      } else {
        await _supabase.from('wishlist').insert({
          'profile_id': pid,
          'product_id': widget.product.id,
        });
      }
      if (!mounted) return;
      setState(() => _isWishlisted = !_isWishlisted);
      _showSnack(
        _isWishlisted ? '❤️ Guardado en favoritos' : 'Eliminado de favoritos',
        isSuccess: _isWishlisted,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    }
  }

  Future<void> _fetchExtraData() async {
    try {
      // Configuramos las consultas base
      final queries = <Future<dynamic>>[
        _supabase
            .from('warehouse_stock_batches')
            .select(
              'id, available_quantity, variant_id, warehouse_id, batch_number, expiry_date, warehouses(name)',
            )
            .eq('product_id', widget.product.id)
            .gt('available_quantity', 0)
            .order('expiry_date', ascending: true, nullsFirst: false),
        _supabase
            .from('product_images')
            .select(
              'id, product_id, variant_id, image_url, display_order, is_main',
            )
            .eq('product_id', widget.product.id)
            .order('display_order', ascending: true),
        // ACTUALIZACIÓN DE QUERY (Relacional: attributes -> attribute_values -> variant_attribute_values)
        _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, variant_attribute_values(attribute_values(id, value, attributes(name))), product_images(*), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, unit_cost',
            )
            .eq('product_id', widget.product.id)
            .eq('is_active', true)
            .order('created_at', ascending: true),
        _supabase
            .from('product_reviews')
            .select('rating, comment, user_name, created_at')
            .eq('product_id', widget.product.id)
            .order('created_at', ascending: false),
        _supabase
            .from('product_active_ingredients')
            .select(
              'concentration, unit, active_ingredients(id, name, description)',
            )
            .eq('product_id', widget.product.id),
      ];

      if (widget.isAdmin) {
        queries.add(
          _supabase
              .from('order_items')
              .select(
                'quantity, unit_cost, applied_price, variant_id, orders!inner(status)',
              )
              .eq('product_id', widget.product.id)
              .eq('orders.status', 'COMPLETED'),
        );
      }

      final results = await Future.wait(queries);

      if (!mounted) return;

      final rawStocks = results[0] as List<dynamic>;

      final aggregatedStocks = <String, Map<String, dynamic>>{};
      final validBatches = <Map<String, dynamic>>[];

      for (final row in rawStocks) {
        final wId = row['warehouse_id']?.toString() ?? 'unknown';
        final vId = row['variant_id']?.toString() ?? 'none';
        final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;

        if (stock > 0) {
          validBatches.add(Map<String, dynamic>.from(row as Map));
        }

        final key = '${wId}_$vId';
        if (aggregatedStocks.containsKey(key)) {
          aggregatedStocks[key]!['available_quantity'] =
              (aggregatedStocks[key]!['available_quantity'] as int) + stock;
        } else {
          aggregatedStocks[key] = {
            'warehouse_id': row['warehouse_id'],
            'variant_id': row['variant_id'],
            'warehouses': row['warehouses'],
            'available_quantity': stock,
          };
        }
      }
      final fetchedStocks = aggregatedStocks.values.toList();

      final fetchedImages =
          (results[1] as List)
              .map(
                (e) => ProductImageModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
      final fetchedVariants =
          (results[2] as List)
              .map(
                (e) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
      final fetchedReviews = List<Map<String, dynamic>>.from(
        results[3] as List,
      );
      final fetchedIngredients = List<Map<String, dynamic>>.from(
        results[4] as List,
      );

      double totalRating = 0;
      for (final r in fetchedReviews) {
        totalRating += (r['rating'] as num).toDouble();
      }

      int soldUnits = 0;
      double reinvestment = 0.0;
      double revenue = 0.0;

      if (widget.isAdmin && results.length > 5) {
        final orderItemsData = results[5] as List<dynamic>;
        for (final row in orderItemsData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final uc = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
          final ap = (row['applied_price'] as num?)?.toDouble() ?? 0.0;

          soldUnits += q;
          reinvestment += (q * uc);
          revenue += (q * ap);
        }
      }

      setState(() {
        _warehouseStocks = fetchedStocks;
        _batchesList = validBatches;
        _images = fetchedImages;
        _variants = fetchedVariants;
        _reviewsList = fetchedReviews;
        _activeIngredients = fetchedIngredients;
        _averageRating =
            fetchedReviews.isEmpty ? 0.0 : totalRating / fetchedReviews.length;

        _totalSold = soldUnits;
        _reinvestmentNeeded = reinvestment;
        _totalRevenue = revenue;

        final Map<String, Map<String, double>> variantSales = {};
        if (widget.isAdmin && results.length > 5) {
          for (final row in results[5] as List<dynamic>) {
            final vid = row['variant_id']?.toString() ?? '';
            if (vid.isEmpty) continue;
            final q = (row['quantity'] as num?)?.toDouble() ?? 0;
            final uc = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
            final ap = (row['applied_price'] as num?)?.toDouble() ?? 0.0;
            variantSales.putIfAbsent(
              vid,
              () => {'qty': 0, 'cost': 0, 'revenue': 0},
            );
            variantSales[vid]!['qty'] = variantSales[vid]!['qty']! + q;
            variantSales[vid]!['cost'] = variantSales[vid]!['cost']! + (q * uc);
            variantSales[vid]!['revenue'] =
                variantSales[vid]!['revenue']! + (q * ap);
          }
        }

        double invValue = 0.0;
        final summaries = <VariantFinancialSummary>[];
        for (final v in fetchedVariants) {
          final cost =
              ((v.unitCost ?? 0) > 0) ? v.unitCost! : widget.product.unitCost;
          int variantStock = 0;
          for (final row in fetchedStocks) {
            if (row['variant_id'] == v.id) {
              variantStock += (row['available_quantity'] as num?)?.toInt() ?? 0;
            }
          }
          final vInv = variantStock * cost;
          invValue += vInv;
          final sales = variantSales[v.id];
          summaries.add(
            VariantFinancialSummary(
              variant: v,
              unitCost: cost,
              stockQuantity: variantStock,
              inventoryValue: vInv,
              soldQuantity: sales?['qty']?.toInt() ?? 0,
              soldCost: sales?['cost'] ?? 0.0,
              soldRevenue: sales?['revenue'] ?? 0.0,
            ),
          );
        }
        _inventoryValue = invValue;
        _variantSummaries = summaries;

        _isLoadingExtra = false;

        if (_variants.isNotEmpty && _selectedVariantId == null) {
          ProductVariantModel? firstWithStock;
          for (final v in _variants) {
            int stock = 0;
            for (final row in _warehouseStocks) {
              if (row['variant_id'] == v.id) {
                stock += ((row['available_quantity'] as num?)?.toInt() ?? 0);
              }
            }
            if (stock > 0) {
              firstWithStock = v;
              break;
            }
          }
          firstWithStock ??= _variants.first;

          _selectedVariantId = firstWithStock.id;
          _selectedAttributes.clear();
          firstWithStock.attributeMap.forEach((k, val) {
            _selectedAttributes[k] = val;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading extra: $e');
      if (mounted) setState(() => _isLoadingExtra = false);
    }
  }

  // ─── DERIVED GETTERS ─────────────────────────────────────────────────────

  String? get _selectedVariantIdSafe =>
      (_selectedVariantId != null &&
              _variants.any((v) => v.id == _selectedVariantId))
          ? _selectedVariantId
          : null;

  ProductVariantModel? get _selectedVariant {
    final id = _selectedVariantIdSafe;
    if (id == null) return null;
    try {
      return _variants.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  double get _baseSalePrice =>
      _selectedVariant?.salePrice ?? widget.product.salePrice;
  double? get _baseWholesalePrice =>
      _selectedVariant?.wholesalePrice ?? widget.product.wholesalePrice;
  int get _baseWholesaleMinQty =>
      _selectedVariant?.wholesaleMinQuantity ??
      widget.product.wholesaleMinQuantity;

  double get _effectivePrice {
    final wp = _baseWholesalePrice;
    if (wp != null && _selectedQty >= _baseWholesaleMinQty) return wp;
    return _baseSalePrice;
  }

  int get _effectiveStock {
    final vid = _selectedVariantIdSafe;
    if (vid == null) return widget.product.totalStock;
    return _warehouseStocks.fold<int>(0, (t, row) {
      if ((row['variant_id'] as String?) != vid) return t;
      return t + ((row['available_quantity'] as num?)?.toInt() ?? 0);
    });
  }

  bool get _isActive => widget.product.isActive;
  bool get _canBuy => _isActive && _effectiveStock > 0;
  double get _effectiveUnitCost =>
      ((_selectedVariant?.unitCost ?? 0) > 0)
          ? _selectedVariant!.unitCost!
          : widget.product.unitCost;

  double get _profit => _effectivePrice - _effectiveUnitCost;
  double get _margin =>
      _effectiveUnitCost > 0 ? (_profit / _effectiveUnitCost) * 100 : 0.0;

  List<Map<String, dynamic>> get _selectedVariantStockRows {
    final vid = _selectedVariantIdSafe;
    if (vid == null) return List<Map<String, dynamic>>.from(_warehouseStocks);
    return _warehouseStocks
        .where((row) => (row['variant_id'] as String?) == vid)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // Filtra los lotes específicos de la variante seleccionada
  List<Map<String, dynamic>> get _selectedVariantBatchesRows {
    final vid = _selectedVariantIdSafe;
    if (vid == null) return _batchesList;
    return _batchesList.where((row) => row['variant_id'] == vid).toList();
  }

  List<String> get _attributeKeys {
    final keys = <String>[];
    for (final v in _variants) {
      for (final k in v.attributeMap.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  Map<String, List<String>> get _attributeOptions {
    final opts = <String, List<String>>{};
    for (final v in _variants) {
      v.attributeMap.forEach((k, val) {
        opts.putIfAbsent(k, () => []);
        if (!opts[k]!.contains(val)) opts[k]!.add(val);
      });
    }
    return opts;
  }

  List<ProductImageModel> get _galleryImages {
    final productImgs = _images.where((img) => img.variantId == null).toList();
    productImgs.sort((a, b) {
      if (a.isMain && !b.isMain) return -1;
      if (!a.isMain && b.isMain) return 1;
      return (a.displayOrder).compareTo(b.displayOrder);
    });
    return productImgs;
  }

  String? get _selectedVariantImageUrl {
    final variant = _selectedVariant;
    if (variant == null) return null;

    final variantImg = _images
        .where((img) => img.variantId == variant.id)
        .cast<ProductImageModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (variantImg != null) return variantImg.imageUrl;

    if (variant.images.isNotEmpty) return variant.images.first.imageUrl;
    return null;
  }

  String? _variantImageUrl(ProductVariantModel variant) {
    final variantImg = _images
        .where((img) => img.variantId == variant.id)
        .cast<ProductImageModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (variantImg != null) return variantImg.imageUrl;
    if (variant.images.isNotEmpty) return variant.images.first.imageUrl;
    return null;
  }

  String? get _effectiveImageUrl {
    final varImg = _selectedVariantImageUrl;
    if (varImg != null && _selectedVariant != null) return varImg;

    final imgs = _galleryImages;
    if (imgs.isNotEmpty && _selectedImageIndex < imgs.length) {
      return imgs[_selectedImageIndex].imageUrl;
    }
    return widget.product.primaryImageUrl;
  }

  String _fmt(String value) {
    final n = value.replaceAll('_', ' ').trim();
    if (n.isEmpty) return value;
    return n
        .split(RegExp(r'\s+'))
        .map(
          (p) =>
              p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  bool _isOptionEnabled(String key, String value) =>
      _variants.any((v) => v.attributeMap[key] == value);

  ProductVariantModel? _findMatchingVariant(Map<String, String> sel) {
    for (final v in _variants) {
      bool ok = true;
      for (final e in sel.entries) {
        if (v.attributeMap[e.key] != e.value) {
          ok = false;
          break;
        }
      }
      if (ok) return v;
    }
    return null;
  }

  void _selectVariant(
    ProductVariantModel variant, {
    bool resetQuantity = true,
    bool animateGallery = true,
  }) {
    if (!mounted) return;
    setState(() {
      _showVariantImage = true;
      _selectedVariantId = variant.id;
      _selectedAttributes
        ..clear()
        ..addAll(variant.attributeMap);
      if (animateGallery) {
        _selectedImageIndex = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
      if (resetQuantity) _selectedQty = 1;
    });
  }

  void _onGalleryChanged(int index) {
    setState(() => _selectedImageIndex = index);
  }

  void _selectAttribute(String key, String value) {
    final next = Map<String, String>.from(_selectedAttributes)..[key] = value;
    var match = _findMatchingVariant(next);
    if (match == null) {
      try {
        match = _variants.firstWhere((v) => v.attributeMap[key] == value);
      } catch (_) {
        return;
      }
    }
    _selectVariant(match);
  }

  // ─── CART & REVIEWS ───────────────────────────────────────────────────────

  void _addToCart() {
    if (_variants.isNotEmpty && _selectedVariantIdSafe == null) {
      _showSnack('Selecciona una opción.');
      return;
    }
    if (_effectiveStock <= 0) {
      _showSnack('Sin stock.');
      return;
    }
    if (_selectedQty > _effectiveStock) {
      _showSnack('Cantidad mayor al stock.');
      return;
    }
    Provider.of<CartProvider>(context, listen: false).addItem(
      widget.product,
      quantity: _selectedQty,
      variantId: _selectedVariant?.id,
      variantLabel: _selectedVariant?.label,
      unitPrice: _effectivePrice,
      imageUrl: _effectiveImageUrl,
      sku: _selectedVariant?.sku,
      availableStock: _effectiveStock,
    );
    HapticFeedback.lightImpact();
    _showSnack('¡Añadido al carrito!', isSuccess: true);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.slate,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showQtyDialog() async {
    final ctrl = TextEditingController(text: '$_selectedQty');
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusXl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cantidad',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Máx. $_effectiveStock',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
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
                          onPressed: () {
                            final n = int.tryParse(ctrl.text.trim());
                            if (n != null && n > 0) {
                              setState(
                                () =>
                                    _selectedQty = n.clamp(1, _effectiveStock),
                              );
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
  }

  // ─── REVIEWS ─────────────────────────────────────────────────────────────

  Future<void> _onAddReviewTapped() async {
    if (widget.isAdmin) {
      _showReviewDialog(isAdmin: true);
      return;
    }
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Inicia sesión para opinar.');
      return;
    }
    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id, full_name')
              .eq('auth_user_id', user.id)
              .single();
      final profileId = profile['id'];
      final fullName = profile['full_name'] ?? 'Usuario';
      final purchases = await _supabase
          .from('order_items')
          .select('id, orders!inner(customer_id)')
          .eq('product_id', widget.product.id)
          .eq('orders.customer_id', profileId)
          .limit(1);
      if (purchases.isEmpty) {
        _showSnack('Debes haber comprado este producto para opinar.');
        return;
      }
      _showReviewDialog(
        isAdmin: false,
        profileId: profileId,
        defaultName: fullName,
      );
    } catch (e) {
      _showSnack('Error al verificar: $e');
    }
  }

  void _showReviewDialog({
    required bool isAdmin,
    String? profileId,
    String? defaultName,
  }) {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: defaultName ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (ctx, setS) => Dialog(
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.amberLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: AppColors.amber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '¿Qué te pareció?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => GestureDetector(
                              onTap: () => setS(() => selectedRating = i + 1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  i < selectedRating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: AppColors.amber,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (isAdmin)
                          _InputField(
                            controller: nameCtrl,
                            hint: 'Nombre del cliente',
                            label: 'Nombre',
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                            ),
                            child: Text(
                              'Publicando como: $defaultName',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        _InputField(
                          controller: commentCtrl,
                          hint: 'Cuéntanos qué te pareció...',
                          label: 'Comentario',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : () => Navigator.pop(dialogCtx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radius,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
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
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : () async {
                                          final name =
                                              isAdmin
                                                  ? nameCtrl.text.trim()
                                                  : (defaultName ?? '');
                                          if (name.isEmpty && isAdmin) {
                                            _showSnack('Ingresa el nombre.');
                                            return;
                                          }
                                          setS(() => isSubmitting = true);
                                          try {
                                            await _supabase
                                                .from('product_reviews')
                                                .insert({
                                                  'product_id':
                                                      widget.product.id,
                                                  'profile_id': profileId,
                                                  'user_name': name,
                                                  'rating': selectedRating,
                                                  'comment':
                                                      commentCtrl.text
                                                              .trim()
                                                              .isEmpty
                                                          ? null
                                                          : commentCtrl.text
                                                              .trim(),
                                                });
                                            if (!mounted) return;
                                            Navigator.pop(dialogCtx);
                                            _showSnack(
                                              '¡Reseña publicada!',
                                              isSuccess: true,
                                            );
                                            _fetchExtraData();
                                          } catch (e) {
                                            setS(() => isSubmitting = false);
                                            _showSnack('Error: $e');
                                          }
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radius,
                                    ),
                                  ),
                                ),
                                child:
                                    isSubmitting
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                        : const Text(
                                          'Publicar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Map<String, int> get _stockByVariant {
    final Map<String, int> result = {};
    for (final row in _warehouseStocks) {
      final variantId = row['variant_id'] as String?;
      final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
      if (variantId == null) continue;
      result.update(
        variantId,
        (current) => current + stock,
        ifAbsent: () => stock,
      );
    }
    return result;
  }

  List<ProductVariantModel> get _thumbnailVariants {
    if (_attributeKeys.length <= 1) return _variants;
    final list = <ProductVariantModel>[];
    final seen = <String>{};
    for (final v in _variants) {
      final url = _variantImageUrl(v);
      if (url != null && !seen.contains(url)) {
        seen.add(url);
        list.add(v);
      }
    }
    return list;
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gallery = _galleryImages;

    final Map<String, dynamic> mergedDetails = Map.from(widget.product.details);
    mergedDetails['Control de Stock'] =
        widget.product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = widget.product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(widget.product.productType);

    final content = CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
          pinned: false,
          stretch: true,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: _GallerySection(
              images: gallery,
              pageController: _pageController,
              selectedIndex: _selectedImageIndex,
              onPageChanged: _onGalleryChanged,
              wishlistWidget: widget.isAdmin ? null : _buildWishlistButton(),
              variantImageOverrideUrl:
                  (_showVariantImage && _selectedVariant != null)
                      ? _selectedVariantImageUrl
                      : null,
              variantLabelOverride:
                  (_showVariantImage && _selectedVariant != null)
                      ? _selectedVariant!.attributeMap.values.join(' - ')
                      : null,
              fallbackImageUrl: widget.product.primaryImageUrl,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              if (_thumbnailVariants.isNotEmpty) ...[
                _buildThumbnailRow(_thumbnailVariants),
                const SizedBox(height: 20),
              ],

              _ProductTopSection(
                name: widget.product.name,
                sku: _selectedVariant?.sku,
                isActive: _isActive,
                effectiveStock: _effectiveStock,
                averageRating: _averageRating,
                totalReviews: _reviewsList.length,
              ),
              const SizedBox(height: 16),

              _PriceSection(
                effectivePrice: _effectivePrice,
                baseSalePrice: _baseSalePrice,
                baseWholesalePrice: _baseWholesalePrice,
                baseWholesaleMinQty: _baseWholesaleMinQty,
                selectedQty: _selectedQty,
              ),
              const SizedBox(height: 20),

              if (_variants.isNotEmpty &&
                  _attributeKeys.isNotEmpty &&
                  !(_attributeKeys.length == 1 &&
                      _thumbnailVariants.isNotEmpty)) ...[
                _VariantSelector(
                  attributeKeys: _attributeKeys,
                  attributeOptions: _attributeOptions,
                  selectedAttributes: _selectedAttributes,
                  formatLabel: _fmt,
                  isOptionEnabled: _isOptionEnabled,
                  onSelect: _selectAttribute,
                ),
                const SizedBox(height: 20),
              ],

              if (widget.isAdmin) ...[
                ProductAdminInfoCard(
                  unitCost: _effectiveUnitCost,
                  profit: _profit,
                  margin: _margin,
                  wholesalePrice:
                      _selectedVariant?.wholesalePrice ??
                      widget.product.wholesalePrice,
                  wholesaleMinQuantity:
                      _selectedVariant?.wholesaleMinQuantity ??
                      widget.product.wholesaleMinQuantity,
                  reorderPoint: _selectedVariant?.reorderPoint ?? 3,
                ),
                const SizedBox(height: 16),

                ProductQuickDecisionsCard(
                  totalSold: _totalSold,
                  reinvestmentNeeded: _reinvestmentNeeded,
                  inventoryValue: _inventoryValue,
                  totalRevenue: _totalRevenue,
                  variantSummaries: _variantSummaries,
                ),
                const SizedBox(height: 16),
              ],

              ProductDetailsCard(details: mergedDetails),
              if (mergedDetails.isNotEmpty) const SizedBox(height: 16),

              if (_activeIngredients.isNotEmpty) ...[
                _ActiveIngredientsCard(ingredients: _activeIngredients),
                const SizedBox(height: 16),
              ],

              ProductDescriptionCard(
                description: widget.product.description ?? '',
              ),
              if ((widget.product.description ?? '').trim().isNotEmpty)
                const SizedBox(height: 16),

              if (widget.isAdmin)
                ProductAvailabilityCard(
                  isActive: _isActive,
                  isAdmin: true,
                  isLoadingExtra: _isLoadingExtra,
                  warehouseStocks: _selectedVariantStockRows,
                  effectiveStock: _effectiveStock,
                  stockLabel: _variants.isNotEmpty ? 'Variante' : 'Total',
                  showQuantitySelector: false,
                  selectedQty: _selectedQty,
                  onDecrement: null,
                  onIncrement: null,
                ),
              if (widget.isAdmin) const SizedBox(height: 16),

              if (widget.isAdmin && widget.product.usesBatches) ...[
                ProductBatchesCard(
                  isLoading: _isLoadingExtra,
                  batches: _selectedVariantBatchesRows,
                ),
                const SizedBox(height: 16),
              ],

              ProductReviewsCard(
                averageRating: _averageRating,
                totalReviews: _reviewsList.length,
                reviews: _reviewsList,
                onAddReview: _onAddReviewTapped,
              ),
            ]),
          ),
        ),
      ],
    );

    if (widget.isAdmin) {
      return AdminLayout(
        title: widget.product.name,
        showBackButton: true,
        showSettingsButton: true,
        settingsActions: [
          const PopupMenuItem(value: 'export', child: Text('Exportar')),
        ],
        onSettingsSelected: (value) {
          switch (value) {
            case 'export':
              ProductPdfGenerator.shareProduct(
                widget.product,
                variants: _variants,
                stockByVariant: _stockByVariant,
              );
              break;
          }
        },
        body: Container(color: AppColors.bg, child: content),
      );
    }

    return CustomerLayout(
      title: widget.product.name,
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body: Container(color: AppColors.bg, child: content),
      bottomNavigationBar: _BottomBar(
        canBuy: _canBuy,
        isActive: _isActive,
        effectiveStock: _effectiveStock,
        effectivePrice: _effectivePrice,
        selectedQty: _selectedQty,
        onDecrement:
            () => setState(() {
              if (_selectedQty > 1) _selectedQty--;
            }),
        onIncrement:
            () => setState(() {
              if (_selectedQty < _effectiveStock) _selectedQty++;
            }),
        onQtyTap: _showQtyDialog,
        onAddToCart: _addToCart,
      ),
    );
  }

  Widget _buildThumbnailRow(List<ProductVariantModel> thumbs) {
    final firstImg =
        _galleryImages.isNotEmpty
            ? _galleryImages.first.imageUrl
            : widget.product.primaryImageUrl;

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showVariantImage = false),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(
                  color:
                      !_showVariantImage ? AppColors.primary : AppColors.border,
                  width: !_showVariantImage ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                image:
                    firstImg != null
                        ? DecorationImage(
                          image: CachedNetworkImageProvider(firstImg),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(7),
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          ...thumbs.map((v) {
            final imgUrl =
                _variantImageUrl(v) ?? widget.product.primaryImageUrl;
            final isSelected =
                _showVariantImage &&
                (_attributeKeys.length == 1
                    ? _selectedVariantId == v.id
                    : _selectedVariantImageUrl == _variantImageUrl(v));

            return GestureDetector(
              onTap: () => _selectVariant(v),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  image:
                      imgUrl != null
                          ? DecorationImage(
                            image: CachedNetworkImageProvider(imgUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    _attributeKeys.length == 1 && v.attributeMap.isNotEmpty
                        ? Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(6),
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                final fullText = v.attributeMap.values.first;
                                final displayText =
                                    fullText.length > 8
                                        ? '${fullText.substring(0, 7)}...'
                                        : fullText;

                                return Text(
                                  displayText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        )
                        : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWishlistButton() {
    if (_isWishlistLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.danger),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleWishlist,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _isWishlisted ? AppColors.danger : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _isWishlisted
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: _isWishlisted ? Colors.white : AppColors.danger,
          size: 20,
        ),
      ),
    );
  }
}

// ─── GALLERY ─────────────────────────────────────────────────────────────────

class _GallerySection extends StatelessWidget {
  final List<ProductImageModel> images;
  final PageController pageController;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final Widget? wishlistWidget;
  final String? variantImageOverrideUrl;
  final String? variantLabelOverride;
  final String? fallbackImageUrl;

  const _GallerySection({
    required this.images,
    required this.pageController,
    required this.selectedIndex,
    required this.onPageChanged,
    this.wishlistWidget,
    this.variantImageOverrideUrl,
    this.variantLabelOverride,
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrls = <String>[];
    if (variantImageOverrideUrl != null) {
      effectiveUrls.add(variantImageOverrideUrl!);
    } else {
      effectiveUrls.addAll(images.map((img) => img.imageUrl));
      if (effectiveUrls.isEmpty && fallbackImageUrl != null) {
        effectiveUrls.add(fallbackImageUrl!);
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        PageView.builder(
          controller: pageController,
          itemCount: effectiveUrls.isNotEmpty ? effectiveUrls.length : 1,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            if (effectiveUrls.isEmpty) {
              return Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              );
            }
            return GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FullScreenGallery(
                            imageUrls: effectiveUrls,
                            initialIndex: index,
                          ),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CachedNetworkImage(
                  imageUrl: effectiveUrls[index],
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                  errorWidget:
                      (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                      ),
                ),
              ),
            );
          },
        ),

        if (wishlistWidget != null)
          Positioned(top: 14, right: 14, child: wishlistWidget!),

        if (variantLabelOverride != null)
          Positioned(
            bottom: 28,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  variantLabelOverride!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

        if (effectiveUrls.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),

        if (effectiveUrls.length > 1 &&
            effectiveUrls.length <= 8 &&
            variantLabelOverride == null)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                effectiveUrls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == selectedIndex ? 16 : 6,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:
                        i == selectedIndex
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── PRODUCT TOP SECTION ─────────────────────────────────────────────────────

class _ProductTopSection extends StatelessWidget {
  final String name;
  final String? sku;
  final bool isActive;
  final int effectiveStock;
  final double averageRating;
  final int totalReviews;

  const _ProductTopSection({
    required this.name,
    required this.sku,
    required this.isActive,
    required this.effectiveStock,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg) =
        !isActive
            ? ('No disponible', AppColors.textSecondary, AppColors.slateLight)
            : effectiveStock > 0
            ? ('En stock', AppColors.success, AppColors.successLight)
            : ('Agotado', AppColors.danger, AppColors.dangerLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            if (sku != null && sku!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                'SKU $sku',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        if (totalReviews > 0)
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < averageRating.floor()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.amber,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($totalReviews reseñas)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── PRICE SECTION ───────────────────────────────────────────────────────────

class _PriceSection extends StatelessWidget {
  final double effectivePrice;
  final double baseSalePrice;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQty;
  final int selectedQty;

  const _PriceSection({
    required this.effectivePrice,
    required this.baseSalePrice,
    required this.baseWholesalePrice,
    required this.baseWholesaleMinQty,
    required this.selectedQty,
  });

  @override
  Widget build(BuildContext context) {
    final isWholesale =
        baseWholesalePrice != null && selectedQty >= baseWholesaleMinQty;
    final hasWholesale = baseWholesalePrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 2.0,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              effectivePrice.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -1.5,
                height: 1.0,
              ),
            ),
            if (isWholesale) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'S/ ${baseSalePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (hasWholesale)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isWholesale ? AppColors.amberLight : AppColors.bg,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color:
                        isWholesale
                            ? AppColors.amber.withValues(alpha: 0.5)
                            : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 14,
                      color:
                          isWholesale ? AppColors.amber : AppColors.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'x$baseWholesaleMinQty+',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            isWholesale
                                ? AppColors.amberDark
                                : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${baseWholesalePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isWholesale ? AppColors.amber : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isWholesale) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '¡Ahorro mayorista de S/ ${(baseSalePrice - effectivePrice).toStringAsFixed(2)}!',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (hasWholesale && !isWholesale) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Compra $baseWholesaleMinQty+ y paga S/ ${baseWholesalePrice!.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.amberDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── VARIANT SELECTOR ────────────────────────────────────────────────────────

class _VariantSelector extends StatelessWidget {
  final List<String> attributeKeys;
  final Map<String, List<String>> attributeOptions;
  final Map<String, String> selectedAttributes;
  final String Function(String) formatLabel;
  final bool Function(String, String) isOptionEnabled;
  final void Function(String, String) onSelect;
  final Map<String, String?> variantImageUrls;
  final String? fallbackImageUrl;

  const _VariantSelector({
    required this.attributeKeys,
    required this.attributeOptions,
    required this.selectedAttributes,
    required this.formatLabel,
    required this.isOptionEnabled,
    required this.onSelect,
    this.variantImageUrls = const {},
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          attributeKeys.map((key) {
            final options = attributeOptions[key] ?? [];
            final selected = selectedAttributes[key];
            final hasImages = options.any(
              (opt) => variantImageUrls[opt] != null,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatLabel(key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (selected != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selected,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasImages)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final option = options[idx];
                          final isSelected = selected == option;
                          final enabled = isOptionEnabled(key, option);
                          final imgUrl =
                              variantImageUrls[option] ?? fallbackImageUrl;
                          return GestureDetector(
                            onTap: enabled ? () => onSelect(key, option) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? AppColors.border
                                          : AppColors.divider,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.18,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                        : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius - 1,
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child:
                                          imgUrl != null
                                              ? CachedNetworkImage(
                                                imageUrl: imgUrl,
                                                fit: BoxFit.cover,
                                                color:
                                                    enabled
                                                        ? null
                                                        : Colors.white
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                colorBlendMode:
                                                    BlendMode.srcATop,
                                                placeholder:
                                                    (context, url) => Container(
                                                      color: AppColors.bg,
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 12,
                                                          height: 12,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (_, __, ___) => Container(
                                                      color: AppColors.bg,
                                                      child: const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 22,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                color: AppColors.bg,
                                                child: const Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 22,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              (isSelected
                                                      ? AppColors.primary
                                                      : Colors.black)
                                                  .withValues(alpha: 0.72),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          option,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                enabled
                                                    ? Colors.white
                                                    : Colors.white.withValues(
                                                      alpha: 0.45,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          options.map((option) {
                            final isSelected = selected == option;
                            final enabled = isOptionEnabled(key, option);
                            return GestureDetector(
                              onTap:
                                  enabled ? () => onSelect(key, option) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? Colors.white
                                          : AppColors.bg,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : enabled
                                            ? AppColors.border
                                            : AppColors.divider,
                                    width: isSelected ? 2 : 1.5,
                                  ),
                                  boxShadow:
                                      isSelected
                                          ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : enabled
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  String _formatLabel(String value) {
    final n = value.replaceAll('_', ' ').trim();
    if (n.isEmpty) return value;
    return n
        .split(RegExp(r'\s+'))
        .map(
          (p) =>
              p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

// ─── COMPACT BOTTOM BAR ──────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool canBuy;
  final bool isActive;
  final int effectiveStock;
  final double effectivePrice;
  final int selectedQty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onQtyTap;
  final VoidCallback onAddToCart;

  const _BottomBar({
    required this.canBuy,
    required this.isActive,
    required this.effectiveStock,
    required this.effectivePrice,
    required this.selectedQty,
    required this.onDecrement,
    required this.onIncrement,
    required this.onQtyTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (canBuy) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _QtyBtn(
                        icon: Icons.remove_rounded,
                        enabled: canBuy && selectedQty > 1,
                        onTap: onDecrement,
                      ),
                      GestureDetector(
                        onTap: canBuy ? onQtyTap : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$selectedQty',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      _QtyBtn(
                        icon: Icons.add_rounded,
                        enabled: canBuy && selectedQty < effectiveStock,
                        onTap: onIncrement,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: canBuy ? onAddToCart : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient:
                          canBuy
                              ? const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color: canBuy ? null : AppColors.slateLight,
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      boxShadow:
                          canBuy
                              ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !isActive
                              ? Icons.do_not_disturb_alt_rounded
                              : canBuy
                              ? Icons.shopping_bag_rounded
                              : Icons.remove_shopping_cart_rounded,
                          color: canBuy ? Colors.white : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              !isActive
                                  ? 'No disponible'
                                  : canBuy
                                  ? 'Añadir al carrito'
                                  : 'Agotado',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color:
                                    canBuy ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                            if (canBuy)
                              Text(
                                'S/ ${(effectivePrice * selectedQty).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:
            enabled
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: enabled ? AppColors.primary : AppColors.textMuted,
      ),
    ),
  );
}

// ─── INPUT FIELD HELPER ──────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final int maxLines;
  const _InputField({
    required this.controller,
    required this.hint,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        isDense: true,
      ),
    );
  }
}

// ─── DESCRIPTION CARD ────────────────────────────────────────────────────────

class ProductDescriptionCard extends StatelessWidget {
  final String description;
  const ProductDescriptionCard({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.description_outlined,
            iconColor: Color(0xFF3B82F6),
            iconBg: Color(0xFFEFF6FF),
            title: 'Descripción',
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DETAILS CARD ─────────────────────────────────────────────────────────────

class ProductDetailsCard extends StatelessWidget {
  final Map<String, dynamic> details;
  const ProductDetailsCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    final entries = details.entries.toList();
    return Container(
      decoration: AppColors.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: _CardHeader(
              icon: Icons.list_alt_rounded,
              iconColor: Color(0xFF8B5CF6),
              iconBg: Color(0xFFEDE9FE),
              title: 'Especificaciones',
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          ...entries.asMap().entries.map((e) {
            final isEven = e.key % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              color: isEven ? AppColors.bg : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.value.key.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.value.value.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── CARD HEADER ──────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── INGREDIENTES ACTIVOS / COMPONENTES QUÍMICOS ────────────────────────────

class _ActiveIngredientsCard extends StatelessWidget {
  final List<Map<String, dynamic>> ingredients;

  const _ActiveIngredientsCard({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Ingredientes Activos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ingredients.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: ingredients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = ingredients[index];
              final ingredient =
                  item['active_ingredients'] as Map<String, dynamic>? ?? {};
              final name = ingredient['name'] as String? ?? '—';
              final description = ingredient['description'] as String?;
              final concentration = item['concentration'];
              final unit = item['unit'] as String?;

              final hasConc = concentration != null;
              final concText =
                  hasConc
                      ? '${(concentration as num).toStringAsFixed(concentration is int || (concentration) % 1 == 0 ? 0 : 2)}${unit != null ? ' $unit' : ''}'
                      : null;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E7FF), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.biotech_rounded,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (description != null &&
                              description.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (concText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          concText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Modelo de resumen financiero por variante ────────────────────────────────
class VariantFinancialSummary {
  final ProductVariantModel variant;
  final double unitCost;
  final int stockQuantity;
  final double inventoryValue;
  final int soldQuantity;
  final double soldCost;
  final double soldRevenue;

  const VariantFinancialSummary({
    required this.variant,
    required this.unitCost,
    required this.stockQuantity,
    required this.inventoryValue,
    required this.soldQuantity,
    required this.soldCost,
    required this.soldRevenue,
  });

  double get soldProfit => soldRevenue - soldCost;
}
