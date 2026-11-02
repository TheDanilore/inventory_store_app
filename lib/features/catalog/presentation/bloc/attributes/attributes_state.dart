import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';

class AttributesState extends Equatable {
  final ViewState viewState;
  final List<AttributeEntity> attributes;
  final String? errorMessage;
  final bool isSaving;
  final bool isRefreshing;

  const AttributesState({
    this.viewState = ViewState.initial,
    this.attributes = const [],
    this.errorMessage,
    this.isSaving = false,
    this.isRefreshing = false,
  });

  AttributesState copyWith({
    ViewState? viewState,
    List<AttributeEntity>? attributes,
    String? errorMessage,
    bool? isSaving,
    bool? isRefreshing,
    bool clearErrorMessage = false,
  }) {
    return AttributesState(
      viewState: viewState ?? this.viewState,
      attributes: attributes ?? this.attributes,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    viewState,
    attributes,
    errorMessage,
    isSaving,
    isRefreshing,
  ];
}
