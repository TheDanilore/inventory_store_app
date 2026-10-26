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
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_details_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_financial_strip.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_gallery_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_ingredients_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_quick_decisions_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_reviews_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_top_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_variant_matrix.dart';

/// Layout móvil optimizado (Apple HIG con píldoras segmentadas y scroll natural).
class ProductDetailMobileLayout extends StatefulWidget {
  final ProductEntity product;
  final PageController pageController;
  final VoidCallback onOpenVariantPicker;
  final VoidCallback onAddReview;

  const ProductDetailMobileLayout({
    super.key,
    required this.product,
    required this.pageController,
    required this.onOpenVariantPicker,
    required this.onAddReview,
  });

  @override
  State<ProductDetailMobileLayout> createState() =>
      _ProductDetailMobileLayoutState();
}

class _ProductDetailMobileLayoutState extends State<ProductDetailMobileLayout> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<ProductDetailCubit>();
    final state = context.watch<ProductDetailCubit>().state;
    final product = widget.product;
    final gallery = state.images;
    final mergedDetails = state.mergedDetails;

    final mobileTabs = [
      (0, 'Resumen', Icons.dashboard_outlined),
      (1, 'Variantes (${state.variants.length})', Icons.style_outlined),
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
                pageController: widget.pageController,
                selectedIndex: state.selectedImageIndex,
                onPageChanged: cubit.setImageIndex,
                variantImageOverrideUrl:
                    (state.showVariantImage && state.selectedVariant != null)
                        ? state.selectedVariantImageUrl
                        : null,
                variantLabelOverride:
                    (state.showVariantImage && state.selectedVariant != null)
                        ? state.selectedVariant!.attributeMap.values.join(' - ')
                        : null,
                fallbackImageUrl: product.primaryImageUrl,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Título, SKU, Rating, Estado
          ProductTopSection(
            name: product.name,
            sku: state.selectedVariant?.sku ?? product.defaultVariant?.sku,
            barcode:
                state.selectedVariant?.barcode ??
                product.defaultVariant?.barcode,
            brandName: product.brandName,
            isActive: state.isActive,
            effectiveStock: state.effectiveStock,
            averageRating: state.averageRating,
            totalReviews: state.reviewsList.length,
          ),
          const SizedBox(height: 14),

          // Píldoras Segmented Control (Apple HIG)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  mobileTabs.map((t) {
                    final isSelected = _selectedTab == t.$1;
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
                        onSelected: (_) => setState(() => _selectedTab = t.$1),
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
              key: ValueKey<int>(_selectedTab),
              child: _buildTabBody(state, cubit, product, mergedDetails),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(
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
            const ProductFinancialStrip(isCompact: true),
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
              variants: state.variants,
              selectedVariantId: state.selectedVariantId,
              fallbackImageUrl: product.primaryImageUrl,
              variantImageUrl: (v) => state.variantImageUrl(v),
              onVariantSelected: (v) {
                cubit.setVariant(v.id);
                cubit.selectVariantImage(v.id);
              },
              onOpenSelectorModal: widget.onOpenVariantPicker,
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
            if (state.activeIngredients.isNotEmpty) ...[
              const SizedBox(height: 14),
              ProductIngredientsCard(ingredients: state.activeIngredients),
            ],
            const SizedBox(height: 14),
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
