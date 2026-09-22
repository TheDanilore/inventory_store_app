import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_admin_info_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_availability_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_batches_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_description_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_input_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_price_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_top_section.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductEntity product;
  final String? initialVariantId;
  final bool isEmbedded;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.initialVariantId,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<ProductDetailCubit>()..loadInitialData(
                product: product,
                initialVariantId: initialVariantId,
              ),
      child: BlocListener<ProductDetailCubit, ProductDetailState>(
        listenWhen:
            (previous, current) =>
                previous.errorMessage != current.errorMessage ||
                previous.successMessage != current.successMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.error,
            );
            context.read<ProductDetailCubit>().clearMessages();
          }
          if (state.successMessage != null) {
            AppSnackbar.show(
              context,
              message: state.successMessage!,
              type: SnackbarType.success,
            );
            context.read<ProductDetailCubit>().clearMessages();
          }
        },
        child: _ProductDetailScreenContent(
          isEmbedded: isEmbedded,
          product: product,
        ),
      ),
    );
  }
}

class _ProductDetailScreenContent extends StatefulWidget {
  final bool isEmbedded;
  final ProductEntity product;

  const _ProductDetailScreenContent({
    this.isEmbedded = false,
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
  ProductDetailState get state => context.read<ProductDetailCubit>().state;
  ProductEntity get product => widget.product;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // DERIVED GETTERS
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

  void _onGalleryChanged(int index) {
    cubit.setImageIndex(index);
  }

  void _showSnack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: msg,
      type:
          isError
              ? SnackbarType.error
              : isSuccess
              ? SnackbarType.success
              : SnackbarType.info,
    );
  }

  Future<void> _exportPdf() async {
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
                Text('Generando PDF...', textAlign: TextAlign.center),
              ],
            ),
          ),
    );

    try {
      if (cubit.state.product == null) return;
      await cubit.exportProductPdf();
    } catch (e) {
      if (mounted) {
        _showSnack('Error al generar PDF: $e', isError: true);
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showVariantPickerModal() {
    if (_variants.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (sheetCtx) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Variantes del Producto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _variants.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final v = _variants[index];
                      final isSelected = v.id == _selectedVariantId;
                      final imgUrl =
                          _variantImageUrl(v) ?? product.primaryImageUrl;

                      return InkWell(
                        onTap: () {
                          cubit.setVariant(v.id);
                          cubit.selectVariantImage(v.id);
                          Navigator.pop(sheetCtx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.primary.withValues(alpha: 0.06)
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    imgUrl != null && imgUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (context, url, error) => Container(
                                                width: 48,
                                                height: 48,
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                        )
                                        : Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'SKU: ${v.sku ?? "N/A"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${(v.salePrice ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  if (v.wholesalePrice != null)
                                    Text(
                                      'Mayoreo: \$${v.wholesalePrice!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showAddReviewDialog() {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
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
                          'Registrar Opinión de Cliente',
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
                        ProductInputField(
                          controller: nameCtrl,
                          hint: 'Nombre del cliente',
                          label: 'Nombre',
                        ),
                        const SizedBox(height: 12),
                        ProductInputField(
                          controller: commentCtrl,
                          hint: 'Comentario u opinión...',
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
                                          final name = nameCtrl.text.trim();
                                          if (name.isEmpty) {
                                            _showSnack(
                                              'Ingresa el nombre del cliente.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          setS(() => isSubmitting = true);

                                          await cubit.addReview(
                                            userName: name,
                                            rating: selectedRating,
                                            comment: commentCtrl.text.trim(),
                                            isAdminSubmission: true,
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
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
                      backgroundColor: Colors.white.withValues(alpha: 0.85),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.black87,
                        ),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                      ),
                    ),
                  ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.85),
                child: IconButton(
                  tooltip: 'Exportar PDF',
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onPressed: _exportPdf,
                ),
              ),
            ),
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

              _buildOptionsTile(),

              const ProductAvailabilityCard(),
              const SizedBox(height: 16),

              if (product.usesBatches) ...[
                const ProductBatchesCard(),
                const SizedBox(height: 16),
              ],

              const ProductAdminInfoCard(),
              const SizedBox(height: 16),

              const ProductQuickDecisionsCard(),
              const SizedBox(height: 16),

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
                onAddReview: _showAddReviewDialog,
              ),
            ]),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              title: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    tooltip: 'Exportar PDF',
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: _exportPdf,
                  ),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Columna Izquierda: Galería ERP (45%) ────────────────
                      Expanded(
                        flex: 45,
                        child: Card(
                          elevation: 0,
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusLg,
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: 520,
                              child: ProductGallerySection(
                                images: gallery.toList(),
                                pageController: _pageController,
                                selectedIndex: _selectedImageIndex,
                                onPageChanged: _onGalleryChanged,
                                wishlistWidget: null,
                                variantImageOverrideUrl:
                                    (_showVariantImage &&
                                            _selectedVariant != null)
                                        ? _selectedVariantImageUrl
                                        : null,
                                variantLabelOverride:
                                    (_showVariantImage &&
                                            _selectedVariant != null)
                                        ? _selectedVariant!.attributeMap.values
                                            .join(' - ')
                                        : null,
                                fallbackImageUrl: product.primaryImageUrl,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // ── Columna Derecha: Información ERP (55%) ─────────────
                      Expanded(
                        flex: 55,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const SizedBox(height: 20),

                              _buildOptionsTile(),

                              const ProductAvailabilityCard(),
                              const SizedBox(height: 16),
                              if (product.usesBatches) ...[
                                const ProductBatchesCard(),
                                const SizedBox(height: 16),
                              ],
                              const ProductAdminInfoCard(),
                              const SizedBox(height: 16),
                              const ProductQuickDecisionsCard(),
                              const SizedBox(height: 16),
                              ProductDetailsCard(details: mergedDetails),
                              const SizedBox(height: 16),
                              if (_activeIngredients.isNotEmpty) ...[
                                ProductIngredientsCard(
                                  ingredients: _activeIngredients,
                                ),
                                const SizedBox(height: 16),
                              ],
                              ProductDescriptionCard(
                                description: product.description ?? '',
                              ),
                              const SizedBox(height: 16),
                              ProductReviewsCard(
                                averageRating: _averageRating,
                                totalReviews: _reviewsList.length,
                                reviews: _reviewsList,
                                onAddReview: _showAddReviewDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (widget.isEmbedded) {
          return Container(color: AppColors.background, child: content);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: content,
        );
      },
    );
  }

  Widget _buildOptionsTile() {
    if (_variants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showVariantPickerModal,
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
                              'Variantes',
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
                                    'Selecciona una variante',
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
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children:
                                  _thumbnailVariants.take(6).map((v) {
                                    final imgUrl =
                                        _variantImageUrl(v) ??
                                        product.primaryImageUrl;
                                    final isSelected =
                                        _selectedVariantId == v.id;

                                    return GestureDetector(
                                      onTap: () {
                                        cubit.setVariant(v.id);
                                        cubit.selectVariantImage(v.id);
                                      },
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? AppColors.primary
                                                    : AppColors.border,
                                            width: isSelected ? 2.5 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                                              AppColors.border,
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                  )
                                                  : Container(
                                                    color: AppColors.border,
                                                  ),
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
                        'Ver todas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
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
    );
  }
}
