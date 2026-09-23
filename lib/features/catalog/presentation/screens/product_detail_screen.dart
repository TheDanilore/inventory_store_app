import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_admin_info_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_availability_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_batches_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_description_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_detail_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_financial_bento_grid.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_input_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_top_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_variant_matrix.dart';

// Keyboard Shortcut Intents
class _ExportPdfIntent extends Intent {
  const _ExportPdfIntent();
}

class _EditProductIntent extends Intent {
  const _EditProductIntent();
}

class _SelectVariantIntent extends Intent {
  const _SelectVariantIntent();
}

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
  int _desktopSelectedTab = 0;

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

  int get _selectedImageIndex => state.selectedImageIndex;
  String? get _selectedVariantId => state.selectedVariantId;

  ProductVariantEntity? get _selectedVariant => state.selectedVariant;
  double get _baseSalePrice => state.baseSalePrice;
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

  void _showVariantPickerModal() {
    if (_variants.isEmpty) return;

    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      showDialog<void>(
        context: context,
        builder:
            (dialogCtx) => Dialog(
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
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (sheetCtx) => Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _buildVariantPickerContent(sheetCtx),
            ),
      );
    }
  }

  Widget _buildVariantPickerContent(BuildContext modalContext) {
    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Catálogo de Variantes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(modalContext),
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
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : AppColors.border,
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, _) {
        final content = _buildShortcutsWrapper(context);
        if (widget.isEmbedded) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: content,
          );
        }

        final isDesktop = MediaQuery.of(context).size.width >= 1024;

        return AdminLayout(
          title: product.name,
          breadcrumb: 'Catálogo > Productos > ${product.name}',
          showBackButton: true,
          showProfileButton: false,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
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
    if (isDesktop) {
      return [
        OutlinedButton.icon(
          onPressed: _exportPdf,
          icon: const Icon(
            Icons.picture_as_pdf_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Exportar PDF',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _buildKbdBadge('Alt + P'),
            ],
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            context.push('/products/product-form/${product.id}');
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Editar Producto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildKbdBadge('Alt + E', isDark: true),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        tooltip: 'Editar',
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

  Widget _buildKbdBadge(String text, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.18)
                : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMobileStickyActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 6
            : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text(
                'Ficha PDF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/products/product-form/${product.id}');
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Editar Producto',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsWrapper(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyP,
        ): const _ExportPdfIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyE,
        ): const _EditProductIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyV,
        ): const _SelectVariantIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ExportPdfIntent: CallbackAction<_ExportPdfIntent>(
            onInvoke: (_) => _exportPdf(),
          ),
          _EditProductIntent: CallbackAction<_EditProductIntent>(
            onInvoke:
                (_) => context.push('/products/product-form/${product.id}'),
          ),
          _SelectVariantIntent: CallbackAction<_SelectVariantIntent>(
            onInvoke: (_) => _showVariantPickerModal(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _buildDesktopLayout(context);
              } else if (constraints.maxWidth >= 580) {
                return _buildTabletLayout(context);
              }
              return _buildMobileLayout(context);
            },
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. DESKTOP LAYOUT (POWER USER / LINEAR & STRIPE STYLE)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(BuildContext context) {
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    final int reorderPoint =
        _selectedVariant?.reorderPoint ??
        product.defaultVariant?.reorderPoint ??
        0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HERO HEADER DE PRODUCTO (Sin redundancias de TopBar)
          ProductDetailHeader(
            product: product,
            isActive: _isActive,
            effectiveStock: _effectiveStock,
            sku: _selectedVariant?.sku ?? product.defaultVariant?.sku,
            onExportPdf: _exportPdf,
            isMobile: false,
            showActions: false,
            variantCount: _variants.length,
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BENTO GRID FINANCIERO (ABOVE-THE-FOLD)
                    ProductFinancialBentoGrid(
                      effectivePrice: _effectivePrice,
                      baseSalePrice: _baseSalePrice,
                      baseWholesalePrice: _baseWholesalePrice,
                      baseWholesaleMinQty: _baseWholesaleMinQty,
                      cost: _cost,
                      effectiveStock: _effectiveStock,
                      reorderPoint: reorderPoint,
                      isCompact: false,
                    ),
                    const SizedBox(height: 20),

                    // DOS COLUMNAS PRINCIPALES (40% / 60%)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Columna Izquierda: Galería y Almacenes (40%) ──
                        Expanded(
                          flex: 40,
                          child: Column(
                            children: [
                              Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    height: 480,
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
                                      fallbackImageUrl:
                                          product.primaryImageUrl,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Almacenes
                              const ProductAvailabilityCard(),
                              const SizedBox(height: 16),

                              // Lotes
                              if (product.usesBatches) ...[
                                const ProductBatchesCard(
                                  initiallyExpanded: true,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Detalles de ficha técnica
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
                        const SizedBox(width: 20),

                        // ── Columna Derecha: Tabs y Secciones (60%) ─
                        Expanded(
                          flex: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pestañas segmentadas para evitar scroll desmedido
                              _buildDesktopTabs(),
                              const SizedBox(height: 16),

                              // Contenido según pestaña activa
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
    final tabs = [
      (0, 'Variantes (${_variants.length})', Icons.style_outlined),
      (1, 'Rentabilidad ERP', Icons.analytics_outlined),
      (2, 'Decisiones Rápidas', Icons.bolt_outlined),
      (3, 'Reseñas (${_reviewsList.length})', Icons.star_outline_rounded),
      (4, 'Vista Completa', Icons.view_agenda_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
                      vertical: 8,
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
                                  : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w600,
                              color:
                                  isSelected
                                      ? Colors.white
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
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      transitionBuilder:
          (child, animation) => FadeTransition(opacity: animation, child: child),
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
        return const ProductAdminInfoCard(initiallyExpanded: true);
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductQuickDecisionsCard(),
            if (product.usesBatches) ...[
              const SizedBox(height: 16),
              const ProductBatchesCard(initiallyExpanded: true),
            ],
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        );
      case 4:
      default:
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
            const ProductAdminInfoCard(initiallyExpanded: true),
            const SizedBox(height: 16),
            const ProductQuickDecisionsCard(),
            const SizedBox(height: 16),
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
        );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. TABLET LAYOUT (EFICIENCIA HÍBRIDA)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildTabletLayout(BuildContext context) {
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    final int reorderPoint =
        _selectedVariant?.reorderPoint ??
        product.defaultVariant?.reorderPoint ??
        0;

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
            isMobile: false,
            showActions: false,
            variantCount: _variants.length,
          ),
          const SizedBox(height: 16),
          // Bento Grid en formato 2x2
          ProductFinancialBentoGrid(
            effectivePrice: _effectivePrice,
            baseSalePrice: _baseSalePrice,
            baseWholesalePrice: _baseWholesalePrice,
            baseWholesaleMinQty: _baseWholesaleMinQty,
            cost: _cost,
            effectiveStock: _effectiveStock,
            reorderPoint: reorderPoint,
            isCompact: true,
          ),
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
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppColors.radius,
                        ),
                        side: const BorderSide(color: AppColors.border),
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
                                (_showVariantImage &&
                                        _selectedVariant != null)
                                    ? _selectedVariantImageUrl
                                    : null,
                            fallbackImageUrl: product.primaryImageUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    const ProductAvailabilityCard(),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Panel Derecho
              Expanded(
                flex: 55,
                child: Column(
                  children: [
                    if (product.usesBatches) ...[
                      const ProductBatchesCard(initiallyExpanded: true),
                      const SizedBox(height: 14),
                    ],
                    const ProductAdminInfoCard(initiallyExpanded: true),
                    const SizedBox(height: 14),
                    const ProductQuickDecisionsCard(),
                    const SizedBox(height: 14),
                    ProductDetailsCard(details: mergedDetails),
                    const SizedBox(height: 14),
                    ProductReviewsCard(
                      averageRating: _averageRating,
                      totalReviews: _reviewsList.length,
                      reviews: _reviewsList,
                      onAddReview: _showAddReviewDialog,
                    ),
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
  // 3. MÓVIL LAYOUT (APPLE HIG / FLUJO TÁCTIL SUAVE)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(BuildContext context) {
    final gallery = _galleryImages;
    final Map<String, dynamic> mergedDetails = Map.from(product.details);
    if (product.brandName != null && product.brandName!.isNotEmpty) {
      mergedDetails['Marca'] = product.brandName!;
    }
    mergedDetails['Control de Stock'] = product.stockControl ? 'Sí' : 'No';
    mergedDetails['Usa Lotes'] = product.usesBatches ? 'Sí' : 'No';
    mergedDetails['Tipo de Producto'] = _fmt(product.productType);

    final int reorderPoint =
        _selectedVariant?.reorderPoint ??
        product.defaultVariant?.reorderPoint ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Galería Móvil
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radius),
            child: Container(
              height: 320,
              color: Colors.white,
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
          const SizedBox(height: 16),

          // Top Section
          ProductTopSection(
            name: product.name,
            sku: _selectedVariant?.sku,
            brandName: product.brandName,
            isActive: _isActive,
            effectiveStock: _effectiveStock,
            averageRating: _averageRating,
            totalReviews: _reviewsList.length,
          ),
          const SizedBox(height: 16),

          // Bento Grid 2x2
          ProductFinancialBentoGrid(
            effectivePrice: _effectivePrice,
            baseSalePrice: _baseSalePrice,
            baseWholesalePrice: _baseWholesalePrice,
            baseWholesaleMinQty: _baseWholesaleMinQty,
            cost: _cost,
            effectiveStock: _effectiveStock,
            reorderPoint: reorderPoint,
            isCompact: true,
          ),
          const SizedBox(height: 16),

          // Variantes Chips
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
          const SizedBox(height: 16),

          // Almacén
          const ProductAvailabilityCard(),
          const SizedBox(height: 16),

          // Lotes
          if (product.usesBatches) ...[
            const ProductBatchesCard(initiallyExpanded: false),
            const SizedBox(height: 16),
          ],

          // Rentabilidad
          const ProductAdminInfoCard(initiallyExpanded: false),
          const SizedBox(height: 16),

          // Decisiones
          const ProductQuickDecisionsCard(),
          const SizedBox(height: 16),

          // Detalles
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
        ],
      ),
    );
  }
}
