import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';

class CategoriesState extends Equatable {
  final ViewState viewState;
  final List<CategoryEntity> categories;
  final String? errorMessage;
  final bool isSaving;
  final String searchQuery;

  const CategoriesState({
    this.viewState = ViewState.initial,
    this.categories = const [],
    this.errorMessage,
    this.isSaving = false,
    this.searchQuery = '',
  });

  CategoriesState copyWith({
    ViewState? viewState,
    List<CategoryEntity>? categories,
    String? errorMessage,
    bool? isSaving,
    String? searchQuery,
    bool clearErrorMessage = false,
  }) {
    return CategoriesState(
      viewState: viewState ?? this.viewState,
      categories: categories ?? this.categories,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        viewState,
        categories,
        errorMessage,
        isSaving,
        searchQuery,
      ];
}
