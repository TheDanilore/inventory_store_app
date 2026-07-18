import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_admin_info_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_availability_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_batches_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';

import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_top_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_price_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_bottom_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_input_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_description_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductEntity product;
  final bool isAdmin;
  final String? initialVariantId;
  final bool isEmbedded;
  final Widget? cartActionWidget;
  final void Function(
    BuildContext context,
    ProductEntity product,
    int qty,
    ProductVariantEntity? selectedVariant,
    String? effectiveImageUrl,
    double effectivePrice,
  )?
  onAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isAdmin = false,
    this.initialVariantId,
    this.isEmbedded = false,
    this.cartActionWidget,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<ProductDetailCubit>()..loadInitialData(
                product: product,
                isAdmin: isAdmin,
                initialVariantId: initialVariantId,
              ),
      child: BlocListener<ProductDetailCubit, ProductDetailState>(
        listenWhen:
            (previous, current) =>
                previous.errorMessage != current.errorMessage ||
                previous.successMessage != current.successMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
            context.read<ProductDetailCubit>().clearMessages();
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
            context.read<ProductDetailCubit>().clearMessages();
          }
        },
        child: _ProductDetailScreenContent(
          isEmbedded: isEmbedded,
          cartActionWidget: cartActionWidget,
          onAddToCart: onAddToCart,
          product: product,
        ),
      ),
    );
  }
}

class _ProductDetailScreenContent extends StatefulWidget {
  final bool isEmbedded;
  final Widget? cartActionWidget;
  final ProductEntity product;
  final void Function(
    BuildContext context,
    ProductEntity product,
    int qty,
    ProductVariantEntity? selectedVariant,
    String? effectiveImageUrl,
    double effectivePrice,
  )?
  onAddToCart;

  const _ProductDetailScreenContent({
    this.isEmbedded = false,
    this.cartActionWidget,
    this.onAddToCart,
    required this.product,
  });

  @override
  State<_ProductDetailScreenContent> createState() =>
      _ProductDetailScreenContentState();
}

