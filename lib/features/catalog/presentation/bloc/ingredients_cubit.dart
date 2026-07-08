import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';

import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/create_ingredient_uc.dart';
import 'ingredients_state.dart';

@injectable
class IngredientsCubit extends Cubit<IngredientsState> {
  final GetIngredientsUC getIngredientsUC;
  final CreateIngredientUC createIngredientUC;
  final UpdateIngredientUC updateIngredientUC;
  final DeleteIngredientUC deleteIngredientUC;

  Timer? _debounceTimer;

  IngredientsCubit({
    required this.getIngredientsUC,
    required this.createIngredientUC,
    required this.updateIngredientUC,
    required this.deleteIngredientUC,
  }) : super(const IngredientsState());

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadIngredients({String? query}) async {
    if (query != null) {
      emit(state.copyWith(searchQuery: query, viewState: ViewState.loading));
    } else {
      emit(state.copyWith(viewState: ViewState.loading));
    }

    final result = await getIngredientsUC(searchQuery: state.searchQuery, limit: 100);
    
    result.fold(
      (failure) => emit(state.copyWith(
        viewState: ViewState.error,
        errorMessage: failure.message,
      )),
      (ingredients) => emit(state.copyWith(
        viewState: ingredients.isEmpty ? ViewState.empty : ViewState.success,
        ingredients: ingredients,
        clearErrorMessage: true,
      ))
    );
  }

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      loadIngredients(query: query);
    });
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    loadIngredients(query: '');
  }

  Future<bool> saveIngredient(String name, {String? id}) async {
    emit(state.copyWith(isSaving: true));

    final result = id == null
        ? await createIngredientUC(name)
        : await updateIngredientUC(id, name);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadIngredients();
        return true;
      }
    );
  }
  
  Future<bool> deleteIngredient(String id) async {
    emit(state.copyWith(isSaving: true));
    final result = await deleteIngredientUC(id);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadIngredients();
        return true;
      }
    );
  }
}
