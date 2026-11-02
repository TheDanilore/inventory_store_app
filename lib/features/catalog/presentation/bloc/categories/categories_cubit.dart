import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_category_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_state.dart';

@lazySingleton
class CategoriesCubit extends Cubit<CategoriesState> {
  final GetCategoriesUC getCategoriesUC;
  final CreateCategoryUseCase createCategoryUseCase;
  final UpdateCategoryUC updateCategoryUC;
  final DeleteCategoryUC deleteCategoryUC;

  Timer? _debounceTimer;
  List<CategoryEntity> _allCategories = const [];

  CategoriesCubit({
    required this.getCategoriesUC,
    required this.createCategoryUseCase,
    required this.updateCategoryUC,
    required this.deleteCategoryUC,
  }) : super(_initialState(getCategoriesUC)) {
    final cached = getCategoriesUC.getCached();
    if (cached != null) {
      _allCategories = cached;
    }
  }

  static CategoriesState _initialState(GetCategoriesUC uc) {
    final cached = uc.getCached();
    if (cached != null && cached.isNotEmpty) {
      return CategoriesState(categories: cached, viewState: ViewState.success);
    }
    return const CategoriesState();
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadCategories({
    bool forceRefresh = false,
    String? query,
  }) async {
    if (query != null) {
      emit(state.copyWith(searchQuery: query));
    }

    // Zero-Shimmer / SWR: Solo emitir loading si no tenemos nada en caché L1
    if (_allCategories.isEmpty && state.categories.isEmpty) {
      emit(state.copyWith(viewState: ViewState.loading));
    }

    final result = await getCategoriesUC(forceRefresh: forceRefresh);

    result.fold(
      (failure) {
        if (state.categories.isEmpty) {
          emit(
            state.copyWith(
              viewState: ViewState.error,
              errorMessage: failure.message,
            ),
          );
        } else {
          emit(state.copyWith(errorMessage: failure.message));
        }
      },
      (categories) {
        _allCategories = categories;
        final filtered = _filterCategories(categories, state.searchQuery);
        emit(
          state.copyWith(
            viewState: filtered.isEmpty ? ViewState.empty : ViewState.success,
            categories: filtered,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  List<CategoryEntity> _filterCategories(
    List<CategoryEntity> list,
    String query,
  ) {
    if (query.trim().isEmpty) return list;
    final q = query.trim().toLowerCase();
    return list
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      final filtered = _filterCategories(_allCategories, query);
      emit(
        state.copyWith(
          searchQuery: query,
          categories: filtered,
          viewState: filtered.isEmpty ? ViewState.empty : ViewState.success,
        ),
      );
    });
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    final filtered = _allCategories;
    emit(
      state.copyWith(
        searchQuery: '',
        categories: filtered,
        viewState: filtered.isEmpty ? ViewState.empty : ViewState.success,
      ),
    );
  }

  Future<void> toggleStatus(CategoryEntity cat, bool isActive) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    final result = await updateCategoryUC(
      id: cat.id!,
      name: cat.name,
      description: cat.description,
      isActive: isActive,
    );
    result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      },
      (_) {
        _allCategories =
            _allCategories.map((c) {
              if (c.id == cat.id) {
                return c.copyWith(isActive: isActive);
              }
              return c;
            }).toList();

        final updatedList = _filterCategories(
          _allCategories,
          state.searchQuery,
        );
        emit(
          state.copyWith(
            isSaving: false,
            categories: updatedList,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<bool> saveCategory({
    CategoryEntity? existingCategory,
    required String name,
    required String description,
    required bool isActive,
  }) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));

    final result =
        existingCategory == null
            ? await createCategoryUseCase(
              name: name,
              description: description,
              isActive: isActive,
            )
            : await updateCategoryUC(
              id: existingCategory.id!,
              name: name,
              description: description,
              isActive: isActive,
            );

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadCategories(forceRefresh: true);
        return true;
      },
    );
  }

  Future<bool> deleteCategory(String id) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    final result = await deleteCategoryUC(id);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        _allCategories = _allCategories.where((c) => c.id != id).toList();
        final updatedList = _filterCategories(
          _allCategories,
          state.searchQuery,
        );
        emit(
          state.copyWith(
            isSaving: false,
            clearErrorMessage: true,
            categories: updatedList,
            viewState:
                updatedList.isEmpty ? ViewState.empty : ViewState.success,
          ),
        );
        return true;
      },
    );
  }
}
