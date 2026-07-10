import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_financial_summary_entity.dart';

class ProductDetailState extends Equatable {
  final ProductEntity? product;
  final ViewState viewState;
  final bool isWishlistLoading;
  final bool isWishlisted;
  final bool showVariantImage;

  final int selectedQty;
  final int selectedImageIndex;
  final String? selectedVariantId;
  final Map<String, String> selectedAttributes;

  final List<Map<String, dynamic>> warehouseStocks;
  final List<Map<String, dynamic>> batchesList;
  final List<ProductImageEntity> images;
  final List<ProductVariantEntity> variants;
  final List<Map<String, dynamic>> reviewsList;
  final List<Map<String, dynamic>> activeIngredients;

  // Admin Data
  final int totalSold;
  final double reinvestmentNeeded;
  final double inventoryValue;
  final double totalRevenue;
  final List<VariantFinancialSummaryEntity> variantSummaries;
  final double averageRating;

  const ProductDetailState({
    this.product,
    this.viewState = ViewState.initial,
    this.isWishlistLoading = true,
    this.isWishlisted = false,
    this.showVariantImage = false,
    this.selectedQty = 1,
    this.selectedImageIndex = 0,
    this.selectedVariantId,
    this.selectedAttributes = const {},
    this.warehouseStocks = const [],
    this.batchesList = const [],
    this.images = const [],
    this.variants = const [],
    this.reviewsList = const [],
    this.activeIngredients = const [],
    this.totalSold = 0,
    this.reinvestmentNeeded = 0.0,
    this.inventoryValue = 0.0,
    this.totalRevenue = 0.0,
    this.variantSummaries = const [],
    this.averageRating = 0.0,
  });

  ProductDetailState copyWith({
    ProductEntity? product,
    ViewState? viewState,
    bool? isWishlistLoading,
    bool? isWishlisted,
    bool? showVariantImage,
    int? selectedQty,
    int? selectedImageIndex,
    String? selectedVariantId,
    Map<String, String>? selectedAttributes,
    List<Map<String, dynamic>>? warehouseStocks,
    List<Map<String, dynamic>>? batchesList,
    List<ProductImageEntity>? images,
    List<ProductVariantEntity>? variants,
    List<Map<String, dynamic>>? reviewsList,
    List<Map<String, dynamic>>? activeIngredients,
    int? totalSold,
    double? reinvestmentNeeded,
    double? inventoryValue,
    double? totalRevenue,
    List<VariantFinancialSummaryEntity>? variantSummaries,
    double? averageRating,
  }) {
    return ProductDetailState(
      product: product ?? this.product,
      viewState: viewState ?? this.viewState,
      isWishlistLoading: isWishlistLoading ?? this.isWishlistLoading,
      isWishlisted: isWishlisted ?? this.isWishlisted,
      showVariantImage: showVariantImage ?? this.showVariantImage,
      selectedQty: selectedQty ?? this.selectedQty,
      selectedImageIndex: selectedImageIndex ?? this.selectedImageIndex,
      selectedVariantId: selectedVariantId ?? this.selectedVariantId,
      selectedAttributes: selectedAttributes ?? this.selectedAttributes,
      warehouseStocks: warehouseStocks ?? this.warehouseStocks,
      batchesList: batchesList ?? this.batchesList,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      reviewsList: reviewsList ?? this.reviewsList,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      totalSold: totalSold ?? this.totalSold,
      reinvestmentNeeded: reinvestmentNeeded ?? this.reinvestmentNeeded,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      variantSummaries: variantSummaries ?? this.variantSummaries,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  ProductVariantEntity? get selectedVariant {
    if (selectedVariantId != null && variants.isNotEmpty) {
      try {
        return variants.firstWhere((v) => v.id == selectedVariantId);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double get baseSalePrice {
    final vSale = selectedVariant?.salePrice;
    if (vSale != null && vSale > 0) return vSale;
    return product?.salePrice ?? 0.0;
  }

  double? get baseWholesalePrice {
    final vWholesale = selectedVariant?.wholesalePrice;
    if (vWholesale != null && vWholesale > 0) return vWholesale;
    return product?.wholesalePrice;
  }

  int get baseWholesaleMinQty =>
      selectedVariant?.wholesaleMinQuantity ??
      product?.wholesaleMinQuantity ??
      0;

  double get effectivePrice {
    final bwp = baseWholesalePrice;
    if (bwp != null && selectedQty >= baseWholesaleMinQty) {
      return bwp;
    }
    return baseSalePrice;
  }

  bool get isActive {
    if (product?.isActive != true) return false;
    final v = selectedVariant;
    if (v != null && !v.isActive) return false;
    return true;
  }

  int get effectiveStock {
    if (product?.stockControl != true) return 999;
    final v = selectedVariant;
    if (v == null) return 0;
    int s = 0;
    for (final row in warehouseStocks) {
      if (row['variant_id'] == v.id) {
        s += (row['available_quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return s;
  }

  bool get canBuy => isActive && effectiveStock > 0 && selectedVariant != null;

  String? variantImageUrl(ProductVariantEntity v) {
    if (v.images.isNotEmpty) {
      return v.images.first.imageUrl;
    }
    try {
      final match = images.firstWhere((img) => img.variantId == v.id);
      return match.imageUrl;
    } catch (_) {
      return null;
    }
  }

  String? get selectedVariantImageUrl {
    final v = selectedVariant;
    if (v == null) return null;
    return variantImageUrl(v);
  }

  List<String> get attributeKeys {
    final Set<String> keys = {};
    for (final v in variants) {
      for (final av in v.attributeValues) {
        keys.add(av.attributeName);
      }
    }
    final list = keys.toList();
    list.sort();
    return list;
  }

  Map<String, List<String>> get attributeOptions {
    final Map<String, Set<String>> map = {};
    for (final key in attributeKeys) {
      map[key] = {};
    }
    for (final v in variants) {
      for (final av in v.attributeValues) {
        map[av.attributeName]?.add(av.value);
      }
    }
    return map.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  bool isOptionEnabled(String key, String value) {
    for (final v in variants) {
      final avList = v.attributeValues;
      bool hasOption = avList.any(
        (av) => av.attributeName == key && av.value == value,
      );
      if (hasOption) {
        bool matchesOther = true;
        selectedAttributes.forEach((k, selectedVal) {
          if (k != key) {
            bool hasOtherOption = avList.any(
              (av) => av.attributeName == k && av.value == selectedVal,
            );
            if (!hasOtherOption) matchesOther = false;
          }
        });
        if (matchesOther) return true;
      }
    }
    return false;
  }

  @override
  List<Object?> get props => [
    product,
    viewState,
    isWishlistLoading,
    isWishlisted,
    showVariantImage,
    selectedQty,
    selectedImageIndex,
    selectedVariantId,
    selectedAttributes,
    warehouseStocks,
    batchesList,
    images,
    variants,
    reviewsList,
    activeIngredients,
    totalSold,
    reinvestmentNeeded,
    inventoryValue,
    totalRevenue,
    variantSummaries,
    averageRating,
  ];
}
