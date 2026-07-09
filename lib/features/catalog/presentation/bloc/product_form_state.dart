import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

// Clases de utilidad locales para el Formulario
class DetailControllers {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  DetailControllers({required this.keyCtrl, required this.valueCtrl});

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class FormImageItem {
  final String id;
  final ProductImageEntity? existing;
  final Uint8List? newBytes;
  final String? newName;

  FormImageItem({this.existing, this.newBytes, this.newName})
      : id = UniqueKey().toString();

  bool get isExisting => existing != null;
}

class IngredientRow {
  String? ingredientId;
  final TextEditingController nameCtrl;
  final TextEditingController concentrationCtrl;
  final TextEditingController unitCtrl;

  IngredientRow({
    this.ingredientId,
    String name = '',
    String concentration = '',
    String unit = '',
  })  : nameCtrl = TextEditingController(text: name),
        concentrationCtrl = TextEditingController(text: concentration),
        unitCtrl = TextEditingController(text: unit);

  void dispose() {
    nameCtrl.dispose();
    concentrationCtrl.dispose();
    unitCtrl.dispose();
  }
}

class ProductFormState extends Equatable {
  final ProductEntity? productToEdit;
  final bool isInitializingData;
  final bool hasErrorLoading;
  final String errorMessage;
  final bool isSaving;
  final bool isDirty;
  
  final bool isLoadingCategories;
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  
  final String productType;
  final bool stockControl;
  final bool batchManagementEnabled;
  final bool ingredientsEnabled;
  
  // Dynamic collections
  final List<DetailControllers> detailRows;
  final List<IngredientRow> ingredientRows;
  final List<FormImageItem> formImages;
  final List<VariantDraftModel> variantDrafts;
  final List<String> removedVariantIds;

  const ProductFormState({
    this.productToEdit,
    this.isInitializingData = false,
    this.hasErrorLoading = false,
    this.errorMessage = '',
    this.isSaving = false,
    this.isDirty = false,
    this.isLoadingCategories = false,
    this.categories = const [],
    this.selectedCategoryId,
    this.productType = 'good',
    this.stockControl = true,
    this.batchManagementEnabled = false,
    this.ingredientsEnabled = false,
    this.detailRows = const [],
    this.ingredientRows = const [],
    this.formImages = const [],
    this.variantDrafts = const [],
    this.removedVariantIds = const [],
  });

  factory ProductFormState.initial() => const ProductFormState();

  ProductFormState copyWith({
    ProductEntity? productToEdit,
    bool? isInitializingData,
    bool? hasErrorLoading,
    String? errorMessage,
    bool? isSaving,
    bool? isDirty,
    bool? isLoadingCategories,
    List<CategoryEntity>? categories,
    String? selectedCategoryId,
    String? productType,
    bool? stockControl,
    bool? batchManagementEnabled,
    bool? ingredientsEnabled,
    List<DetailControllers>? detailRows,
    List<IngredientRow>? ingredientRows,
    List<FormImageItem>? formImages,
    List<VariantDraftModel>? variantDrafts,
    List<String>? removedVariantIds,
  }) {
    return ProductFormState(
      productToEdit: productToEdit ?? this.productToEdit,
      isInitializingData: isInitializingData ?? this.isInitializingData,
      hasErrorLoading: hasErrorLoading ?? this.hasErrorLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      productType: productType ?? this.productType,
      stockControl: stockControl ?? this.stockControl,
      batchManagementEnabled: batchManagementEnabled ?? this.batchManagementEnabled,
      ingredientsEnabled: ingredientsEnabled ?? this.ingredientsEnabled,
      detailRows: detailRows ?? this.detailRows,
      ingredientRows: ingredientRows ?? this.ingredientRows,
      formImages: formImages ?? this.formImages,
      variantDrafts: variantDrafts ?? this.variantDrafts,
      removedVariantIds: removedVariantIds ?? this.removedVariantIds,
    );
  }

  ProductFormState copyWithCategory({String? selectedCategoryId}) {
    return ProductFormState(
      productToEdit: productToEdit,
      isInitializingData: isInitializingData,
      hasErrorLoading: hasErrorLoading,
      errorMessage: errorMessage,
      isSaving: isSaving,
      isDirty: isDirty,
      isLoadingCategories: isLoadingCategories,
      categories: categories,
      selectedCategoryId: selectedCategoryId,
      productType: productType,
      stockControl: stockControl,
      batchManagementEnabled: batchManagementEnabled,
      ingredientsEnabled: ingredientsEnabled,
      detailRows: detailRows,
      ingredientRows: ingredientRows,
      formImages: formImages,
      variantDrafts: variantDrafts,
      removedVariantIds: removedVariantIds,
    );
  }

  @override
  List<Object?> get props => [
        productToEdit,
        isInitializingData,
        hasErrorLoading,
        errorMessage,
        isSaving,
        isDirty,
        isLoadingCategories,
        categories,
        selectedCategoryId,
        productType,
        stockControl,
        batchManagementEnabled,
        ingredientsEnabled,
        detailRows,
        ingredientRows,
        formImages,
        variantDrafts,
        removedVariantIds,
      ];
}
