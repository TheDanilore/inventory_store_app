import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

abstract class VariantPickerState extends Equatable {
  const VariantPickerState();

  @override
  List<Object?> get props => [];
}

class VariantPickerInitial extends VariantPickerState {}

class VariantPickerLoading extends VariantPickerState {}

class VariantPickerLoaded extends VariantPickerState {
  final List<ProductVariantEntity> variants;
  final Map<String, int> stockByVariant;

  const VariantPickerLoaded({
    required this.variants,
    required this.stockByVariant,
  });

  @override
  List<Object?> get props => [variants, stockByVariant];
}

class VariantPickerError extends VariantPickerState {
  final String message;

  const VariantPickerError(this.message);

  @override
  List<Object?> get props => [message];
}
