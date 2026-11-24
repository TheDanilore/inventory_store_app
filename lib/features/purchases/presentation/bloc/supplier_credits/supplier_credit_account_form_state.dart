import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

class SupplierCreditAccountFormState extends Equatable {
  final bool isEditing;
  final bool isSearching;
  final bool isSaving;
  final List<SupplierCandidateEntity> matches;
  final String? selectedSupplierId;
  final String? selectedSupplierName;
  final Failure? searchFailure;
  final Failure? saveFailure;
  final bool savedSuccessfully;
  final SupplierCreditEntity? savedCredit;

  const SupplierCreditAccountFormState({
    this.isEditing = false,
    this.isSearching = false,
    this.isSaving = false,
    this.matches = const [],
    this.selectedSupplierId,
    this.selectedSupplierName,
    this.searchFailure,
    this.saveFailure,
    this.savedSuccessfully = false,
    this.savedCredit,
  });

  SupplierCreditAccountFormState copyWith({
    bool? isEditing,
    bool? isSearching,
    bool? isSaving,
    List<SupplierCandidateEntity>? matches,
    String? selectedSupplierId,
    bool clearSelectedSupplier = false,
    String? selectedSupplierName,
    Failure? searchFailure,
    bool clearSearchFailure = false,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? savedSuccessfully,
    SupplierCreditEntity? savedCredit,
  }) {
    return SupplierCreditAccountFormState(
      isEditing: isEditing ?? this.isEditing,
      isSearching: isSearching ?? this.isSearching,
      isSaving: isSaving ?? this.isSaving,
      matches: matches ?? this.matches,
      selectedSupplierId:
          clearSelectedSupplier
              ? null
              : (selectedSupplierId ?? this.selectedSupplierId),
      selectedSupplierName:
          clearSelectedSupplier
              ? null
              : (selectedSupplierName ?? this.selectedSupplierName),
      searchFailure:
          clearSearchFailure ? null : (searchFailure ?? this.searchFailure),
      saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
      savedSuccessfully: savedSuccessfully ?? this.savedSuccessfully,
      savedCredit: savedCredit ?? this.savedCredit,
    );
  }

  @override
  List<Object?> get props => [
    isEditing,
    isSearching,
    isSaving,
    matches,
    selectedSupplierId,
    selectedSupplierName,
    searchFailure,
    saveFailure,
    savedSuccessfully,
    savedCredit,
  ];
}
