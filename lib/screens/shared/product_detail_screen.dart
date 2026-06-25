// ignore_for_file: unused_element_parameter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:go_router/go_router.dart';
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
import 'package:inventory_store_app/providers/shared/product_detail_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_gallery_section.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_top_section.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_price_section.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_bottom_bar.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_input_field.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_description_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_details_card.dart';
import 'package:inventory_store_app/screens/shared/widgets/product_ingredients_card.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;
  final bool isAdmin;
  final String? initialVariantId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isAdmin = false,
    this.initialVariantId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => ProductDetailProvider(
            product: product,
            isAdmin: isAdmin,
            initialVariantId: initialVariantId,
          ),
      child: const _ProductDetailScreenContent(),
    );
  }
}

class _ProductDetailScreenContent extends StatefulWidget {
  const _ProductDetailScreenContent({super.key});

  @override
  State<_ProductDetailScreenContent> createState() =>
      _ProductDetailScreenContentState();
}

class _ProductDetailScreenContentState
    extends State<_ProductDetailScreenContent> {
  final PageController _pageController = PageController();

  ProductDetailProvider get provider => context.read<ProductDetailProvider>();
  ProductDetailProvider get providerWatch =>
      context.watch<ProductDetailProvider>();

  ProductModel get product => providerWatch.product;
  bool get isAdmin => providerWatch.isAdmin;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── DERIVED GETTERS ─────────────────────────────────────────────────────

  bool get _isWishlistLoading => providerWatch.isWishlistLoading;
  bool get _isWishlisted => providerWatch.isWishlisted;
  bool get _showVariantImage => providerWatch.showVariantImage;
  List<ProductVariantModel> get _variants => providerWatch.variants;
  List<Map<String, dynamic>> get _warehouseStocks =>
      providerWatch.warehouseStocks;
  List<Map<String, dynamic>> get _reviewsList => providerWatch.reviewsList;
  List<Map<String, dynamic>> get _activeIngredients =>
      providerWatch.activeIngredients;
  double get _averageRating => providerWatch.averageRating;

  int get _selectedQty => providerWatch.selectedQty;
  int get _selectedImageIndex => providerWatch.selectedImageIndex;
  String? get _selectedVariantId => providerWatch.selectedVariantId;

  ProductVariantModel? get _selectedVariant => providerWatch.selectedVariant;
  double get _baseSalePrice => providerWatch.baseSalePrice;
  double? get _baseWholesalePrice => providerWatch.baseWholesalePrice;
  int get _baseWholesaleMinQty => providerWatch.baseWholesaleMinQty;
  double get _effectivePrice => providerWatch.effectivePrice;
  int get _effectiveStock => providerWatch.effectiveStock;
  bool get _isActive => providerWatch.isActive;
  bool get _canBuy => providerWatch.canBuy;
  List<String> get _attributeKeys => providerWatch.attributeKeys;
  String? get _selectedVariantImageUrl => providerWatch.selectedVariantImageUrl;
  List<ProductImageModel> get _galleryImages => providerWatch.images;
  String? _variantImageUrl(ProductVariantModel variant) =>
      providerWatch.variantImageUrl(variant);
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

  Future<void> _toggleWishlist() async {
    try {
      await provider.toggleWishlist();
      _showSnack(
        providerWatch.isWishlisted
            ? '❤️ Guardado en favoritos'
            : 'Eliminado de favoritos',
        isSuccess: providerWatch.isWishlisted,
      );
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _selectVariant(
    ProductVariantModel variant, {
    bool resetQuantity = true,
    bool animateGallery = true,
  }) {
    provider.selectVariant(variant);
    if (animateGallery) {
      provider.setPage(0);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  void _onGalleryChanged(int index) {
    provider.setPage(index);
  }

  // ─── CART & REVIEWS ───────────────────────────────────────────────────────

  void _addToCart() {
    final qty = provider.selectedQty;
    final stock = provider.effectiveStock;
    final variants = provider.variants;
    final selectedVariant = provider.selectedVariant;
    final effectivePrice = provider.effectivePrice;

    final String? effectiveImageUrl =
        provider.selectedVariantImageUrl ??
        (provider.images.isNotEmpty
            ? provider.images[0].imageUrl
            : product.primaryImageUrl);

    if (variants.isNotEmpty && selectedVariant == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (sheetContext) => CartVariantPickerSheet(
              cart: Provider.of<CartProvider>(sheetContext, listen: false),
              product: product,
              initialQuantity: qty,
              selectedVariantId: provider.selectedVariantId,
            ),
      );
      return;
    }

    if (stock <= 0) {
      _showSnack('Sin stock.');
      return;
    }
    if (qty > stock) {
      _showSnack('Cantidad mayor al stock.');
      return;
    }

    Provider.of<CartProvider>(context, listen: false).addItem(
      product,
      quantity: qty,
      variantId: selectedVariant?.id,
      variantLabel: selectedVariant?.label,
      unitPrice: effectivePrice,
      imageUrl: effectiveImageUrl,
      sku: selectedVariant?.sku,
      availableStock: stock,
    );
    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
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

  Future<void> _showQuantityDialog() async {
    final ctrl = TextEditingController(text: '$_selectedQty');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Cantidad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Máx. $_effectiveStock disponibles',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          final n = int.tryParse(ctrl.text.trim());
                          if (n != null && n > 0) {
                            provider.setSelectedQty(
                              n.clamp(1, _effectiveStock),
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar Cantidad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  // ─── REVIEWS ─────────────────────────────────────────────────────────────

  Future<void> _onAddReviewTapped() async {
    if (isAdmin) {
      _showReviewDialog(isAdmin: true);
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnack('Inicia sesión para opinar.');
      return;
    }
    try {
      final profile =
          await Supabase.instance.client
              .from('profiles')
              .select('id, full_name')
              .eq('auth_user_id', user.id)
              .single();
      final profileId = profile['id'];
      final fullName = profile['full_name'] ?? 'Usuario';
      final purchases = await Supabase.instance.client
          .from('order_items')
          .select('id, orders!inner(customer_id)')
          .eq('product_id', product.id)
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
                          ProductInputField(
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
                        ProductInputField(
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
                                            await Supabase.instance.client
                                                .from('product_reviews')
                                                .insert({
                                                  'product_id': product.id,
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
                                            if (!context.mounted) return;
                                            Navigator.pop(dialogCtx);
                                            _showSnack(
                                              '¡Reseña publicada!',
                                              isSuccess: true,
                                            );
                                            provider.loadData();
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
    ).then((_) {
      commentCtrl.dispose();
      nameCtrl.dispose();
    });
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

    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    final content = CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          stretch: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          actions: [
            if (isAdmin) ...[
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: Colors.black87,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'export') {
                        ProductPdfGenerator.shareProduct(
                          product,
                          variants: _variants,
                          stockByVariant: _stockByVariant,
                        );
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: Text('Exportar PDF'),
                          ),
                        ],
                  ),
                ),
              ),
            ] else ...[
              if (!isAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
                  child: _buildWishlistButton(),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                              color: Colors.black87,
                            ),
                            onPressed: () => context.push('/customer/cart'),
                          ),
                          if (cart.itemCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${cart.itemCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: ProductGallerySection(
              images: gallery,
              pageController: _pageController,
              selectedIndex: _selectedImageIndex,
              onPageChanged: _onGalleryChanged,
              wishlistWidget: null,
              variantImageOverrideUrl:
                  (_showVariantImage && _selectedVariant != null)
                      ? _selectedVariantImageUrl
                      : null,
              variantLabelOverride:
                  (_showVariantImage && _selectedVariant != null)
                      ? _selectedVariant!.attributeMap.values.join(' - ')
                      : null,
              fallbackImageUrl: product.primaryImageUrl,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              ProductTopSection(
                name: product.name,
                sku: _selectedVariant?.sku,
                isActive: _isActive,
                effectiveStock: _effectiveStock,
                averageRating: _averageRating,
                totalReviews: _reviewsList.length,
              ),
              const SizedBox(height: 16),

              ProductPriceSection(
                effectivePrice: _effectivePrice,
                baseSalePrice: _baseSalePrice,
                baseWholesalePrice: _baseWholesalePrice,
                baseWholesaleMinQty: _baseWholesaleMinQty,
                selectedQty: _selectedQty,
              ),
              const SizedBox(height: 24),

              if (_variants.isNotEmpty) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final currentVariantId = provider.selectedVariantId;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (sheetContext) => CartVariantPickerSheet(
                              cart: Provider.of<CartProvider>(
                                sheetContext,
                                listen: false,
                              ),
                              product: product,
                              selectedVariantId: currentVariantId,
                              onVariantSelected: (variant) {
                                _selectVariant(variant);
                              },
                            ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Opciones',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedVariant?.label ??
                                            'Selecciona un modelo',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_thumbnailVariants.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: Row(
                                      children:
                                          _thumbnailVariants.take(6).map((v) {
                                            final imgUrl =
                                                _variantImageUrl(v) ??
                                                product.primaryImageUrl;
                                            final isSelected =
                                                _selectedVariantId == v.id;
                                            return Container(
                                              width: 40,
                                              height: 40,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      isSelected
                                                          ? AppColors.primary
                                                          : AppColors.border,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child:
                                                    (imgUrl != null &&
                                                            imgUrl.isNotEmpty)
                                                        ? CachedNetworkImage(
                                                          imageUrl: imgUrl,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (
                                                                context,
                                                                url,
                                                              ) => Container(
                                                                color:
                                                                    AppColors
                                                                        .border,
                                                              ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => Container(
                                                                color:
                                                                    AppColors
                                                                        .border,
                                                              ),
                                                        )
                                                        : Container(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Más',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (isAdmin) ProductAvailabilityCard(),
              if (isAdmin) const SizedBox(height: 16),

              if (isAdmin && product.usesBatches) ...[
                const ProductBatchesCard(),
                const SizedBox(height: 16),
              ],

              if (isAdmin) ...[
                ProductAdminInfoCard(),
                const SizedBox(height: 16),

                ProductQuickDecisionsCard(),
                const SizedBox(height: 16),
              ],

              ProductDetailsCard(details: mergedDetails),
              if (mergedDetails.isNotEmpty) const SizedBox(height: 16),

              if (_activeIngredients.isNotEmpty) ...[
                ProductIngredientsCard(ingredients: _activeIngredients),
                const SizedBox(height: 16),
              ],

              ProductDescriptionCard(description: product.description ?? ''),
              if ((product.description ?? '').trim().isNotEmpty)
                const SizedBox(height: 16),

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

    if (isAdmin) {
      return AdminLayout(
        title: product.name,
        showBackButton: true,
        showSettingsButton: false,
        showAppBar: false,
        body: Container(color: AppColors.bg, child: content),
      );
    }

    return CustomerLayout(
      title: product.name,
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: false,
      showAppBar: false,
      body: Container(color: AppColors.bg, child: content),
      bottomNavigationBar: ProductBottomBar(
        canBuy: _canBuy,
        isActive: _isActive,
        effectiveStock: _effectiveStock,
        effectivePrice: _effectivePrice,
        selectedQty: _selectedQty,
        onDecrement: () => provider.setSelectedQty(_selectedQty - 1),
        onIncrement: () => provider.setSelectedQty(_selectedQty + 1),
        onQtyTap: _showQuantityDialog,
        onAddToCart: _addToCart,
      ),
    );
  }

  Widget _buildWishlistButton() {
    if (_isWishlistLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              _isWishlisted
                  ? AppColors.danger
                  : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
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
