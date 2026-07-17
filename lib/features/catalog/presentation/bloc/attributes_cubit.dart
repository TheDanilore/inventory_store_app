import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_attributes_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_attribute_mutations_uc.dart';
import 'attributes_state.dart';

@injectable
class AttributesCubit extends Cubit<AttributesState> {
  final GetAttributesUC getAttributesUC;
  final CreateAttributeUseCase createAttributeUseCase;
  final UpdateAttributeUC updateAttributeUC;
  final DeleteAttributeUC deleteAttributeUC;
  final CreateAttributeValueUC createAttributeValueUC;
  final UpdateAttributeValueUC updateAttributeValueUC;
  final DeleteAttributeValueUC deleteAttributeValueUC;

  AttributesCubit({
    required this.getAttributesUC,
    required this.createAttributeUseCase,
    required this.updateAttributeUC,
    required this.deleteAttributeUC,
    required this.createAttributeValueUC,
    required this.updateAttributeValueUC,
    required this.deleteAttributeValueUC,
  }) : super(const AttributesState());

  Future<void> loadAttributes() async {
    emit(state.copyWith(viewState: ViewState.loading));
    final result = await getAttributesUC();
    result.fold(
      (failure) => emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: failure.message,
        ),
      ),
      (attributes) => emit(
        state.copyWith(
          viewState: attributes.isEmpty ? ViewState.empty : ViewState.success,
          attributes: attributes,
          clearErrorMessage: true,
        ),
      ),
    );
  }

  Future<bool> saveAttribute(String name, {String? id}) async {
    emit(state.copyWith(isSaving: true));
    final result =
        id == null
            ? await createAttributeUseCase(name)
            : await updateAttributeUC(id, name);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadAttributes();
        return true;
      },
    );
  }

  Future<bool> deleteAttribute(String id) async {
    emit(state.copyWith(isSaving: true));
    final result = await deleteAttributeUC(id);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadAttributes();
        return true;
      },
    );
  }

  Future<bool> saveAttributeValue(
    String attributeId,
    String value, {
    String? valueId,
  }) async {
    emit(state.copyWith(isSaving: true));
    final result =
        valueId == null
            ? await createAttributeValueUC(attributeId, value)
            : await updateAttributeValueUC(valueId, value);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadAttributes();
        return true;
      },
    );
  }

  Future<bool> deleteAttributeValue(String valueId) async {
    emit(state.copyWith(isSaving: true));
    final result = await deleteAttributeValueUC(valueId);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSaving: false, clearErrorMessage: true));
        await loadAttributes();
        return true;
      },
    );
  }
}
