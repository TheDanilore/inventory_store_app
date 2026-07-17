import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

abstract class ProductDetailState extends Equatable {
  const ProductDetailState();

  @override
  List<Object?> get props => [];
}

class ProductDetailInitial extends ProductDetailState {}

class ProductDetailLoading extends ProductDetailState {}

class ProductDetailLoaded extends ProductDetailState {
  final ProductEntity? product;

  const ProductDetailLoaded(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductDetailError extends ProductDetailState {
  final String message;

  const ProductDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
