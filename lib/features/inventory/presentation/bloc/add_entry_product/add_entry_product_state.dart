import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

class AddEntryProductState extends Equatable {
  final bool isLoadingVariants;
  final bool isLoadingBatches;
  final List<Map<String, dynamic>> searchResults;
  final List<ProductVariantModel> availableVariants;
  final List<Map<String, dynamic>> availableBatches;
  final String? errorMessage;

  const AddEntryProductState({
    this.isLoadingVariants = false,
    this.isLoadingBatches = false,
    this.searchResults = const [],
    this.availableVariants = const [],
    this.availableBatches = const [],
    this.errorMessage,
  });

  AddEntryProductState copyWith({
    bool? isLoadingVariants,
    bool? isLoadingBatches,
    List<Map<String, dynamic>>? searchResults,
    List<ProductVariantModel>? availableVariants,
    List<Map<String, dynamic>>? availableBatches,
    String? errorMessage,
  }) {
    return AddEntryProductState(
      isLoadingVariants: isLoadingVariants ?? this.isLoadingVariants,
      isLoadingBatches: isLoadingBatches ?? this.isLoadingBatches,
      searchResults: searchResults ?? this.searchResults,
      availableVariants: availableVariants ?? this.availableVariants,
      availableBatches: availableBatches ?? this.availableBatches,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  AddEntryProductState copyWithNullError({
    bool? isLoadingVariants,
    bool? isLoadingBatches,
    List<Map<String, dynamic>>? searchResults,
    List<ProductVariantModel>? availableVariants,
    List<Map<String, dynamic>>? availableBatches,
  }) {
    return AddEntryProductState(
      isLoadingVariants: isLoadingVariants ?? this.isLoadingVariants,
      isLoadingBatches: isLoadingBatches ?? this.isLoadingBatches,
      searchResults: searchResults ?? this.searchResults,
      availableVariants: availableVariants ?? this.availableVariants,
      availableBatches: availableBatches ?? this.availableBatches,
      errorMessage: null,
    );
  }

  @override
  List<Object?> get props => [
    isLoadingVariants,
    isLoadingBatches,
    searchResults,
    availableVariants,
    availableBatches,
    errorMessage,
  ];
}
