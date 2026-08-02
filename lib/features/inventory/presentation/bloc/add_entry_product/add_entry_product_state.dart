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
      // If we pass errorMessage explicitly, it updates. If we want to clear it, we might need a wrapped value or just set it to null in the caller, but here we can't easily clear it with copyWith unless we do a trick.
      // For simplicity, we just pass null when we want to clear it, but Dart copyWith usually doesn't allow setting null.
      // Workaround: we can just use errorMessage parameter directly.
      // Actually, if we pass a value, we use it. If not, we keep the old one.
      // Wait, in the cubit we did `errorMessage: null`. To allow setting to null, we can do:
      errorMessage:
          errorMessage, // This means errorMessage will be set to what's passed, or null if omitted. But this means we lose it if omitted.
      // Let's change the Cubit to use a new state or just standard copyWith where we can pass null.
    );
  }

  // To properly handle nulls in copyWith:
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
