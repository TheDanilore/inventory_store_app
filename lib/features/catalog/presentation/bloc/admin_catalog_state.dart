import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class AdminCatalogState extends Equatable {
  final ViewState catalogState;
  final ViewState actionState;
  final List<CategoryEntity> categories;
  final List<ProductEntity> products;
  final Map<String, String> matchedIngredients;
  final String? selectedCategoryId;
  final String searchTerm;
  final bool searchByIngredient;
  final bool? filterIsActive;
  final String sortOption;
  final int stockFilter;
  final int totalCount;
  final int currentPage;
  final String? errorMessage;

  const AdminCatalogState({
    this.catalogState = ViewState.initial,
    this.actionState = ViewState.initial,
    this.categories = const [],
    this.products = const [],
    this.matchedIngredients = const {},
    this.selectedCategoryId,
    this.searchTerm = '',
    this.searchByIngredient = false,
    this.filterIsActive,
    this.sortOption = 'Recientes',
    this.stockFilter = 0,
    this.totalCount = 0,
    this.currentPage = 0,
    this.errorMessage,
  });

  static const int pageSize = 24;
  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
  bool get isLoading => catalogState == ViewState.loading;
  bool get isLoadingAction => actionState == ViewState.loading;

  AdminCatalogState copyWith({
    ViewState? catalogState,
    ViewState? actionState,
    List<CategoryEntity>? categories,
    List<ProductEntity>? products,
    Map<String, String>? matchedIngredients,
    String? selectedCategoryId,
    String? searchTerm,
    bool? searchByIngredient,
    bool? filterIsActive,
    String? sortOption,
    int? stockFilter,
    int? totalCount,
    int? currentPage,
    String? errorMessage,
    bool clearCategory = false,
    bool clearError = false,
    bool clearFilterIsActive = false,
  }) {
    return AdminCatalogState(
      catalogState: catalogState ?? this.catalogState,
      actionState: actionState ?? this.actionState,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      matchedIngredients: matchedIngredients ?? this.matchedIngredients,
      selectedCategoryId:
          clearCategory
              ? null
              : (selectedCategoryId ?? this.selectedCategoryId),
      searchTerm: searchTerm ?? this.searchTerm,
      searchByIngredient: searchByIngredient ?? this.searchByIngredient,
      filterIsActive:
          clearFilterIsActive ? null : (filterIsActive ?? this.filterIsActive),
      sortOption: sortOption ?? this.sortOption,
      stockFilter: stockFilter ?? this.stockFilter,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    catalogState,
    actionState,
    categories,
    products,
    matchedIngredients,
    selectedCategoryId,
    searchTerm,
    searchByIngredient,
    filterIsActive,
    sortOption,
    stockFilter,
    totalCount,
    currentPage,
    errorMessage,
  ];
}
