import 'package:injectable/injectable.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_image_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_variant_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/save_product_usecase.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'product_form_state.dart';

@injectable
class ProductFormCubit extends Cubit<ProductFormState> {
  final GetCategoriesUC _getCategoriesUC;
  final GetProductImagesUC _getProductImagesUC;
  final GetProductIngredientsUC _getProductIngredientsUC;
  final GetVariantsDraftsUC _getVariantsDraftsUC;
  final DeleteProductImageUC _deleteProductImageUC;
  final DeleteVariantUC _deleteVariantUC;
  final HasVariantSalesUC _hasVariantSalesUC;
  final GetCurrentProfileIdUseCase _getCurrentProfileIdUC;
  final SaveProductUseCase _saveProductUC;

  Future<T> _unwrap<T>(Future<Either<Failure, T>> future) async {
    final res = await future;
    return res.fold((f) => throw Exception(f.message), (r) => r);
  }

  ProductEntity? _productToEdit;

  // Controladores Generales
  final nombreCtrl = TextEditingController();
  final costoCtrl = TextEditingController();
  final precioCtrl = TextEditingController();
  final precioMayorCtrl = TextEditingController();
  final cantidadMayorCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // Estados de Configuración
  String _productType = 'good';
  bool _stockControl = true;
  bool _batchManagementEnabled = false;
  bool _ingredientsEnabled = false;

  // Colecciones dinámicas
  final List<DetailControllers> detailRows = [];
  final List<IngredientRow> ingredientRows = [];
  final List<FormImageItem> formImages = [];
  final List<VariantDraftModel> variantDrafts = [];
  final List<String> _removedVariantIds = [];

  // Categorías
  String? _selectedCategoryId;
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = true;

  // Flags de progreso
  bool _isInitializingData = false;
  bool _isSaving = false;
  bool _isDirty = false;

  ProductFormCubit(
    this._getCategoriesUC,
    this._getProductImagesUC,
    this._getProductIngredientsUC,
    this._getVariantsDraftsUC,
    this._deleteProductImageUC,
    this._deleteVariantUC,
    this._hasVariantSalesUC,
    this._getCurrentProfileIdUC,
    this._saveProductUC,
    @factoryParam ProductEntity? productToEdit,
  ) : super(ProductFormState.initial()) {
    initData(productToEdit);
  }

  bool _hasErrorLoading = false;
  String _errorMessage = '';

  // Getters
  bool get isInitializingData => _isInitializingData;
  bool get hasErrorLoading => _hasErrorLoading;
  String get errorMessage => _errorMessage;

  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _isDirty;
  bool get isLoadingCategories => _isLoadingCategories;
  List<CategoryEntity> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;

  String get productType => _productType;
  bool get stockControl => _stockControl;
  bool get batchManagementEnabled => _batchManagementEnabled;
  bool get ingredientsEnabled => _ingredientsEnabled;

  ProductEntity? get productToEdit => _productToEdit;

  // Setters
  void setProductType(String type) {
    _productType = type;
    if (_productType == 'service') {
      _stockControl = false;
      _batchManagementEnabled = false;
    }
    markAsDirty();
    _syncState();
  }

  void setStockControl(bool val) {
    _stockControl = val;
    markAsDirty();
    _syncState();
  }

  void setBatchManagement(bool val) {
    _batchManagementEnabled = val;
    markAsDirty();
    _syncState();
  }

  void setIngredientsEnabled(bool val) {
    _ingredientsEnabled = val;
    markAsDirty();
    _syncState();
  }

  void setSelectedCategory(String? id) {
    _selectedCategoryId = id;
    markAsDirty();
    _syncState();
  }

  void _syncState() {
    emit(
      state.copyWith(
        productToEdit: _productToEdit,
        isInitializingData: _isInitializingData,
        hasErrorLoading: _hasErrorLoading,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        isDirty: _isDirty,
        isLoadingCategories: _isLoadingCategories,
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        productType: _productType,
        stockControl: _stockControl,
        batchManagementEnabled: _batchManagementEnabled,
        ingredientsEnabled: _ingredientsEnabled,
        detailRows: List.of(detailRows),
        ingredientRows: List.of(ingredientRows),
        formImages: List.of(formImages),
        variantDrafts: List.of(variantDrafts),
        removedVariantIds: List.of(_removedVariantIds),
      ),
    );
  }

