import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class CustomerCatalogState extends Equatable {
  final ViewState viewState;
  final List<CategoryEntity> categories;
  final List<ProductEntity> products;
  final String? selectedCategoryId;
  final String searchTerm;
  final bool isSearchMode;
  final List<String> searchHistory;
  final bool hasMoreProducts;
  final bool isLoadingMore;
  final String? errorMessage;

  const CustomerCatalogState({
    this.viewState = ViewState.initial,
    this.categories = const [],
    this.products = const [],
    this.selectedCategoryId,
    this.searchTerm = '',
    this.isSearchMode = false,
    this.searchHistory = const [],
    this.hasMoreProducts = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  CustomerCatalogState copyWith({
    ViewState? viewState,
    List<CategoryEntity>? categories,
    List<ProductEntity>? products,
    String? selectedCategoryId,
    String? searchTerm,
    bool? isSearchMode,
    List<String>? searchHistory,
    bool? hasMoreProducts,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearCategory = false,
    bool clearError = false,
  }) {
    return CustomerCatalogState(
      viewState: viewState ?? this.viewState,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      selectedCategoryId:
          clearCategory
              ? null
              : (selectedCategoryId ?? this.selectedCategoryId),
      searchTerm: searchTerm ?? this.searchTerm,
      isSearchMode: isSearchMode ?? this.isSearchMode,
      searchHistory: searchHistory ?? this.searchHistory,
      hasMoreProducts: hasMoreProducts ?? this.hasMoreProducts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    viewState,
    categories,
    products,
    selectedCategoryId,
    searchTerm,
    isSearchMode,
    searchHistory,
    hasMoreProducts,
    isLoadingMore,
    errorMessage,
  ];
}
