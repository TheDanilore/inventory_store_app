import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/screens/shared/widgets/full_screen_gallery.dart';
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

// ─── TOKENS ──────────────────────────────────────────────────────────────────

class _DS {
  static const bg = Color(0xFFF8F9FC);
  static const surface = Colors.white;
  static const border = Color(0xFFEAEEF4);
  static const divider = Color(0xFFF3F6FA);
  static const textPrimary = Color(0xFF0D1B2E);
  static const textSecondary = Color(0xFF5C6E85);
  static const textMuted = Color(0xFF9CAEBF);
  static const success = Color(0xFF0CB77C);
  static const successLight = Color(0xFFD6F5EC);
  static const danger = Color(0xFFE8394A);
  static const dangerLight = Color(0xFFFFE8EB);
  static const amber = Color(0xFFF5A623);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberDark = Color(0xFF7D4A00);
  static const slate = Color(0xFF3D5168);
  static const slateLight = Color(0xFFDFE8F0);
  static const radius = 14.0;
  static const radiusSm = 8.0;
  static const radiusXl = 20.0;

  static BoxDecoration card({Color? borderColor, bool elevated = true}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(color: borderColor ?? border),
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: const Color(0xFF0D1B2E).withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      );
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────

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
  List<Map<String, dynamic>> _batchesList =
      []; // <-- NUEVO: Lista de lotes detallados
  List<ProductImageModel> _images = [];
  List<ProductVariantModel> _variants = [];
  List<Map<String, dynamic>> _reviewsList = [];

