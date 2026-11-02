import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';

import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/create_ingredient_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_state.dart';

@lazySingleton
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

  /// Carga de componentes químicos con política Stale-While-Revalidate (Zero-Shimmer).
  ///
  /// Si el estado actual ya posee ingredientes en caché en memoria y no se fuerza refresco,
  /// se preserva la visualización instantánea sin provocar transiciones destructivas a
  /// `ViewState.loading` que gatillarían shimmer en pantallas de bajo recurso/navegación.
  Future<void> loadIngredients({
    String? query,
    bool forceRefresh = false,
  }) async {
    final hasExistingData = state.ingredients.isNotEmpty;
    final isQueryChange = query != null && query != state.searchQuery;

    if (query != null) {
      emit(
        state.copyWith(
          searchQuery: query,
          viewState:
              (hasExistingData && !isQueryChange)
                  ? state.viewState
                  : ViewState.loading,
        ),
      );
    } else if (!hasExistingData || forceRefresh) {
      emit(state.copyWith(viewState: ViewState.loading));
    }

    final result = await getIngredientsUC(
      searchQuery: state.searchQuery,
      limit: 100,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          viewState: hasExistingData ? state.viewState : ViewState.error,
          errorMessage: failure.message,
          incrementErrorId: true,
        ),
      ),
      (ingredients) => emit(
        state.copyWith(
          viewState: ingredients.isEmpty ? ViewState.empty : ViewState.success,
          ingredients: ingredients,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      loadIngredients(query: query);
    });
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    loadIngredients(query: '');
  }

  Future<bool> saveIngredient(String name, {String? id}) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));

    final result =
        id == null
            ? await createIngredientUC(name)
            : await updateIngredientUC(id, name);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: failure.message,
            incrementErrorId: true,
          ),
        );
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadIngredients(forceRefresh: true);
        return true;
      },
    );
  }

  Future<bool> deleteIngredient(String id) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    final result = await deleteIngredientUC(id);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: failure.message,
            incrementErrorId: true,
          ),
        );
        return false;
      },
      (_) {
        final updatedList = state.ingredients.where((i) => i.id != id).toList();
        emit(
          state.copyWith(
            isSaving: false,
            clearErrorMessage: true,
            ingredients: updatedList,
            viewState:
                updatedList.isEmpty ? ViewState.empty : ViewState.success,
          ),
        );
        return true;
      },
    );
  }
}
