import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

class AddExitProductState extends Equatable {
  final bool isLoadingVariants;
  final bool isLoadingBatches;
  final String? errorMessage;
  final List<Map<String, dynamic>> searchResults;
  final List<ProductVariantModel> availableVariants;
  final List<Map<String, dynamic>> availableBatches;

  const AddExitProductState({
    this.isLoadingVariants = false,
    this.isLoadingBatches = false,
    this.errorMessage,
    this.searchResults = const [],
    this.availableVariants = const [],
    this.availableBatches = const [],
  });

  AddExitProductState copyWith({
    bool? isLoadingVariants,
    bool? isLoadingBatches,
    String? errorMessage,
    List<Map<String, dynamic>>? searchResults,
    List<ProductVariantModel>? availableVariants,
    List<Map<String, dynamic>>? availableBatches,
  }) {
    return AddExitProductState(
      isLoadingVariants: isLoadingVariants ?? this.isLoadingVariants,
      isLoadingBatches: isLoadingBatches ?? this.isLoadingBatches,
      errorMessage: errorMessage ?? this.errorMessage,
      searchResults: searchResults ?? this.searchResults,
      availableVariants: availableVariants ?? this.availableVariants,
      availableBatches: availableBatches ?? this.availableBatches,
    );
  }

  AddExitProductState copyWithNullError({
    bool? isLoadingVariants,
    bool? isLoadingBatches,
    List<Map<String, dynamic>>? searchResults,
    List<ProductVariantModel>? availableVariants,
    List<Map<String, dynamic>>? availableBatches,
  }) {
    return AddExitProductState(
      isLoadingVariants: isLoadingVariants ?? this.isLoadingVariants,
      isLoadingBatches: isLoadingBatches ?? this.isLoadingBatches,
      errorMessage: null,
      searchResults: searchResults ?? this.searchResults,
      availableVariants: availableVariants ?? this.availableVariants,
      availableBatches: availableBatches ?? this.availableBatches,
    );
  }

  @override
  List<Object?> get props => [
        isLoadingVariants,
        isLoadingBatches,
        errorMessage,
        searchResults,
        availableVariants,
        availableBatches,
      ];
}
