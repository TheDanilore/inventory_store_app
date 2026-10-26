import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_admin_info_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_availability_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_batches_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_description_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_detail_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_financial_strip.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_variant_matrix.dart';

/// Layout optimizado para pantallas de escritorio (Linear/Stripe style).
class ProductDetailDesktopLayout extends StatefulWidget {
  final ProductEntity product;
  final PageController pageController;
  final VoidCallback onExportPdf;
  final VoidCallback onShowQr;
  final VoidCallback onOpenVariantPicker;
  final VoidCallback onAddReview;

  const ProductDetailDesktopLayout({
    super.key,
    required this.product,
    required this.pageController,
    required this.onExportPdf,
    required this.onShowQr,
    required this.onOpenVariantPicker,
    required this.onAddReview,
  });

  @override
  State<ProductDetailDesktopLayout> createState() =>
      _ProductDetailDesktopLayoutState();
}

class _ProductDetailDesktopLayoutState
    extends State<ProductDetailDesktopLayout> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<ProductDetailCubit>();
    final state = context.watch<ProductDetailCubit>().state;
    final product = widget.product;
    final gallery = state.images;
    final mergedDetails = state.mergedDetails;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Header con botones de acción y QR
          ProductDetailHeader(
            product: product,
            isActive: state.isActive,
            effectiveStock: state.effectiveStock,
            sku: state.selectedVariant?.sku ?? product.defaultVariant?.sku,
            barcode:
                state.selectedVariant?.barcode ??
                product.defaultVariant?.barcode,
            onExportPdf: widget.onExportPdf,
            onShowQr: widget.onShowQr,
            isMobile: false,
            showActions: true,
            variantCount: state.variants.length,
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
                    const ProductFinancialStrip(isCompact: false),
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
                                      pageController: widget.pageController,
                                      selectedIndex: state.selectedImageIndex,
                                      onPageChanged: cubit.setImageIndex,
                                      variantImageOverrideUrl:
                                          (state.showVariantImage &&
                                                  state.selectedVariant != null)
                                              ? state.selectedVariantImageUrl
                                              : null,
                                      variantLabelOverride:
                                          (state.showVariantImage &&
                                                  state.selectedVariant != null)
                                              ? state
                                                  .selectedVariant!
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
                              if (state.activeIngredients.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ProductIngredientsCard(
                                  ingredients: state.activeIngredients,
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
                              _buildTabs(isDark, state.variants.length),
                              const SizedBox(height: 16),
                              _buildTabContent(
                                state,
                                cubit,
                                product,
                                mergedDetails,
                              ),
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

  Widget _buildTabs(bool isDark, int variantCount) {
    final tabs = [
      (0, 'Variantes ($variantCount)', Icons.style_outlined),
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
              final isSelected = _selectedTab == t.$1;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = t.$1),
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

  Widget _buildTabContent(
    ProductDetailState state,
    ProductDetailCubit cubit,
    ProductEntity product,
    Map<String, dynamic> mergedDetails,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedTab),
        child: _buildSelectedTabBody(state, cubit, product, mergedDetails),
      ),
    );
  }

  Widget _buildSelectedTabBody(
    ProductDetailState state,
    ProductDetailCubit cubit,
    ProductEntity product,
    Map<String, dynamic> mergedDetails,
  ) {
    switch (_selectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductVariantMatrix(
              variants: state.variants,
              selectedVariantId: state.selectedVariantId,
              fallbackImageUrl: product.primaryImageUrl,
              variantImageUrl: (v) => state.variantImageUrl(v),
              onVariantSelected: (v) {
                cubit.setVariant(v.id);
                cubit.selectVariantImage(v.id);
              },
              onOpenSelectorModal: widget.onOpenVariantPicker,
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
              averageRating: state.averageRating,
              totalReviews: state.reviewsList.length,
              reviews: state.reviewsList,
              onAddReview: widget.onAddReview,
            ),
          ],
        );
    }
  }
}
