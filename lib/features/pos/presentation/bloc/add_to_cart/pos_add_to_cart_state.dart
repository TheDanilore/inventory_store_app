import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

abstract class PosAddToCartState extends Equatable {
  const PosAddToCartState();

  @override
  List<Object?> get props => [];
}

class PosAddToCartInitial extends PosAddToCartState {}

class PosAddToCartLoading extends PosAddToCartState {}

class PosAddToCartLoaded extends PosAddToCartState {
  final List<ProductVariantEntity> variants;
  final Map<String, int> stockByVariant;
  final ProductVariantEntity? selectedVariant;
  final int quantity;
  final ProductEntity productEntity;

  const PosAddToCartLoaded({
    required this.variants,
    required this.stockByVariant,
    this.selectedVariant,
    this.quantity = 1,
    required this.productEntity,
  });

  PosAddToCartLoaded copyWith({
    List<ProductVariantEntity>? variants,
    Map<String, int>? stockByVariant,
    ProductVariantEntity? selectedVariant,
    int? quantity,
    ProductEntity? productEntity,
  }) {
    return PosAddToCartLoaded(
      variants: variants ?? this.variants,
      stockByVariant: stockByVariant ?? this.stockByVariant,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      quantity: quantity ?? this.quantity,
      productEntity: productEntity ?? this.productEntity,
    );
  }

  bool get hasStockControl => productEntity.stockControl;

  int get currentStock {
    if (variants.isEmpty) return productEntity.totalStock;
    if (selectedVariant == null) return 0;
    return stockByVariant[selectedVariant!.id] ?? 0;
  }

  double get currentPrice {
    if (variants.isEmpty) return 0;
    return selectedVariant?.salePrice ?? 0;
  }

  bool get canSell =>
      selectedVariant != null &&
      (!hasStockControl || currentStock > 0) &&
      currentPrice > 0;

  @override
  List<Object?> get props => [
    variants,
    stockByVariant,
    selectedVariant,
    quantity,
    productEntity,
  ];
}

class PosAddToCartError extends PosAddToCartState {
  final String message;

  const PosAddToCartError(this.message);

  @override
  List<Object?> get props => [message];
}
