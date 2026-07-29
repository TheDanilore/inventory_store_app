import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';

class AttributesState extends Equatable {
  final ViewState viewState;
  final List<Map<String, dynamic>>
  attributes; // Para simplificar asumo que es map por ahora
  final String? errorMessage;
  final bool isSaving;

  const AttributesState({
    this.viewState = ViewState.initial,
    this.attributes = const [],
    this.errorMessage,
    this.isSaving = false,
  });

  AttributesState copyWith({
    ViewState? viewState,
    List<Map<String, dynamic>>? attributes,
    String? errorMessage,
    bool? isSaving,
    bool clearErrorMessage = false,
  }) {
    return AttributesState(
      viewState: viewState ?? this.viewState,
      attributes: attributes ?? this.attributes,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [viewState, attributes, errorMessage, isSaving];
}
