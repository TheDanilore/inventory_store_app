import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_attributes_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_attribute_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_state.dart';

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

    if (id == null) {
      final result = await createAttributeUseCase(name);
      return result.fold(
        (failure) {
          emit(state.copyWith(isSaving: false, errorMessage: failure.message));
          return false;
        },
        (createdAttr) {
          final currentAttributes = List<AttributeEntity>.from(
            state.attributes,
          );
          currentAttributes.add(createdAttr);
          currentAttributes.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

          emit(
            state.copyWith(
              isSaving: false,
              clearErrorMessage: true,
              attributes: currentAttributes,
              viewState:
                  currentAttributes.isEmpty
                      ? ViewState.empty
                      : ViewState.success,
            ),
          );
          return true;
        },
      );
    } else {
      final result = await updateAttributeUC(id, name);
      return result.fold(
        (failure) {
          emit(state.copyWith(isSaving: false, errorMessage: failure.message));
          return false;
        },
        (_) {
          final currentAttributes = List<AttributeEntity>.from(
            state.attributes,
          );
          final index = currentAttributes.indexWhere((a) => a.id == id);
          if (index != -1) {
            currentAttributes[index] = currentAttributes[index].copyWith(
              name: name,
            );
          }
          currentAttributes.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

          emit(
            state.copyWith(
              isSaving: false,
              clearErrorMessage: true,
              attributes: currentAttributes,
              viewState:
                  currentAttributes.isEmpty
                      ? ViewState.empty
                      : ViewState.success,
            ),
          );
          return true;
        },
      );
    }
  }

  Future<bool> deleteAttribute(String id) async {
    emit(state.copyWith(isSaving: true));
    final result = await deleteAttributeUC(id);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        final currentAttributes =
            state.attributes.where((a) => a.id != id).toList();
        emit(
          state.copyWith(
            isSaving: false,
            clearErrorMessage: true,
            attributes: currentAttributes,
            viewState:
                currentAttributes.isEmpty ? ViewState.empty : ViewState.success,
          ),
        );
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

    if (valueId == null) {
      final result = await createAttributeValueUC(attributeId, value);
      return result.fold(
        (failure) {
          emit(state.copyWith(isSaving: false, errorMessage: failure.message));
          return false;
        },
        (createdVal) {
          final currentAttributes = List<AttributeEntity>.from(
            state.attributes,
          );
          final attrIndex = currentAttributes.indexWhere(
            (a) => a.id == attributeId,
          );

          if (attrIndex != -1) {
            final attr = currentAttributes[attrIndex];
            final currentValues = List<AttributeValueEntity>.from(attr.values);
            currentValues.add(createdVal);
            currentAttributes[attrIndex] = attr.copyWith(values: currentValues);
          }

          emit(
            state.copyWith(
              isSaving: false,
              clearErrorMessage: true,
              attributes: currentAttributes,
            ),
          );
          return true;
        },
      );
    } else {
      final result = await updateAttributeValueUC(valueId, value);
      return result.fold(
        (failure) {
          emit(state.copyWith(isSaving: false, errorMessage: failure.message));
          return false;
        },
        (_) {
          final currentAttributes = List<AttributeEntity>.from(
            state.attributes,
          );
          final attrIndex = currentAttributes.indexWhere(
            (a) => a.id == attributeId,
          );

          if (attrIndex != -1) {
            final attr = currentAttributes[attrIndex];
            final currentValues = List<AttributeValueEntity>.from(attr.values);
            final valIndex = currentValues.indexWhere((v) => v.id == valueId);
            if (valIndex != -1) {
              currentValues[valIndex] = currentValues[valIndex].copyWith(
                value: value,
              );
            }
            currentAttributes[attrIndex] = attr.copyWith(values: currentValues);
          }

          emit(
            state.copyWith(
              isSaving: false,
              clearErrorMessage: true,
              attributes: currentAttributes,
            ),
          );
          return true;
        },
      );
    }
  }

  Future<bool> deleteAttributeValue(String valueId) async {
    emit(state.copyWith(isSaving: true));
    final result = await deleteAttributeValueUC(valueId);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        final currentAttributes = List<AttributeEntity>.from(state.attributes);
        for (int i = 0; i < currentAttributes.length; i++) {
          final attr = currentAttributes[i];
          if (attr.values.any((v) => v.id == valueId)) {
            final newValues =
                attr.values.where((v) => v.id != valueId).toList();
            currentAttributes[i] = attr.copyWith(values: newValues);
            break;
          }
        }

        emit(
          state.copyWith(
            isSaving: false,
            clearErrorMessage: true,
            attributes: currentAttributes,
          ),
        );
        return true;
      },
    );
  }
}
