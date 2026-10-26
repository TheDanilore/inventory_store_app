import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/layouts/product_detail_desktop_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/layouts/product_detail_mobile_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/layouts/product_detail_tablet_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_add_review_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_export_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_variant_picker_modal.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_qr_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

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

  ProductDetailCubit get cubit => context.read<ProductDetailCubit>();
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

  String get _currencySymbol {
    try {
      return context.read<AppConfigCubit>().state.baseCurrency.symbol;
    } catch (_) {
      return 'S/';
    }
  }

  Future<void> _exportPdf() async {
    final state = cubit.state;
    final currentProduct = state.product ?? product;
    final stockByVariant = <String, int>{};
    for (final row in state.warehouseStocks) {
      final vId = row['variant_id'] as String?;
      final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
      if (vId != null) {
        stockByVariant[vId] = (stockByVariant[vId] ?? 0) + qty;
      }
    }
    await ProductExportSheet.show(
      context,
      product: currentProduct,
      variants:
          state.variants.isNotEmpty
              ? state.variants
              : currentProduct.productVariants,
      stockByVariant: stockByVariant,
    );
  }

  void _showQrCode() {
    final state = cubit.state;
    final selectedVariant = state.selectedVariant;
    InventoryQrSheet.show(
      context,
      productId: product.id,
      variantId:
          selectedVariant?.id ??
          (product.productVariants.isNotEmpty
              ? product.productVariants.first.id
              : ''),
      productName: product.name,
      variantName: selectedVariant?.label,
      sku: selectedVariant?.sku ?? product.defaultVariant?.sku,
      barcode: selectedVariant?.barcode ?? product.defaultVariant?.barcode,
    );
  }

  void _showVariantPickerModal() {
    final state = cubit.state;
    ProductVariantPickerModal.show(
      context,
      variants: state.variants,
      selectedVariantId: state.selectedVariantId,
      fallbackImageUrl: product.primaryImageUrl ?? '',
      currencySymbol: _currencySymbol,
      variantImageUrl: (v) => state.variantImageUrl(v),
      onVariantSelected: (v) {
        cubit.setVariant(v.id);
        cubit.selectVariantImage(v.id);
      },
    );
  }

  void _showAddReviewDialog() {
    ProductAddReviewDialog.show(context, cubit);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildShortcutsWrapper(context);
    if (widget.isEmbedded) {
      return Scaffold(backgroundColor: AppColors.background, body: content);
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return AdminLayout(
      title: product.name,
      showBackButton: true,
      showProfileButton: false,
      actions: isDesktop ? _buildHeaderActions(context, isDesktop: true) : null,
      bottomNavigationBar:
          !isDesktop ? _buildMobileStickyActionBar(context) : null,
      body: content,
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
            return ProductDetailDesktopLayout(
              product: product,
              pageController: _pageController,
              onExportPdf: _exportPdf,
              onShowQr: _showQrCode,
              onOpenVariantPicker: _showVariantPickerModal,
              onAddReview: _showAddReviewDialog,
            );
          } else if (constraints.maxWidth >= 640) {
            return ProductDetailTabletLayout(
              product: product,
              pageController: _pageController,
              onExportPdf: _exportPdf,
              onShowQr: _showQrCode,
              onOpenVariantPicker: _showVariantPickerModal,
              onAddReview: _showAddReviewDialog,
            );
          }
          return ProductDetailMobileLayout(
            product: product,
            pageController: _pageController,
            onOpenVariantPicker: _showVariantPickerModal,
            onAddReview: _showAddReviewDialog,
          );
        },
      ),
    );
  }
}
