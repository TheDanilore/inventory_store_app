import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/save_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/search_available_suppliers_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credit_account_form_state.dart';

@injectable
class SupplierCreditAccountFormCubit
    extends Cubit<SupplierCreditAccountFormState> {
  final SearchAvailableSuppliersUseCase _searchSuppliers;
  final SaveSupplierCreditUseCase _saveSupplierCredit;

  Timer? _debounce;
  int _searchRequestId = 0;
  SupplierCreditEntity? _accountToEdit;

  SupplierCreditAccountFormCubit(
    this._searchSuppliers,
    this._saveSupplierCredit,
  ) : super(const SupplierCreditAccountFormState());

  void init(SupplierCreditEntity? accountToEdit) {
    _accountToEdit = accountToEdit;
    if (accountToEdit != null) {
      emit(
        state.copyWith(
          isEditing: true,
          selectedSupplierId: accountToEdit.supplierId,
          selectedSupplierName: accountToEdit.supplierName,
        ),
      );
    }
  }

  void onSearchChanged(String query) {
    if (state.isEditing) return;

    if (state.selectedSupplierId != null) {
      emit(
        state.copyWith(
          clearSelectedSupplier: true,
          clearSearchFailure: true,
        ),
      );
    }

    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchRequestId++;
      emit(
        state.copyWith(
          isSearching: false,
          matches: const [],
          clearSearchFailure: true,
        ),
      );
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    final reqId = ++_searchRequestId;
    emit(state.copyWith(isSearching: true, clearSearchFailure: true));

    final result = await _searchSuppliers(query);
    if (isClosed || reqId != _searchRequestId) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          isSearching: false,
          matches: const [],
          searchFailure: failure,
        ),
      ),
      (matches) => emit(
        state.copyWith(
          isSearching: false,
          matches: matches,
          clearSearchFailure: true,
        ),
      ),
    );
  }

  void selectSupplier(SupplierCandidateEntity supplier) {
    _debounce?.cancel();
    _searchRequestId++;
    emit(
      state.copyWith(
        selectedSupplierId: supplier.id,
        selectedSupplierName: supplier.name,
        matches: const [],
        isSearching: false,
        clearSearchFailure: true,
      ),
    );
  }

  Future<void> save(double creditLimit) async {
    if (state.isSaving) return;
    final supplierId = state.selectedSupplierId;
    if (supplierId == null) return;

    emit(
      state.copyWith(
        isSaving: true,
        clearSaveFailure: true,
        savedSuccessfully: false,
      ),
    );

    final result = await _saveSupplierCredit(
      creditId: _accountToEdit?.creditId,
      supplierId: supplierId,
      creditLimit: creditLimit,
    );

    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          isSaving: false,
          saveFailure: failure,
          savedSuccessfully: false,
        ),
      ),
      (updatedCredit) => emit(
        state.copyWith(
          isSaving: false,
          clearSaveFailure: true,
          savedSuccessfully: true,
          savedCredit: updatedCredit,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
