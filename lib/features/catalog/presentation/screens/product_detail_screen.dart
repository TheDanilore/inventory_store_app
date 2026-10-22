import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_admin_info_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_availability_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_batches_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_description_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_detail_header.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_qr_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_input_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_top_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_variant_matrix.dart';

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
  final FocusNode _screenFocusNode = FocusNode();
  int _desktopSelectedTab = 0;
  int _mobileSelectedTab = 0;

  ProductDetailCubit get cubit => context.read<ProductDetailCubit>();
  ProductDetailState get state => context.read<ProductDetailCubit>().state;
  ProductEntity get product => widget.product;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // DERIVED GETTERS
  bool get _showVariantImage => state.showVariantImage;
  List<ProductVariantEntity> get _variants => state.variants;
  List<Map<String, dynamic>> get _reviewsList => state.reviewsList;
  List<Map<String, dynamic>> get _activeIngredients => state.activeIngredients;
  double get _averageRating => state.averageRating;

  int get _selectedImageIndex => state.selectedImageIndex;
  String? get _selectedVariantId => state.selectedVariantId;

  ProductVariantEntity? get _selectedVariant => state.selectedVariant;
  double? get _baseWholesalePrice => state.baseWholesalePrice;
  int get _baseWholesaleMinQty => state.baseWholesaleMinQty;
  double get _effectivePrice => state.effectivePrice;
  int get _effectiveStock => state.effectiveStock;
  bool get _isActive => state.isActive;
  double get _cost => state.effectiveCost;
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

  void _showQrCode() {
    InventoryQrSheet.show(
      context,
      productId: product.id,
      variantId:
          _selectedVariant?.id ??
          (product.productVariants.isNotEmpty
              ? product.productVariants.first.id
              : ''),
      productName: product.name,
      variantName: _selectedVariant?.label,
      sku: _selectedVariant?.sku ?? product.defaultVariant?.sku,
    );
  }

  void _showVariantPickerModal() {
    if (_variants.isEmpty) return;

    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      showDialog<void>(
        context: context,
        builder:
            (dialogCtx) => Dialog(
              backgroundColor:
                  isDark ? AppColors.darkSurfaceElevated : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 580,
                  maxHeight: 650,
                ),
                child: _buildVariantPickerContent(dialogCtx),
              ),
            ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (sheetCtx) => Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: _buildVariantPickerContent(sheetCtx),
            ),
      );
    }
  }

  Widget _buildVariantPickerContent(BuildContext modalContext) {
    final isDark = Theme.of(modalContext).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Catálogo de Variantes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF94A3B8) : null,
                ),
                onPressed: () => Navigator.pop(modalContext),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? AppColors.darkBorder : AppColors.divider,
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: _variants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final v = _variants[index];
              final isSelected = v.id == _selectedVariantId;
              final imgUrl = _variantImageUrl(v) ?? product.primaryImageUrl;

              return InkWell(
                onTap: () {
                  cubit.setVariant(v.id);
                  cubit.selectVariantImage(v.id);
                  Navigator.pop(modalContext);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primary.withValues(
                              alpha: isDark ? 0.2 : 0.06,
                            )
                            : (isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.surface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border),
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
                                color:
                                    isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.textPrimary,
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
                            'S/ ${(v.salePrice ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (v.wholesalePrice != null)
                            Text(
                              'Mayoreo: S/ ${v.wholesalePrice!.toStringAsFixed(2)}',
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
    );
  }

  void _showAddReviewDialog() {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isSubmitting = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (ctx, setS) => Dialog(
                  backgroundColor:
                      isDark ? AppColors.darkSurfaceElevated : Colors.white,
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
                            color:
                                isDark
                                    ? AppColors.amber.withValues(alpha: 0.15)
                                    : AppColors.amberLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: AppColors.amber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Registrar Opinión de Cliente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.textPrimary,
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, _) {
        final content = _buildShortcutsWrapper(context);
        if (widget.isEmbedded) {
          return Scaffold(backgroundColor: AppColors.background, body: content);
        }

        final isDesktop = MediaQuery.of(context).size.width >= 1024;

        return AdminLayout(
          title: product.name,
          showBackButton: true,
          showProfileButton: false,
          actions:
              isDesktop ? _buildHeaderActions(context, isDesktop: true) : null,
          bottomNavigationBar:
              !isDesktop ? _buildMobileStickyActionBar(context) : null,
          body: content,
        );
      },
    );
  }

  List<Widget> _buildHeaderActions(
    BuildContext context, {
    required bool isDesktop,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDesktop) {
      return [
        Tooltip(
          message: 'Exportar Ficha Técnica en PDF (P o Alt + P)',
          waitDuration: const Duration(milliseconds: 250),
          child: OutlinedButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            label: Text(
              'Exportar PDF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Editar datos del producto (E o Alt + E)',
          waitDuration: const Duration(milliseconds: 250),
          child: ElevatedButton.icon(
            onPressed: () {
              context.push('/products/product-form/${product.id}');
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text(
              'Editar Producto',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Exportar PDF',
        icon: const Icon(
          Icons.picture_as_pdf_outlined,
          color: AppColors.primary,
          size: 20,
        ),
        onPressed: _exportPdf,
      ),
      IconButton(
        tooltip: 'Editar Producto',
        icon: const Icon(
          Icons.edit_outlined,
          color: AppColors.primary,
          size: 20,
        ),
        onPressed: () {
          context.push('/products/product-form/${product.id}');
        },
      ),
    ];
  }

  Widget _buildMobileStickyActionBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 6
                : 14,
          ),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : Colors.white).withValues(
              alpha: 0.94,
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
            boxShadow:
                isDark
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text(
                      'Ficha PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark
                              ? const Color(0xFFF8FAFC)
                              : AppColors.textPrimary,
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor:
                          isDark ? AppColors.darkSurface : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/products/product-form/${product.id}');
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Editar Producto',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildShortcutsWrapper(BuildContext context) {
    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Regla estricta de aislamiento de foco:
        if (FocusUtils.isInputFieldFocused()) {
          return KeyEventResult.ignored;
        }

        final isAlt = HardwareKeyboard.instance.isAltPressed;
        final isControl = HardwareKeyboard.instance.isControlPressed;

        // E o Alt+E -> Editar
        if (event.logicalKey == LogicalKeyboardKey.keyE ||
            ((isAlt || isControl) &&
                event.logicalKey == LogicalKeyboardKey.keyE)) {
          context.push('/products/product-form/${product.id}');
          return KeyEventResult.handled;
        }

        // P o Alt+P -> Exportar PDF
        if (event.logicalKey == LogicalKeyboardKey.keyP ||
            ((isAlt || isControl) &&
                event.logicalKey == LogicalKeyboardKey.keyP)) {
          _exportPdf();
          return KeyEventResult.handled;
        }

        // V o Alt+V -> Abrir selector de variantes
        if (event.logicalKey == LogicalKeyboardKey.keyV ||
            ((isAlt || isControl) &&
                event.logicalKey == LogicalKeyboardKey.keyV)) {
          _showVariantPickerModal();
          return KeyEventResult.handled;
        }

        // Esc -> Salir / Volver
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/products');
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 960) {
            return _buildDesktopLayout(context);
          } else if (constraints.maxWidth >= 640) {
            return _buildTabletLayout(context);
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // ── Banda Financiera Compacta (Reemplazo moderno del Bento Grid) ───────────
  Widget _buildFinancialStrip({required bool isCompact}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retailProfit =
        _effectivePrice > _cost ? _effectivePrice - _cost : 0.0;
    final retailMargin =
        _effectivePrice > 0 ? (retailProfit / _effectivePrice) * 100 : 0.0;
    final reorderPoint =
        _selectedVariant?.reorderPoint ??
        product.defaultVariant?.reorderPoint ??
        0;
    final isLowStock = reorderPoint > 0 && _effectiveStock <= reorderPoint;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
          boxShadow:
              isDark
                  ? []
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'PRECIO VENTA',
                    value: 'S/ ${_effectivePrice.toStringAsFixed(2)}',
                    subValue:
                        _baseWholesalePrice != null
                            ? 'Mayorista: S/ ${_baseWholesalePrice!.toStringAsFixed(2)}'
                            : null,
                    valueColor: AppColors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: (isDark ? AppColors.darkBorder : AppColors.border)
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricItem(
                    label: 'STOCK TOTAL',
                    value: '$_effectiveStock uds',
                    subValue:
                        isLowStock ? 'Bajo punto de reorden' : 'Stock óptimo',
                    valueColor:
                        isLowStock ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            Divider(
              height: 18,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'COSTO ERP',
                    value:
                        _cost > 0
                            ? 'S/ ${_cost.toStringAsFixed(2)}'
                            : 'S/ 0.00',
                    subValue:
                        '${retailMargin.toStringAsFixed(1)}% margen bruto',
                    valueColor:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.textPrimary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: (isDark ? AppColors.darkBorder : AppColors.border)
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricItem(
                    label: 'VALOR INVENTARIO',
                    value: 'S/ ${(_effectiveStock * _cost).toStringAsFixed(2)}',
                    subValue:
                        reorderPoint > 0
                            ? 'Mínimo: $reorderPoint u.'
                            : 'Sin reorden',
                    valueColor:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildMetricItem(
              label: 'PRECIO DE VENTA',
              value: 'S/ ${_effectivePrice.toStringAsFixed(2)}',
              subValue:
                  _baseWholesalePrice != null
                      ? 'Mayorista: S/ ${_baseWholesalePrice!.toStringAsFixed(2)} (Min ${_baseWholesaleMinQty}u)'
                      : null,
              valueColor: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: _buildMetricItem(
              label: 'COSTO & RENTABILIDAD',
              value: _cost > 0 ? 'S/ ${_cost.toStringAsFixed(2)}' : 'S/ 0.00',
              subValue:
                  '${retailMargin.toStringAsFixed(1)}% margen bruto (S/ ${retailProfit.toStringAsFixed(2)})',
              valueColor:
                  isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              badgeColor:
                  retailMargin > 20 ? AppColors.success : AppColors.warning,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: _buildMetricItem(
              label: 'STOCK TOTAL DISPONIBLE',
              value: '$_effectiveStock unidades',
              subValue:
                  isLowStock
                      ? 'Alerta: Bajo punto de reorden'
                      : 'Existencias saludables',
              valueColor: isLowStock ? AppColors.error : AppColors.success,
              isPill: true,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 2,
            child: _buildMetricItem(
              label: 'VALORIZACIÓN TOTAL',
              value: 'S/ ${(_effectiveStock * _cost).toStringAsFixed(2)}',
              subValue:
                  reorderPoint > 0 ? 'Mínimo: $reorderPoint u.' : 'Sin reorden',
              valueColor:
                  isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    String? subValue,
    required Color valueColor,
    Color? badgeColor,
    bool isPill = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: valueColor,
              ),
            ),
            if (badgeColor != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color:
                  isPill && valueColor == AppColors.error
                      ? AppColors.error
                      : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. DESKTOP LAYOUT (POWER USER / LINEAR & STRIPE STYLE)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Header con botones de acción y QR
          ProductDetailHeader(
            product: product,
            isActive: _isActive,
            effectiveStock: _effectiveStock,
            sku: _selectedVariant?.sku ?? product.defaultVariant?.sku,
            onExportPdf: _exportPdf,
            onShowQr: _showQrCode,
            isMobile: false,
            showActions: true,
            variantCount: _variants.length,
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banda Métrica Financiera Unificada
                    _buildFinancialStrip(isCompact: false),
                    const SizedBox(height: 20),

                    // Dos Columnas Principales (40% / 60%)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda: Galería y Ficha Técnica
                        Expanded(
                          flex: 40,
                          child: Column(
                            children: [
                              Card(
                                elevation: 0,
                                color:
                                    isDark
                                        ? AppColors.darkSurface
                                        : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color:
                                        isDark
                                            ? AppColors.darkBorder
                                            : AppColors.border,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    height: 440,
                                    child: ProductGallerySection(
                                      images: gallery.toList(),
                                      pageController: _pageController,
                                      selectedIndex: _selectedImageIndex,
                                      onPageChanged: _onGalleryChanged,
                                      variantImageOverrideUrl:
                                          (_showVariantImage &&
                                                  _selectedVariant != null)
                                              ? _selectedVariantImageUrl
                                              : null,
                                      variantLabelOverride:
                                          (_showVariantImage &&
                                                  _selectedVariant != null)
                                              ? _selectedVariant!
                                                  .attributeMap
                                                  .values
                                                  .join(' - ')
                                              : null,
                                      fallbackImageUrl: product.primaryImageUrl,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ProductDetailsCard(details: mergedDetails),
                              if (_activeIngredients.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ProductIngredientsCard(
                                  ingredients: _activeIngredients,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 22),

                        // Columna Derecha: Tabs sin duplicados
                        Expanded(
                          flex: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDesktopTabs(),
                              const SizedBox(height: 16),
                              _buildDesktopTabContent(mergedDetails),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      (0, 'Variantes (${_variants.length})', Icons.style_outlined),
      (1, 'Almacenes y Lotes', Icons.warehouse_outlined),
      (2, 'Rentabilidad ERP', Icons.analytics_outlined),
      (3, 'Descripción y Reseñas', Icons.reviews_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children:
            tabs.map((t) {
              final isSelected = _desktopSelectedTab == t.$1;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _desktopSelectedTab = t.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.$3,
                          size: 15,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDesktopTabContent(Map<String, dynamic> mergedDetails) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<int>(_desktopSelectedTab),
        child: _buildDesktopSelectedTabBody(mergedDetails),
      ),
    );
  }

  Widget _buildDesktopSelectedTabBody(Map<String, dynamic> mergedDetails) {
    switch (_desktopSelectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductVariantMatrix(
              variants: _variants,
              selectedVariantId: _selectedVariantId,
              fallbackImageUrl: product.primaryImageUrl,
              variantImageUrl: _variantImageUrl,
              onVariantSelected: (v) {
                cubit.setVariant(v.id);
                cubit.selectVariantImage(v.id);
              },
              onOpenSelectorModal: _showVariantPickerModal,
              isDesktop: true,
              variantStock: (id) => state.variantStock(id),
            ),
            const SizedBox(height: 16),
            const ProductQuickDecisionsCard(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductAvailabilityCard(),
            if (product.usesBatches) ...[
              const SizedBox(height: 16),
              const ProductBatchesCard(initiallyExpanded: true),
            ],
          ],
        );
      case 2:
        return const ProductAdminInfoCard(initiallyExpanded: true);
      case 3:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductDescriptionCard(description: product.description ?? ''),
            const SizedBox(height: 16),
            ProductReviewsCard(
              averageRating: _averageRating,
              totalReviews: _reviewsList.length,
              reviews: _reviewsList,
              onAddReview: _showAddReviewDialog,
            ),
          ],
        );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. TABLET LAYOUT (EFICIENCIA HÍBRIDA)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildTabletLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ProductDetailHeader(
            product: product,
            isActive: _isActive,
            effectiveStock: _effectiveStock,
            sku: _selectedVariant?.sku ?? product.defaultVariant?.sku,
            onExportPdf: _exportPdf,
            onShowQr: _showQrCode,
            isMobile: false,
            showActions: true,
            variantCount: _variants.length,
          ),
          const SizedBox(height: 16),
          _buildFinancialStrip(isCompact: true),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Izquierdo
              Expanded(
                flex: 45,
                child: Column(
                  children: [
                    Card(
                      elevation: 0,
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color:
                              isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: 380,
                          child: ProductGallerySection(
                            images: gallery.toList(),
                            pageController: _pageController,
                            selectedIndex: _selectedImageIndex,
                            onPageChanged: _onGalleryChanged,
                            variantImageOverrideUrl:
                                (_showVariantImage && _selectedVariant != null)
                                    ? _selectedVariantImageUrl
                                    : null,
                            fallbackImageUrl: product.primaryImageUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ProductDetailsCard(details: mergedDetails),
                    if (_activeIngredients.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ProductIngredientsCard(ingredients: _activeIngredients),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Panel Derecho
              Expanded(
                flex: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopTabs(),
                    const SizedBox(height: 14),
                    _buildDesktopTabContent(mergedDetails),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 3. MÓVIL LAYOUT (APPLE HIG / PÍLDORAS SEGMENTADAS / CERO CARD FATIGUE)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    final mobileTabs = [
      (0, 'Resumen', Icons.dashboard_outlined),
      (1, 'Variantes (${_variants.length})', Icons.style_outlined),
      (2, 'Stock & Lotes', Icons.warehouse_outlined),
      (3, 'Ficha Técnica', Icons.description_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Galería Móvil Compacta
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 280,
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: ProductGallerySection(
                images: gallery.toList(),
                pageController: _pageController,
                selectedIndex: _selectedImageIndex,
                onPageChanged: _onGalleryChanged,
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
          const SizedBox(height: 14),

          // Título, SKU, Rating, Estado
          ProductTopSection(
            name: product.name,
            sku: _selectedVariant?.sku,
            brandName: product.brandName,
            isActive: _isActive,
            effectiveStock: _effectiveStock,
            averageRating: _averageRating,
            totalReviews: _reviewsList.length,
          ),
          const SizedBox(height: 14),

          // Píldoras Segmented Control (Apple HIG)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  mobileTabs.map((t) {
                    final isSelected = _mobileSelectedTab == t.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          t.$3,
                          size: 15,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                        ),
                        label: Text(
                          t.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color:
                                isSelected
                                    ? Colors.white
                                    : isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor:
                            isDark ? AppColors.darkSurface : Colors.white,
                        side: BorderSide(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected:
                            (_) => setState(() => _mobileSelectedTab = t.$1),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Contenido modular dinámico según pestaña
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<int>(_mobileSelectedTab),
              child: _buildMobileTabContent(mergedDetails),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabContent(Map<String, dynamic> mergedDetails) {
    switch (_mobileSelectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialStrip(isCompact: true),
            const SizedBox(height: 14),
            const ProductAvailabilityCard(),
            const SizedBox(height: 14),
            ProductDescriptionCard(description: product.description ?? ''),
            const SizedBox(height: 14),
            const ProductQuickDecisionsCard(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductVariantMatrix(
              variants: _variants,
              selectedVariantId: _selectedVariantId,
              fallbackImageUrl: product.primaryImageUrl,
              variantImageUrl: _variantImageUrl,
              onVariantSelected: (v) {
                cubit.setVariant(v.id);
                cubit.selectVariantImage(v.id);
              },
              onOpenSelectorModal: _showVariantPickerModal,
              isDesktop: false,
              variantStock: (id) => state.variantStock(id),
            ),
            const SizedBox(height: 14),
            const ProductQuickDecisionsCard(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductAvailabilityCard(),
            if (product.usesBatches) ...[
              const SizedBox(height: 14),
              const ProductBatchesCard(initiallyExpanded: true),
            ],
            const SizedBox(height: 14),
            const ProductAdminInfoCard(initiallyExpanded: true),
          ],
        );
      case 3:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductDetailsCard(details: mergedDetails),
            if (_activeIngredients.isNotEmpty) ...[
              const SizedBox(height: 14),
              ProductIngredientsCard(ingredients: _activeIngredients),
            ],
            const SizedBox(height: 14),
            ProductReviewsCard(
              averageRating: _averageRating,
              totalReviews: _reviewsList.length,
              reviews: _reviewsList,
              onAddReview: _showAddReviewDialog,
            ),
          ],
        );
    }
  }
}
