import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';

class IngredientsState extends Equatable {
  final ViewState viewState;
  final List<ActiveIngredientEntity> ingredients;
  final String? errorMessage;
  final bool isSaving;
  final String searchQuery;

  const IngredientsState({
    this.viewState = ViewState.initial,
    this.ingredients = const [],
    this.errorMessage,
    this.isSaving = false,
    this.searchQuery = '',
  });

  IngredientsState copyWith({
    ViewState? viewState,
    List<ActiveIngredientEntity>? ingredients,
    String? errorMessage,
    bool? isSaving,
    String? searchQuery,
    bool clearErrorMessage = false,
  }) {
    return IngredientsState(
      viewState: viewState ?? this.viewState,
      ingredients: ingredients ?? this.ingredients,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    viewState,
    ingredients,
    errorMessage,
    isSaving,
    searchQuery,
  ];
}