  void markAsDirty() {
    if (!_isDirty) {
      _isDirty = true;
    }
  }

  // --- Inicialización ---

  Future<void> initData(ProductEntity? product) async {
    _productToEdit = product;
    _isInitializingData = true;
    _hasErrorLoading = false;
    _errorMessage = '';
    _syncState();

    try {
      if (product != null) {
        // Editar
        nombreCtrl.text = product.name;
        costoCtrl.text = product.unitCost.toString();
        precioCtrl.text = product.salePrice.toString();
        precioMayorCtrl.text = product.wholesalePrice?.toString() ?? '';
        cantidadMayorCtrl.text = product.wholesaleMinQuantity.toString();
        descCtrl.text = product.description ?? '';
        _selectedCategoryId = product.categoryId;

        _productType = product.productType;
        _stockControl = product.stockControl;
        _batchManagementEnabled = product.usesBatches;

        if (product.details.isNotEmpty) {
          product.details.forEach((key, value) {
            detailRows.add(
              DetailControllers(
                keyCtrl: TextEditingController(text: key),
                valueCtrl: TextEditingController(text: value.toString()),
              ),
            );
          });
        }

        await Future.wait([
          _fetchCategories(),
          _fetchProductImages(product.id),
          _fetchIngredients(product.id),
          _fetchVariants(product.id),
        ]);
      } else {
        // Nuevo
        cantidadMayorCtrl.text = '3';
        await _fetchCategories();
      }
    } catch (e) {
      debugPrint('Error en initData: $e');
      _hasErrorLoading = true;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('timeout')) {
        _errorMessage = 'Error de red. Verifica tu conexión a internet.';
      } else {
        _errorMessage = 'Ocurrió un error inesperado al cargar los datos.';
      }
    } finally {
      _isInitializingData = false;
      _syncState();
    }
  }

  Future<void> _fetchCategories() async {
    _categories = await _unwrap(_getCategoriesUC.call());
    _isLoadingCategories = false;
    _syncState();
  }

  Future<void> _fetchProductImages(String productId) async {
    final images = await _unwrap(_getProductImagesUC.call(productId));
    formImages.addAll(images.map((img) => FormImageItem(existing: img)));
    _syncState();
  }

  Future<void> _fetchIngredients(String productId) async {
    final list = await _unwrap(_getProductIngredientsUC.call(productId));
    for (final row in list) {
      final activeIng = row['active_ingredients'] as Map<String, dynamic>?;
      ingredientRows.add(
        IngredientRow(
          ingredientId: row['ingredient_id'] as String,
          name: activeIng?['name'] as String? ?? '',
          concentration: row['concentration']?.toString() ?? '',
          unit: row['unit'] as String? ?? '',
        ),
      );
    }
    if (ingredientRows.isNotEmpty) _ingredientsEnabled = true;
    _syncState();
  }

  Future<void> _fetchVariants(String productId) async {
    try {
      final drafts = await _unwrap(_getVariantsDraftsUC.call(productId));
      variantDrafts.addAll(drafts.map(VariantDraftModel.fromEntity));
    } catch (e) {
      // El error se silencia o se maneja en el cubit. Aquí lo notificaremos por Snackbar desde UI idealmente.
    }
    _syncState();
  }

  // --- Manejo de Detalles y Formato ---

  void addDetailRow() {
    detailRows.add(
      DetailControllers(
        keyCtrl: TextEditingController(),
        valueCtrl: TextEditingController(),
      ),
    );
    markAsDirty();
    _syncState();
  }

  void removeDetailRow(int index) {
    detailRows[index].dispose();
    detailRows.removeAt(index);
    markAsDirty();
    _syncState();
  }

  void addIngredientRow() {
    ingredientRows.add(IngredientRow());
    markAsDirty();
    _syncState();
  }

  void removeIngredientRow(int index) {
    ingredientRows[index].dispose();
    ingredientRows.removeAt(index);
    markAsDirty();
    _syncState();
  }

  // --- Imágenes ---

  Future<void> pickImages(BuildContext context) async {
    final picker = ImagePicker();
    final archivos = await picker.pickMultiImage();

    if (archivos.isNotEmpty) {
      const maxImages = 5;
      final int currentCount = formImages.length;

      if (currentCount >= maxImages) {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Límite de imágenes alcanzado ($maxImages).',
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      var duplicadas = 0;
      var excedidas = 0;
      final nuevosItems = <FormImageItem>[];

      for (final archivo in archivos) {
        if (currentCount + nuevosItems.length >= maxImages) {
          excedidas++;
          continue;
        }

        final nombre = _normalizarNombreArchivo(archivo);
        if (formImages.any((img) => !img.isExisting && img.newName == nombre)) {
          duplicadas++;
          continue;
        }

        final bytesOriginales = await archivo.readAsBytes();
        final bytesOptimizados = await _optimizarImagen(bytesOriginales);

        nuevosItems.add(
          FormImageItem(newBytes: bytesOptimizados, newName: nombre),
        );
      }

      formImages.addAll(nuevosItems);
      markAsDirty();
      _syncState();

      if ((duplicadas > 0 || excedidas > 0) && context.mounted) {
        String msg = '';
        if (duplicadas > 0) msg += '$duplicadas repetida(s). ';
        if (excedidas > 0) msg += '$excedidas exceden el límite de $maxImages.';

        AppSnackbar.show(
          context,
          message: msg.trim(),
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  Future<void> removeImage(BuildContext context, int index) async {
    final item = formImages[index];

    if (item.isExisting) {
      try {
        await _unwrap(
          _deleteProductImageUC.call(
            item.existing!.id,
            item.existing!.imageUrl,
          ),
        );
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Imagen eliminada',
            backgroundColor: AppColors.success,
          );
        }
      } catch (e) {
        debugPrint('Error deleting product image: $e');
        if (context.mounted) {
          final errStr = e.toString().toLowerCase();
          String msg = 'Ocurrió un error al intentar actualizar el estado.';
          if (errStr.contains('socketexception') ||
              errStr.contains('clientexception') ||
              errStr.contains('failed host lookup')) {
            msg = 'Sin conexión a internet.';
          }
          AppSnackbar.show(context, message: msg, type: SnackbarType.error);
        }
        return;
      }
    }

    formImages.removeAt(index);
    markAsDirty();
    _syncState();
  }

  void reorderImages(int oldIndex, int newIndex) {
    final item = formImages.removeAt(oldIndex);
    formImages.insert(newIndex, item);
    markAsDirty();
    _syncState();
  }

  // --- Variantes ---

  void addVariantDraft() {
    variantDrafts.add(VariantDraftModel());
    markAsDirty();
    _syncState();
  }

  void duplicateVariantDraft(int index) {
    final original = variantDrafts[index];
    final copy = VariantDraftModel();
    copy.skuCtrl.text =
        original.skuCtrl.text.isNotEmpty ? '${original.skuCtrl.text}-COPY' : '';
    copy.reorderPointCtrl.text = original.reorderPointCtrl.text;
    copy.unitCostCtrl.text = original.unitCostCtrl.text;
    copy.priceCtrl.text = original.priceCtrl.text;
    copy.wholesalePriceCtrl.text = original.wholesalePriceCtrl.text;
    copy.wholesaleMinQuantityCtrl.text = original.wholesaleMinQuantityCtrl.text;
    copy.isActive = original.isActive;

    final copiedAttributes = <Map<String, dynamic>>[];
    for (var attr in original.selectedAttributes) {
      copiedAttributes.add(Map<String, dynamic>.from(attr));
    }
    copy.selectedAttributes = copiedAttributes;

    copy.urlsExistentes.addAll(original.urlsExistentes);

    variantDrafts.insert(index + 1, copy);
    markAsDirty();
    _syncState();
  }

  Future<void> removeVariantDraft(BuildContext context, int index) async {
    final draft = variantDrafts[index];

    if (draft.id == null) {
      draft.dispose();
      variantDrafts.removeAt(index);
      markAsDirty();
      _syncState();
      return;
    }

    try {
      final hasSales = await _unwrap(_hasVariantSalesUC(draft.id!));
      if (hasSales) {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message:
                "No se puede eliminar: Esta variante tiene ventas asociadas.",
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      await _unwrap(_deleteVariantUC.call(draft.id!));
      draft.dispose();
      variantDrafts.removeAt(index);
      markAsDirty();
      _syncState();

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: "Variante y su imagen eliminadas correctamente.",
        );
      }
    } catch (e) {
      debugPrint('Error deleting product image: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error al intentar eliminar.';
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        AppSnackbar.show(context, message: msg, type: SnackbarType.error);
      }
    }
  }

  Future<void> pickVariantImage(BuildContext context, int index) async {
    final draft = variantDrafts[index];
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytesOriginales = await file.readAsBytes();
      final bytesOptimizados = await _optimizarImagen(bytesOriginales);

      draft.urlsExistentes.clear();
      draft.nuevasImagenes.clear();
      draft.nuevasImagenes.add(bytesOptimizados);
      markAsDirty();
      _syncState();
    }
  }

  // --- Helper Compress/Upload ---

  Future<Uint8List> _optimizarImagen(Uint8List bytesOriginales) async {
    if (bytesOriginales.lengthInBytes < 250 * 1024) {
      return bytesOriginales;
    }
    try {
      final bytesComprimidos = await FlutterImageCompress.compressWithList(
        bytesOriginales,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (bytesComprimidos.isNotEmpty &&
          bytesComprimidos.lengthInBytes < bytesOriginales.lengthInBytes) {
        return bytesComprimidos;
      }
    } catch (e) {
      debugPrint('Error compresión: $e');
    }
    return bytesOriginales;
  }

  String _normalizarNombreArchivo(XFile archivo) {
    final rawName = archivo.name.trim();
    if (rawName.isNotEmpty) return rawName.toLowerCase();
    final segments = archivo.path.split(RegExp(r'[\\/]'));
    return segments.isEmpty
        ? archivo.path.toLowerCase()
        : segments.last.toLowerCase();
  }

  double? _parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  // --- Guardado General ---

  Future<bool> saveProduct(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    if (!formKey.currentState!.validate()) return false;

    final skus = variantDrafts
        .where((d) => d.skuCtrl.text.trim().isNotEmpty)
        .map((d) => d.skuCtrl.text.trim().toLowerCase());

    if (skus.toSet().length != skus.length) {
      AppSnackbar.show(
        context,
        message: "Hay SKUs duplicados en las variantes.",
        backgroundColor: Colors.red,
      );
      return false;
    }

    _isSaving = true;
    _syncState();

    try {
      final Map<String, String> detailsMap = {};
      for (final row in detailRows) {
        final key = row.keyCtrl.text.trim();
        final value = row.valueCtrl.text.trim();
        if (key.isNotEmpty) detailsMap[key] = value;
      }

      final isUpdating = _productToEdit != null;
      final unitCost = _parseDecimal(costoCtrl.text)!;
      final salePrice = _parseDecimal(precioCtrl.text)!;
      final wholesalePrice =
          precioMayorCtrl.text.trim().isEmpty
              ? null
              : _parseDecimal(precioMayorCtrl.text);

      final profileIdRes = await _getCurrentProfileIdUC.call();
      final profileId = profileIdRes.fold((l) => null, (r) => r);

      final productEntity = ProductEntity(
        id: isUpdating ? _productToEdit!.id : '',
        name: nombreCtrl.text.trim(),
        unitCost: unitCost,
        salePrice: salePrice,
        wholesalePrice: wholesalePrice,
        wholesaleMinQuantity:
            cantidadMayorCtrl.text.trim().isEmpty
                ? 3
                : (int.tryParse(cantidadMayorCtrl.text) ?? 3),
        isActive: isUpdating ? _productToEdit!.isActive : true,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        details: detailsMap,
        productType: _productType,
        stockControl: _stockControl,
        usesBatches: _batchManagementEnabled,
        createdAt: null,
        updatedAt: null,
        createdBy: null,
        updatedBy: null,
        images: const [],
        totalStock: 0,
        categoryName: null,
        productVariants: const [],
        warehouseStockBatches: const [],
      );

      final imagesPayload =
          formImages.map((item) {
            return ImagePayload(
              existingId: item.isExisting ? item.existing!.id : null,
              existingUrl: item.isExisting ? item.existing!.imageUrl : null,
              newBytes: item.newBytes,
            );
          }).toList();

      final variantsPayload =
          variantDrafts.map((draft) {
            final valueIds =
                draft.selectedAttributes
                    .map((attr) => attr['value_id'] as String)
                    .toList();
            final skuValue = draft.skuCtrl.text.trim();

            return VariantPayload(
              id: draft.id,
              sku: skuValue.isEmpty ? null : skuValue,
              unitCost: _parseDecimal(draft.unitCostCtrl.text) ?? 0.0,
              salePrice: _parseDecimal(draft.priceCtrl.text),
              wholesalePrice: _parseDecimal(draft.wholesalePriceCtrl.text),
              wholesaleMinQuantity: int.tryParse(
                draft.wholesaleMinQuantityCtrl.text,
              ),
              reorderPoint: int.tryParse(draft.reorderPointCtrl.text),
              isActive: draft.isActive,
              attributeValueIds: valueIds,
              clearImages:
                  draft.id != null &&
                  (draft.urlsExistentes.isEmpty ||
                      draft.nuevasImagenes.isNotEmpty),
              newImageBytes:
                  draft.nuevasImagenes.isNotEmpty
                      ? draft.nuevasImagenes.first
                      : null,
            );
          }).toList();

      final ingredientsPayload =
          ingredientRows
              .where(
                (r) =>
                    r.ingredientId != null && r.nameCtrl.text.trim().isNotEmpty,
              )
              .map(
                (row) => IngredientPayload(
                  ingredientId: row.ingredientId!,
                  concentration:
                      row.concentrationCtrl.text.trim().isEmpty
                          ? null
                          : double.tryParse(
                            row.concentrationCtrl.text.trim().replaceAll(
                              ',',
                              '.',
                            ),
                          ),
                  unit:
                      row.unitCtrl.text.trim().isEmpty
                          ? null
                          : row.unitCtrl.text.trim(),
                ),
              )
              .toList();

      final payload = SaveProductPayload(
        product: productEntity,
        profileId: profileId,
        isUpdating: isUpdating,
        images: imagesPayload,
        removedVariantIds: _removedVariantIds.toList(),
        variants: variantsPayload,
        ingredientsEnabled: _ingredientsEnabled,
        ingredients: ingredientsPayload,
      );

      final result = await _saveProductUC.call(payload);

      return result.fold(
        (failure) {
          if (context.mounted) _showError(context, failure.message);
          return false;
        },
        (_) {
          _removedVariantIds.clear();
          _isDirty = false;
          _syncState();

          if (context.mounted) {
            AppSnackbar.show(
              context,
              message: 'Producto guardado con éxito.',
              type: SnackbarType.success,
            );
          }
          return true;
        },
      );
    } catch (e) {
      debugPrint('Error saveProduct: $e');
      if (context.mounted) _showError(context, e.toString());
      return false;
    } finally {
      _isSaving = false;
      _syncState();
    }
  }

  void _showError(BuildContext context, String error) {
    if (!context.mounted) return;
    final errStr = error.toLowerCase();
    String msg = 'Ocurrió un error al guardar el producto.';
    if (errStr.contains('socketexception') ||
        errStr.contains('clientexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('timeout')) {
      msg = 'Error de red. Verifica tu conexión a internet e intenta de nuevo.';
    }
    AppSnackbar.show(context, message: msg, type: SnackbarType.error);
  }

  @override
  Future<void> close() async {
    nombreCtrl.dispose();
    costoCtrl.dispose();
    precioCtrl.dispose();
    precioMayorCtrl.dispose();
    cantidadMayorCtrl.dispose();
    descCtrl.dispose();
    for (final draft in variantDrafts) {
      draft.dispose();
    }
    for (final row in detailRows) {
      row.dispose();
    }
    for (final row in ingredientRows) {
      row.dispose();
    }
    super.close();
  }
}