class _ProductDetailScreenContentState
    extends State<_ProductDetailScreenContent> {
  final PageController _pageController = PageController();

  ProductDetailCubit get cubit => context.read<ProductDetailCubit>();
  ProductDetailState get state => context.watch<ProductDetailCubit>().state;

  ProductEntity get product => widget.product;
  bool get isAdmin => cubit.isAdmin;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // DERIVED GETTERS

  bool get _isWishlistLoading => state.isWishlistLoading;
  bool get _isWishlisted => state.isWishlisted;
  bool get _showVariantImage => state.showVariantImage;
  List<ProductVariantEntity> get _variants => state.variants;
  List<Map<String, dynamic>> get _reviewsList => state.reviewsList;
  List<Map<String, dynamic>> get _activeIngredients => state.activeIngredients;
  double get _averageRating => state.averageRating;

  int get _selectedQty => state.selectedQty;
  int get _selectedImageIndex => state.selectedImageIndex;
  String? get _selectedVariantId => state.selectedVariantId;

  ProductVariantEntity? get _selectedVariant => state.selectedVariant;
  double get _baseSalePrice => state.baseSalePrice;
  double? get _baseWholesalePrice => state.baseWholesalePrice;
  int get _baseWholesaleMinQty => state.baseWholesaleMinQty;
  double get _effectivePrice => state.effectivePrice;
  int get _effectiveStock => state.effectiveStock;
  bool get _isActive => state.isActive;
  bool get _canBuy => state.canBuy;
  List<String> get _attributeKeys => state.attributeKeys;
  String? get _selectedVariantImageUrl => state.selectedVariantImageUrl;
  List<ProductImageEntity> get _galleryImages => state.images;
  String? _variantImageUrl(ProductVariantEntity variant) =>
      state.variantImageUrl(variant);
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
      await cubit.toggleWishlist();
      _showSnack(
        state.isWishlisted ? 'Guardado en favoritos' : 'Eliminado de favoritos',
        isSuccess: state.isWishlisted,
      );
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _onGalleryChanged(int index) {
    cubit.setImageIndex(index);
  }

  // CART & REVIEWS

  void _addToCart() {
    final qty = state.selectedQty;
    final stock = state.effectiveStock;
    final variants = state.variants;
    final selectedVariant = state.selectedVariant;
    final effectivePrice = state.effectivePrice;

    final String? effectiveImageUrl =
        state.selectedVariantImageUrl ??
        (state.images.isNotEmpty
            ? state.images[0].imageUrl
            : widget.product.primaryImageUrl);

    if (variants.isNotEmpty && selectedVariant == null) {
      if (widget.onAddToCart != null) {
        widget.onAddToCart?.call(
          context,
          widget.product,
          qty,
          selectedVariant,
          effectiveImageUrl,
          effectivePrice,
        );
      } else {
        final cartCubit = context.read<CartCubit>();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder:
              (sheetContext) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: CartVariantPickerSheet(
                  cartCubit: cartCubit,
                  product: widget.product,
                ),
              ),
        );
      }
      return;
    }

    if (!cubit.validateCartAddition(qty)) {
      return;
    }

    if (widget.onAddToCart != null) {
      widget.onAddToCart?.call(
        context,
        widget.product,
        qty,
        selectedVariant,
        effectiveImageUrl,
        effectivePrice,
      );
    } else {
      context.read<CartCubit>().addItem(
        CartItemEntity(
          productId: widget.product.id,
          productName: widget.product.name,
          cartKey: CartItemEntity.buildKey(
            widget.product.id,
            selectedVariant?.id,
          ),
          quantity: qty,
          unitPrice: effectivePrice,
          unitCost: selectedVariant?.unitCost ?? widget.product.unitCost,
          availableStock: stock,
          usesBatches: widget.product.usesBatches,
          imageUrl: effectiveImageUrl,
          variantLabel: selectedVariant?.label,
        ),
      );
    }

    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
    _showSnack('Añadido al carrito!', isSuccess: true);
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
            (sheetContext) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
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
                        color: AppColors.background,
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
                            cubit.setQty(n.clamp(1, _effectiveStock));
                          }
                          Navigator.pop(sheetContext);
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

  // REVIEWS

  Future<void> _onAddReviewTapped() async {
    if (isAdmin) {
      _showReviewDialog(isAdmin: true);
      return;
    }

    final canReview = await cubit.canReview();
    if (!canReview) {
      _showSnack(
        'Debes iniciar sesión y haber comprado este producto para opinar.',
      );
      return;
    }

    if (!mounted) return;
    final authCubit = context.read<AuthCubit>();
    final currentUser = authCubit.state.currentUser;
    final defaultName = currentUser?.fullName ?? 'Usuario';

    _showReviewDialog(isAdmin: false, defaultName: defaultName);
  }

  void _showReviewDialog({required bool isAdmin, String? defaultName}) {
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
                              color: AppColors.background,
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

                                          await cubit.addReview(
                                            userName: name,
                                            rating: selectedRating,
                                            comment: commentCtrl.text.trim(),
                                            isAdminSubmission: isAdmin,
                                          );

                                          if (!context.mounted) return;
                                          Navigator.pop(dialogCtx);
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

  List<ProductVariantEntity> get _thumbnailVariants {
    if (_attributeKeys.length <= 1) return _variants;
    final list = <ProductVariantEntity>[];
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

  // BUILD

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
          leading:
              widget.isEmbedded
                  ? null
                  : Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      top: 8,
                      bottom: 8,
                    ),
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
                    onSelected: (value) async {
                      if (value == 'export') {
                        final currentState = state;
                        final Map<String, int> stockMap = {};
                        for (final row in currentState.warehouseStocks) {
                          final variantId = row['variant_id'] as String?;
                          final stock =
                              (row['available_quantity'] as num?)?.toInt() ?? 0;
                          if (variantId != null) {
                            stockMap.update(
                              variantId,
                              (current) => current + stock,
                              ifAbsent: () => stock,
                            );
                          }
                        }
                        // Mostrar diálogo de carga
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (dialogCtx) => const AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 20),
                                    Text(
                                      'Generando PDF...',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                        );
                        try {
                          if (currentState.product == null) return;
                          await context
                              .read<ProductDetailCubit>()
                              .exportProductPdf();
                        } catch (e) {
                          if (context.mounted) {
                            _showSnack('Error al generar PDF: $e');
                          }
                        } finally {
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        }
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
                child: _buildWishlistButton(),
              ),
              if (widget.cartActionWidget != null)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 16.0,
                    top: 8,
                    bottom: 8,
                  ),
                  child: widget.cartActionWidget,
                ),
            ],
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: ProductGallerySection(
              images: gallery.toList(),
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
                      final s = context.read<ProductDetailCubit>().state;
                      final effectiveImageUrl =
                          s.selectedVariantImageUrl ??
                          (s.images.isNotEmpty
                              ? s.images[0].imageUrl
                              : widget.product.primaryImageUrl);
                      if (widget.onAddToCart != null) {
                        widget.onAddToCart?.call(
                          context,
                          widget.product,
                          s.selectedQty,
                          null,
                          effectiveImageUrl,
                          s.effectivePrice,
                        );
                      } else {
                        final cartCubit = context.read<CartCubit>();
                        final productDetailCubit =
                            context.read<ProductDetailCubit>();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (sheetContext) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(
                                        sheetContext,
                                      ).viewInsets.bottom,
                                ),
                                child: CartVariantPickerSheet(
                                  cartCubit: cartCubit,
                                  product: widget.product,
                                  onVariantSelected: (variant) {
                                    productDetailCubit.setVariant(variant.id);
                                    productDetailCubit.selectVariantImage(
                                      variant.id,
                                    );
                                  },
                                ),
                              ),
                        );
                      }
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

    if (widget.isEmbedded) {
      return Container(color: AppColors.background, child: content);
    }

    if (isAdmin) {
      return Scaffold(backgroundColor: AppColors.background, body: content);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
      bottomNavigationBar: ProductBottomBar(
        canBuy: _canBuy,
        isActive: _isActive,
        effectiveStock: _effectiveStock,
        effectivePrice: _effectivePrice,
        selectedQty: _selectedQty,
        onDecrement: () => cubit.setQty(_selectedQty - 1),
        onIncrement: () => cubit.setQty(_selectedQty + 1),
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
