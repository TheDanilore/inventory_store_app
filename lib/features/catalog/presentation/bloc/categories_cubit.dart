import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_category_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'categories_state.dart';

@injectable
class CategoriesCubit extends Cubit<CategoriesState> {
  final GetCategoriesUC getCategoriesUC;
  final CreateCategoryUC createCategoryUC;
  final UpdateCategoryUC updateCategoryUC;
  final DeleteCategoryUC deleteCategoryUC;

  Timer? _debounceTimer;

  CategoriesCubit({
    required this.getCategoriesUC,
    required this.createCategoryUC,
    required this.updateCategoryUC,
    required this.deleteCategoryUC,
  }) : super(const CategoriesState());

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadCategories({bool forceRefresh = false, String? query}) async {
    if (query != null) {
      emit(state.copyWith(searchQuery: query, viewState: ViewState.loading));
    } else {
      emit(state.copyWith(viewState: ViewState.loading));
    }

    final result = await getCategoriesUC();
    
    result.fold(
      (failure) => emit(state.copyWith(
        viewState: ViewState.error,
        errorMessage: failure.message,
      )),
      (categories) {
        var filtered = categories;
        if (state.searchQuery.isNotEmpty) {
          filtered = categories
              .where((c) => c.name.toLowerCase().contains(state.searchQuery.toLowerCase()))
              .toList();
        }
        emit(state.copyWith(
          viewState: filtered.isEmpty ? ViewState.empty : ViewState.success,
          categories: filtered,
          clearErrorMessage: true,
        ));
      }
    );
  }

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      loadCategories(query: query);
    });
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    loadCategories(query: '');
  }

  Future<void> toggleStatus(CategoryEntity cat, bool isActive) async {
    emit(state.copyWith(isSaving: true));
    final result = await updateCategoryUC(
      id: cat.id!, 
      name: cat.name, 
      description: cat.description, 
      isActive: isActive
    );
    result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      },
      (_) {
        final updatedList = state.categories.map((c) {
          if (c.id == cat.id) {
            return c.copyWith(isActive: isActive);
          }
          return c;
        }).toList();
        emit(state.copyWith(
          isSaving: false,
          categories: updatedList,
          clearErrorMessage: true,
        ));
      }
    );
  }

  Future<bool> saveCategory({
    CategoryEntity? existingCategory,
    required String name,
    required String description,
    required bool isActive,
  }) async {
    emit(state.copyWith(isSaving: true));

    final result = existingCategory == null
        ? await createCategoryUC(name: name, description: description, isActive: isActive)
        : await updateCategoryUC(id: existingCategory.id!, name: name, description: description, isActive: isActive);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadCategories(forceRefresh: true);
        return true;
      }
    );
  }
}
