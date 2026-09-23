import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_brand_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_brands_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/brands/brands_state.dart';

@injectable
class BrandsCubit extends Cubit<BrandsState> {
  final GetBrandsUC getBrandsUC;
  final CreateBrandUseCase createBrandUseCase;
  final UpdateBrandUC updateBrandUC;
  final DeleteBrandUC deleteBrandUC;

  Timer? _debounceTimer;

  BrandsCubit({
    required this.getBrandsUC,
    required this.createBrandUseCase,
    required this.updateBrandUC,
    required this.deleteBrandUC,
  }) : super(const BrandsState());

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadBrands({
    bool forceRefresh = false,
    String? query,
  }) async {
    if (query != null) {
      emit(state.copyWith(searchQuery: query, viewState: ViewState.loading));
    } else {
      emit(state.copyWith(viewState: ViewState.loading));
    }

    final result = await getBrandsUC();

    result.fold(
      (failure) => emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: failure.message,
        ),
      ),
      (brands) {
        var filtered = brands;
        if (state.searchQuery.isNotEmpty) {
          final q = state.searchQuery.toLowerCase();
          filtered =
              brands
                  .where(
                    (b) =>
                        b.name.toLowerCase().contains(q) ||
                        (b.description != null &&
                            b.description!.toLowerCase().contains(q)),
                  )
                  .toList();
        }
        emit(
          state.copyWith(
            viewState: filtered.isEmpty ? ViewState.empty : ViewState.success,
            brands: filtered,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadBrands(query: query);
    });
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    loadBrands(query: '');
  }

  Future<void> toggleStatus(BrandEntity brand, bool isActive) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    final result = await updateBrandUC(
      id: brand.id!,
      name: brand.name,
      description: brand.description,
      logoUrl: brand.logoUrl,
      website: brand.website,
      isActive: isActive,
    );
    result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      },
      (_) {
        final updatedList =
            state.brands.map((b) {
              if (b.id == brand.id) {
                return b.copyWith(isActive: isActive);
              }
              return b;
            }).toList();
        emit(
          state.copyWith(
            isSaving: false,
            brands: updatedList,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<bool> saveBrand({
    BrandEntity? existingBrand,
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
  }) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));

    final result =
        existingBrand == null
            ? await createBrandUseCase(
              name: name,
              description: description,
              logoUrl: logoUrl,
              website: website,
              isActive: isActive,
            )
            : await updateBrandUC(
              id: existingBrand.id!,
              name: name,
              description: description,
              logoUrl: logoUrl,
              website: website,
              isActive: isActive,
            );

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadBrands(forceRefresh: true);
        return true;
      },
    );
  }

  Future<bool> deleteBrand(String id) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    final result = await deleteBrandUC(id);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        final updatedList = state.brands.where((b) => b.id != id).toList();
        emit(
          state.copyWith(
            isSaving: false,
            clearErrorMessage: true,
            brands: updatedList,
            viewState:
                updatedList.isEmpty ? ViewState.empty : ViewState.success,
          ),
        );
        return true;
      },
    );
  }
}
