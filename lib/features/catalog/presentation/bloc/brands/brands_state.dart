import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';

class BrandsState extends Equatable {
  final ViewState viewState;
  final List<BrandEntity> brands;
  final String? errorMessage;
  final bool isSaving;
  final String searchQuery;

  const BrandsState({
    this.viewState = ViewState.initial,
    this.brands = const [],
    this.errorMessage,
    this.isSaving = false,
    this.searchQuery = '',
  });

  BrandsState copyWith({
    ViewState? viewState,
    List<BrandEntity>? brands,
    String? errorMessage,
    bool? isSaving,
    String? searchQuery,
    bool clearErrorMessage = false,
  }) {
    return BrandsState(
      viewState: viewState ?? this.viewState,
      brands: brands ?? this.brands,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    viewState,
    brands,
    errorMessage,
    isSaving,
    searchQuery,
  ];
}