  // Para Decisiones Rápidas
  int _totalSold = 0;
  double _reinvestmentNeeded = 0.0;

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
              // <-- NUEVO: Agregamos batch_number y expiry_date a la consulta
              'id, available_quantity, variant_id, warehouse_id, batch_number, expiry_date, warehouses(name)',
            )
            .eq('product_id', widget.product.id)
            .gt(
              'available_quantity',
              0,
            ) // <-- Solo traemos lotes con stock para la UI
            .order('expiry_date', ascending: true, nullsFirst: false),
        _supabase
            .from('product_images')
            .select(
              'id, product_id, variant_id, image_url, display_order, is_main',
            )
            .eq('product_id', widget.product.id)
            .order('display_order', ascending: true),
        _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, attributes, product_images(*), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active',
            )
            .eq('product_id', widget.product.id)
            .eq('is_active', true)
            .order('created_at', ascending: true),
        _supabase
            .from('product_reviews')
            .select('rating, comment, user_name, created_at')
            .eq('product_id', widget.product.id)
            .order('created_at', ascending: false),
      ];

      // Se agrega el inner join para filtrar solo órdenes completadas
      if (widget.isAdmin) {
        queries.add(
          _supabase
              .from('order_items')
              .select('quantity, unit_cost, orders!inner(status)')
              .eq('product_id', widget.product.id)
              .eq('orders.status', 'COMPLETED'),
        );
      }

      final results = await Future.wait(queries);

      if (!mounted) return;

      final rawStocks = results[0] as List<dynamic>;

      // AGREGAR LOS LOTES POR ALMACÉN Y VARIANTE PARA LA VISTA RESUMIDA
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

      double totalRating = 0;
      for (final r in fetchedReviews) {
        totalRating += (r['rating'] as num).toDouble();
      }

      // Parseo de Decisiones Rápidas (Histórico)
      int soldUnits = 0;
      double reinvestment = 0.0;

      if (widget.isAdmin && results.length > 4) {
        final orderItemsData = results[4] as List<dynamic>;
        for (final row in orderItemsData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final uc = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;

          soldUnits += q;
          reinvestment +=
              (q * uc); // Costo histórico exacto para reponer lo vendido
        }
      }

      setState(() {
        _warehouseStocks = fetchedStocks;
        _batchesList = validBatches; // <-- Guardamos los lotes detallados
        _images = fetchedImages;
        _variants = fetchedVariants;
        _reviewsList = fetchedReviews;
        _averageRating =
            fetchedReviews.isEmpty ? 0.0 : totalRating / fetchedReviews.length;

        _totalSold = soldUnits;
        _reinvestmentNeeded = reinvestment;

        _isLoadingExtra = false;

        // AUTO-SELECCIONAR LA PRIMERA VARIANTE CON STOCK
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
          firstWithStock.attributes.forEach((k, val) {
            _selectedAttributes[k] = val.toString();
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
  double get _profit => _effectivePrice - widget.product.unitCost;
  double get _margin =>
      widget.product.unitCost > 0
          ? (_profit / widget.product.unitCost) * 100
          : 0.0;

  List<Map<String, dynamic>> get _selectedVariantStockRows {
    final vid = _selectedVariantIdSafe;
    if (vid == null) return List<Map<String, dynamic>>.from(_warehouseStocks);
    return _warehouseStocks
        .where((row) => (row['variant_id'] as String?) == vid)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // <-- NUEVO: Filtra los lotes específicos de la variante seleccionada
  List<Map<String, dynamic>> get _selectedVariantBatchesRows {
    final vid = _selectedVariantIdSafe;
    if (vid == null) return _batchesList;
    return _batchesList.where((row) => row['variant_id'] == vid).toList();
  }

  List<String> get _attributeKeys {
    final keys = <String>[];
    for (final v in _variants) {
      for (final k in v.attributes.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  Map<String, List<String>> get _attributeOptions {
    final opts = <String, List<String>>{};
    for (final v in _variants) {
      v.attributes.forEach((k, val) {
        final s = val.toString();
        opts.putIfAbsent(k, () => []);
        if (!opts[k]!.contains(s)) opts[k]!.add(s);
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
      _variants.any((v) => v.attributes[key]?.toString() == value);

  ProductVariantModel? _findMatchingVariant(Map<String, String> sel) {
    for (final v in _variants) {
      bool ok = true;
      for (final e in sel.entries) {
        if (v.attributes[e.key]?.toString() != e.value) {
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
        ..addAll(variant.attributes.map((k, v) => MapEntry(k, v.toString())));
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
        match = _variants.firstWhere(
          (v) => v.attributes[key]?.toString() == value,
        );
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
        backgroundColor: isSuccess ? _DS.success : _DS.slate,
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
              borderRadius: BorderRadius.circular(_DS.radiusXl),
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
                    style: const TextStyle(fontSize: 12, color: _DS.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: _DS.bg,
                      borderRadius: BorderRadius.circular(_DS.radius),
                      border: Border.all(color: _DS.border),
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
                              color: _DS.textSecondary,
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
                    borderRadius: BorderRadius.circular(_DS.radiusXl),
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
                            color: _DS.amberLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: _DS.amber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '¿Qué te pareció?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _DS.textPrimary,
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
                                  color: _DS.amber,
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
                              color: _DS.bg,
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                            ),
                            child: Text(
                              'Publicando como: $defaultName',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _DS.textSecondary,
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
                                      _DS.radius,
                                    ),
                                    side: const BorderSide(color: _DS.border),
                                  ),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: _DS.textSecondary,
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
                                            // ignore: use_build_context_synchronously
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
                                      _DS.radius,
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

    // Agrupamos la info de detalles junto con los flags de base de datos
    final Map<String, dynamic> mergedDetails = Map.from(widget.product.details);
    // Info técnica extraída de los booleanos de BD
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
                      ? _selectedVariant!.attributes.values.join(' - ')
                      : null,
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
                  unitCost: widget.product.unitCost,
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

                // COMPONENTE: DECISIONES RÁPIDAS
                ProductQuickDecisionsCard(
                  totalSold: _totalSold,
                  reinvestmentNeeded: _reinvestmentNeeded,
                ),
                const SizedBox(height: 16),
              ],

              ProductDetailsCard(details: mergedDetails),
              if (mergedDetails.isNotEmpty) const SizedBox(height: 16),

              ProductDescriptionCard(
                description: widget.product.description ?? '',
              ),
              if ((widget.product.description ?? '').trim().isNotEmpty)
                const SizedBox(height: 16),

              // RESUMEN DE STOCK
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

              // <-- NUEVO: TARJETA DETALLADA DE LOTES (Solo visible para Admin si el producto usa lotes) -->
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
              ProductPdfGenerator.generateProductPdf(
                product: widget.product,
                variants: _variants,
                stockByVariant: _stockByVariant,
              );
              break;
          }
        },
        body: Container(color: _DS.bg, child: content),
      );
    }

    return CustomerLayout(
      title: widget.product.name,
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body: Container(color: _DS.bg, child: content),
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
    // Imagen principal a mostrar en el primer cuadradito
    final firstImg =
        _galleryImages.isNotEmpty
            ? _galleryImages.first.imageUrl
            : widget.product.primaryImageUrl;

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero, // Usa el padding del SliverList padre
        children: [
          // 1. CUADRADITO FIJO (GALERÍA DEL PRODUCTO)
          GestureDetector(
            onTap: () => setState(() => _showVariantImage = false),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _DS.bg,
                border: Border.all(
                  color: !_showVariantImage ? AppColors.primary : _DS.border,
                  width: !_showVariantImage ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                image:
                    firstImg != null
                        ? DecorationImage(
                          image: NetworkImage(firstImg),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              // Iconito superpuesto para indicar que es la galería general
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

          // 2. CUADRADITOS DE VARIANTES
          ...thumbs.map((v) {
            // Si no tiene imagen, cae por defecto a la principal
            final imgUrl =
                _variantImageUrl(v) ?? widget.product.primaryImageUrl;

            // Verificamos si es la seleccionada
            final isSelected =
                _showVariantImage &&
                (_attributeKeys.length == 1
                    ? _selectedVariantId ==
                        v
                            .id // Coincidencia exacta si es 1 atributo
                    : _selectedVariantImageUrl ==
                        _variantImageUrl(
                          v,
                        )); // Coincidencia por foto si son múltiples

            return GestureDetector(
              onTap: () => _selectVariant(v),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _DS.bg,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : _DS.border,
                    width: isSelected ? 2.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  image:
                      imgUrl != null
                          ? DecorationImage(
                            image: NetworkImage(imgUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                // Solo si es de 1 atributo, le ponemos un pequeño texto translúcido
                // para que sepan qué variante es (ej. "Pikachu")
                child:
                    _attributeKeys.length == 1 && v.attributes.isNotEmpty
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
                                // Tomamos el texto y lo cortamos estrictamente si es muy largo
                                final fullText =
                                    v.attributes.values.first.toString();
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
              valueColor: AlwaysStoppedAnimation(_DS.danger),
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
          color: _isWishlisted ? _DS.danger : Colors.white,
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
          color: _isWishlisted ? Colors.white : _DS.danger,
          size: 20,
        ),
      ),
    );
  }
}

// ─── COMPONENTE NUEVO: DECISIONES RÁPIDAS ────────────────────────────────────

class ProductQuickDecisionsCard extends StatelessWidget {
  final int totalSold;
  final double reinvestmentNeeded;

  const ProductQuickDecisionsCard({
    super.key,
    required this.totalSold,
    required this.reinvestmentNeeded,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSold == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Verde sutil (DS Success light)
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF166534),
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Decisiones rápidas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Has vendido $totalSold unidades en total.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF15803D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                _DecisionRow(
                  icon: Icons.inventory_2_outlined,
                  color: _DS.amberDark,
                  label: 'Fondo de reposición',
                  value: 'S/ ${reinvestmentNeeded.toStringAsFixed(2)}',
                  subtitle: 'Ideal para reinvertir en stock.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  const _DecisionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _DS.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 10, color: _DS.textMuted),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
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

  /// If set, this URL is shown on index 0 (variant image override).
  final String? variantImageOverrideUrl;

  /// NUEVO: Texto de la variante a mostrar sobre la imagen principal
  final String? variantLabelOverride;

  const _GallerySection({
    required this.images,
    required this.pageController,
    required this.selectedIndex,
    required this.onPageChanged,
    this.wishlistWidget,
    this.variantImageOverrideUrl,
    this.variantLabelOverride, // Recibimos el texto aquí
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrls = <String>[];
    if (variantImageOverrideUrl != null) {
      effectiveUrls.add(variantImageOverrideUrl!);
    } else {
      effectiveUrls.addAll(images.map((img) => img.imageUrl));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // White background
        Container(color: Colors.white),
        // Image pager
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
                  color: _DS.textMuted.withValues(alpha: 0.4),
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
                            images: images,
                            initialIndex: index,
                          ),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.network(
                  effectiveUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: _DS.textMuted,
                        ),
                      ),
                ),
              ),
            );
          },
        ),

        // Wishlist
        if (wishlistWidget != null)
          Positioned(top: 14, right: 14, child: wishlistWidget!),

        // NUEVO: Etiqueta con el nombre de la variante centrado abajo
        if (variantLabelOverride != null)
          Positioned(
            bottom: 28, // Un poco arriba de los puntitos indicadores
            left: 20, // Margen izquierdo para que no toque el borde del celular
            right: 20, // Margen derecho para que no toque el borde del celular
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
                // Se envuelve el texto en Flexible o se deja que el Center+Positioned lo limite
                child: Text(
                  variantLabelOverride!,
                  maxLines: 1, // <--- Obliga a que sea una sola línea
                  overflow:
                      TextOverflow.ellipsis, // <--- Agrega los "..." al final
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
        // Expand icon
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

        // Dot indicators
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
            ? ('No disponible', _DS.textSecondary, _DS.slateLight)
            : effectiveStock > 0
            ? ('En stock', _DS.success, _DS.successLight)
            : ('Agotado', _DS.danger, _DS.dangerLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status pill + SKU
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
                style: const TextStyle(fontSize: 11, color: _DS.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Name
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _DS.textPrimary,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        // Rating inline
        if (totalReviews > 0)
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < averageRating.floor()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: _DS.amber,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _DS.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($totalReviews reseñas)',
                style: const TextStyle(fontSize: 12, color: _DS.textMuted),
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
        // Main price row
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
                    color: _DS.textMuted,
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
                  color: isWholesale ? _DS.amberLight : _DS.bg,
                  borderRadius: BorderRadius.circular(_DS.radius),
                  border: Border.all(
                    color:
                        isWholesale
                            ? _DS.amber.withValues(alpha: 0.5)
                            : _DS.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 14,
                      color: isWholesale ? _DS.amber : _DS.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'x$baseWholesaleMinQty+',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isWholesale ? _DS.amberDark : _DS.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${baseWholesalePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isWholesale ? _DS.amber : _DS.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // Savings badge
        if (isWholesale) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _DS.successLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '¡Ahorro mayorista de S/ ${(baseSalePrice - effectivePrice).toStringAsFixed(2)}!',
              style: const TextStyle(
                fontSize: 11,
                color: _DS.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],

        // Wholesale hint
        if (hasWholesale && !isWholesale) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _DS.amberLight,
              borderRadius: BorderRadius.circular(_DS.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: _DS.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Compra $baseWholesaleMinQty+ y paga S/ ${baseWholesalePrice!.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _DS.amberDark,
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
  // For image-aware chips: map of option value → image url
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
            // Check if any option in this key has an image
            final hasImages = options.any(
              (opt) => variantImageUrls[opt] != null,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label + selected value inline
                  Row(
                    children: [
                      Text(
                        _formatLabel(key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _DS.textPrimary,
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
                    // Visual chips with image + label (horizontal scroll)
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
                                borderRadius: BorderRadius.circular(_DS.radius),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? _DS.border
                                          : _DS.divider,
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
                                  _DS.radius - 1,
                                ),
                                child: Stack(
                                  children: [
                                    // Image
                                    Positioned.fill(
                                      child:
                                          imgUrl != null
                                              ? Image.network(
                                                imgUrl,
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
                                                errorBuilder:
                                                    (_, __, ___) => Container(
                                                      color: _DS.bg,
                                                      child: const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 22,
                                                        color: _DS.textMuted,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                color: _DS.bg,
                                                child: const Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 22,
                                                  color: _DS.textMuted,
                                                ),
                                              ),
                                    ),
                                    // Bottom label strip
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
                                    // Selected checkmark
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
                    // Text-only chips (no images)
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
                                          : _DS.bg,
                                  borderRadius: BorderRadius.circular(
                                    _DS.radius,
                                  ),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : enabled
                                            ? _DS.border
                                            : _DS.divider,
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
                                            ? _DS.textPrimary
                                            : _DS.textMuted,
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
        border: const Border(top: BorderSide(color: _DS.border, width: 1)),
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
              // Compact quantity selector
              if (canBuy) ...[
                Container(
                  decoration: BoxDecoration(
                    color: _DS.bg,
                    borderRadius: BorderRadius.circular(_DS.radius),
                    border: Border.all(color: _DS.border),
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
                              color: _DS.textPrimary,
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

              // Add to cart button — takes remaining width
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
                      color: canBuy ? null : _DS.slateLight,
                      borderRadius: BorderRadius.circular(_DS.radius),
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
                          color: canBuy ? Colors.white : _DS.textMuted,
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
                                color: canBuy ? Colors.white : _DS.textMuted,
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
        color: enabled ? AppColors.primary : _DS.textMuted,
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
      style: const TextStyle(fontSize: 14, color: _DS.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _DS.textMuted),
        labelStyle: const TextStyle(color: _DS.textSecondary),
        filled: true,
        fillColor: _DS.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _DS.border),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
        ),
        isDense: true,
      ),
    );
  }
}

// ─── ADMIN INFO CARD ─────────────────────────────────────────────────────────

class ProductAdminInfoCard extends StatelessWidget {
  final double unitCost;
  final double profit;
  final double margin;
  final double? wholesalePrice;
  final int wholesaleMinQuantity;
  final int reorderPoint;

  const ProductAdminInfoCard({
    super.key,
    required this.unitCost,
    required this.profit,
    required this.margin,
    required this.wholesalePrice,
    required this.wholesaleMinQuantity,
    required this.reorderPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _DS.slate.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: _DS.slate,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Info interna',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _DS.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _AdminRow(
            Icons.receipt_long_rounded,
            const Color(0xFFF59E0B),
            'Costo unitario',
            'S/ ${unitCost.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _AdminRow(
            Icons.trending_up_rounded,
            _DS.success,
            'Ganancia estim.',
            'S/ ${profit.toStringAsFixed(2)}',
            badge: '${margin.toStringAsFixed(1)}%',
            valueColor: _DS.success,
          ),
          if (wholesalePrice != null) ...[
            const SizedBox(height: 8),
            _AdminRow(
              Icons.people_rounded,
              _DS.amber,
              'Precio mayor',
              'S/ ${wholesalePrice!.toStringAsFixed(2)}',
              badge: 'x$wholesaleMinQuantity',
            ),
          ],
          const SizedBox(height: 8),
          _AdminRow(
            Icons.warning_amber_rounded,
            _DS.danger,
            'Pto. reorden',
            '$reorderPoint unds.',
          ),
        ],
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? badge;
  final Color? valueColor;
  const _AdminRow(
    this.icon,
    this.iconColor,
    this.label,
    this.value, {
    this.badge,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _DS.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? _DS.textPrimary,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _DS.slateLight,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 9,
                color: _DS.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
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
      decoration: _DS.card(),
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
              color: _DS.textSecondary,
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
      decoration: _DS.card(),
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
          Container(height: 1, color: _DS.divider),
          ...entries.asMap().entries.map((e) {
            final isEven = e.key % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              color: isEven ? _DS.bg : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.value.key.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _DS.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.value.value.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _DS.textPrimary,
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

// ─── REVIEWS CARD ─────────────────────────────────────────────────────────────

class ProductReviewsCard extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onAddReview;

  const ProductReviewsCard({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
    required this.onAddReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _DS.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _CardHeader(
                icon: Icons.star_rounded,
                iconColor: Color(0xFFF5A623),
                iconBg: Color(0xFFFEF3C7),
                title: 'Reseñas',
              ),
              GestureDetector(
                onTap: onAddReview,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(_DS.radius),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Opinar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (totalReviews == 0) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 36,
                    color: _DS.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sé el primero en opinar',
                    style: TextStyle(
                      fontSize: 13,
                      color: _DS.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            // Summary row
            Row(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: _DS.textPrimary,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < averageRating.floor()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _DS.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews calificaciones',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _DS.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _DS.divider),
            const SizedBox(height: 14),
            ...reviews.take(3).map((r) => _ReviewRow(review: r)),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    final name = review['user_name']?.toString() ?? 'Usuario';
    final rating = (review['rating'] as num?)?.toInt() ?? 5;
    final comment = review['comment'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _DS.textPrimary,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _DS.amber,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 13,
                color: _DS.textSecondary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: _DS.divider),
        ],
      ),
    );
  }
}

// ─── AVAILABILITY CARD ───────────────────────────────────────────────────────

class ProductAvailabilityCard extends StatelessWidget {
  final bool isActive;
  final bool isAdmin;
  final bool isLoadingExtra;
  final List<Map<String, dynamic>> warehouseStocks;
  final int effectiveStock;
  final String stockLabel;
  final bool showQuantitySelector;
  final int selectedQty;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const ProductAvailabilityCard({
    super.key,
    required this.isActive,
    required this.isAdmin,
    required this.isLoadingExtra,
    required this.warehouseStocks,
    required this.effectiveStock,
    required this.stockLabel,
    required this.showQuantitySelector,
    required this.selectedQty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _DS.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.warehouse_rounded,
            iconColor: Color(0xFF0D9488),
            iconBg: Color(0xFFCCFBF1),
            title: 'Stock por almacén',
          ),
          const SizedBox(height: 14),
          if (isLoadingExtra)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          else if (warehouseStocks.isEmpty)
            const Text(
              'Sin registros.',
              style: TextStyle(fontSize: 12, color: _DS.textMuted),
            )
          else
            ...warehouseStocks.map((row) {
              final name = row['warehouses']?['name'] ?? 'Almacén';
              final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
              final ok = stock > 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _DS.bg,
                  borderRadius: BorderRadius.circular(_DS.radiusSm + 2),
                  border: Border.all(color: _DS.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: ok ? _DS.successLight : _DS.dangerLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.warehouse_rounded,
                        size: 13,
                        color: ok ? _DS.success : _DS.danger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _DS.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            ok
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : _DS.dangerLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '$stock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ok ? AppColors.primary : _DS.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── NUEVO COMPONENTE: PRODUCT BATCHES CARD ──────────────────────────────────

class ProductBatchesCard extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> batches;

  const ProductBatchesCard({
    super.key,
    required this.isLoading,
    required this.batches,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _DS.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.calendar_month_rounded,
            iconColor: Color(0xFFD97706),
            iconBg: Color(0xFFFEF3C7),
            title: 'Lotes y Vencimientos',
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          else if (batches.isEmpty)
            const Text(
              'No hay lotes con stock para esta variante.',
              style: TextStyle(fontSize: 12, color: _DS.textMuted),
            )
          else
            ...batches.map((row) {
              final batchNum = row['batch_number']?.toString() ?? 'Sin Lote';
              final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
              final whName =
                  row['warehouses']?['name']?.toString() ?? 'Almacén';
              final String? expStr = row['expiry_date'];

              DateTime? expDate;
              int daysRemaining = 999;

              if (expStr != null) {
                expDate = DateTime.tryParse(expStr);
                if (expDate != null) {
                  daysRemaining = expDate.difference(DateTime.now()).inDays;
                }
              }

              // Lógica de semáforo de colores
              Color statusColor = _DS.success;
              Color statusBg = _DS.successLight;
              String statusLabel = 'OK';
              IconData statusIcon = Icons.check_circle_outline_rounded;

              if (expDate != null) {
                if (daysRemaining < 0) {
                  statusColor = _DS.danger;
                  statusBg = _DS.dangerLight;
                  statusLabel = 'Vencido';
                  statusIcon = Icons.warning_rounded;
                } else if (daysRemaining <= 30) {
                  statusColor = _DS.amberDark;
                  statusBg = _DS.amberLight;
                  statusLabel = 'Vence pronto';
                  statusIcon = Icons.info_outline_rounded;
                }
              }

              String dateLabel = 'Sin fecha';
              if (expDate != null) {
                dateLabel =
                    '${expDate.day.toString().padLeft(2, '0')}/${expDate.month.toString().padLeft(2, '0')}/${expDate.year}';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _DS.bg,
                  borderRadius: BorderRadius.circular(_DS.radiusSm + 2),
                  border: Border.all(color: _DS.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, size: 16, color: statusColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                batchNum,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _DS.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: _DS.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                whName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _DS.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.event_rounded,
                                size: 12,
                                color: _DS.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      expDate != null && daysRemaining <= 30
                                          ? statusColor
                                          : _DS.textSecondary,
                                  fontWeight:
                                      expDate != null && daysRemaining <= 30
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$stock',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'unds',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
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
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _DS.textPrimary,
          ),
        ),
      ],
    );
  }
}
