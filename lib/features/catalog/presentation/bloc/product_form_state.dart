import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';

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

  // ── Colecciones dinámicas (datos puros, sin TextEditingController) ──────────
  final List<DetailModel> detailRows;
  final List<IngredientRowModel> ingredientRows;
  final List<FormImageItem> formImages;
  final List<VariantDraftFormModel> variantDrafts;
  final List<String> removedVariantIds;

  // ── Señales de feedback para la UI (en lugar de BuildContext en el Cubit) ───
  /// Mensaje de información/advertencia a mostrar como Snackbar. Se limpia tras consumirse.
  final String? snackMessage;

  /// Mensaje de error a mostrar como Snackbar. Se limpia tras consumirse.
  final String? snackError;

  /// Señal de guardado exitoso. La UI reacciona navegando hacia atrás.
  final bool saveSuccess;

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
    this.snackMessage,
    this.snackError,
    this.saveSuccess = false,
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
    List<DetailModel>? detailRows,
    List<IngredientRowModel>? ingredientRows,
    List<FormImageItem>? formImages,
    List<VariantDraftFormModel>? variantDrafts,
    List<String>? removedVariantIds,
    String? snackMessage,
    String? snackError,
    bool? saveSuccess,
    bool clearSnacks = false,
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
      batchManagementEnabled:
          batchManagementEnabled ?? this.batchManagementEnabled,
      ingredientsEnabled: ingredientsEnabled ?? this.ingredientsEnabled,
      detailRows: detailRows ?? this.detailRows,
      ingredientRows: ingredientRows ?? this.ingredientRows,
      formImages: formImages ?? this.formImages,
      variantDrafts: variantDrafts ?? this.variantDrafts,
      removedVariantIds: removedVariantIds ?? this.removedVariantIds,
      snackMessage: clearSnacks ? null : (snackMessage ?? this.snackMessage),
      snackError: clearSnacks ? null : (snackError ?? this.snackError),
      saveSuccess: saveSuccess ?? this.saveSuccess,
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
    snackMessage,
    snackError,
    saveSuccess,
  ];
}
