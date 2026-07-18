import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_image_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_variant_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/save_product_usecase.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
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

  String _productType = 'good';
  bool _stockControl = true;
  bool _batchManagementEnabled = false;
  bool _ingredientsEnabled = false;

  String? _selectedCategoryId;
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = true;

  bool _isInitializingData = false;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _hasErrorLoading = false;
  String _errorMessage = '';

  List<DetailModel> _detailRows = [];
  List<IngredientRowModel> _ingredientRows = [];
  List<FormImageItem> _formImages = [];
  List<VariantDraftFormModel> _variantDrafts = [];
  final List<String> _removedVariantIds = [];

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
  ) : super(ProductFormState.initial());

  // ── Getters ──────────────────────────────────────────────────────────────────
  bool get isInitializingData => _isInitializingData;
  bool get hasErrorLoading => _hasErrorLoading;
  String get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _isDirty;
  ProductEntity? get productToEdit => _productToEdit;

  // ── Setters de configuración ─────────────────────────────────────────────────
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
        detailRows: List.of(_detailRows),
        ingredientRows: List.of(_ingredientRows),
        formImages: List.of(_formImages),
        variantDrafts: List.of(_variantDrafts),
        removedVariantIds: List.of(_removedVariantIds),
        clearSnacks: true,
      ),
    );
  }

  void markAsDirty() {
    if (!_isDirty) _isDirty = true;
  }

  // ── Inicialización ───────────────────────────────────────────────────────────

  /// Carga los datos iniciales del formulario a partir de la entidad de producto.
  /// Retorna los valores iniciales de los controllers como [ProductFormInitialValues]
  /// para que la pantalla los inyecte en sus propios [TextEditingController].
  Future<ProductFormInitialValues> loadInitialData(
    ProductEntity? product,
  ) async {
    _productToEdit = product;
    _isInitializingData = true;
    _hasErrorLoading = false;
    _errorMessage = '';
    _detailRows = [];
    _ingredientRows = [];
    _formImages = [];
    _variantDrafts = [];
    _syncState();

    // Valores de texto para los controllers de la pantalla
    String nombre = '';
    String costo = '';
    String precio = '';
    String precioMayor = '';
    String cantidadMayor = '3';
    String desc = '';

    try {
      if (product != null) {
        nombre = product.name;
        costo = product.unitCost.toString();
        precio = product.salePrice.toString();
        precioMayor = product.wholesalePrice?.toString() ?? '';
        cantidadMayor = product.wholesaleMinQuantity.toString();
        desc = product.description ?? '';
        _selectedCategoryId = product.categoryId;
        _productType = product.productType;
        _stockControl = product.stockControl;
        _batchManagementEnabled = product.usesBatches;

        product.details.forEach((key, value) {
          _detailRows.add(DetailModel(key: key, value: value.toString()));
        });

        await Future.wait([
          _fetchCategories(),
          _fetchProductImages(product.id),
          _fetchIngredients(product.id),
          _fetchVariants(product.id),
        ]);
      } else {
        await _fetchCategories();
      }
    } catch (e) {
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

    return ProductFormInitialValues(
      nombre: nombre,
      costo: costo,
      precio: precio,
      precioMayor: precioMayor,
      cantidadMayor: cantidadMayor,
      desc: desc,
    );
  }

  Future<void> _fetchCategories() async {
    _categories = await _unwrap(_getCategoriesUC.call());
    _isLoadingCategories = false;
    _syncState();
  }

  Future<void> _fetchProductImages(String productId) async {
    final images = await _unwrap(_getProductImagesUC.call(productId));
    final productImagesOnly =
        images.where((img) => img.variantId == null).toList();
    _formImages.addAll(
      productImagesOnly.map((img) => FormImageItem(existing: img)),
    );
    _syncState();
  }

  Future<void> _fetchIngredients(String productId) async {
    final list = await _unwrap(_getProductIngredientsUC.call(productId));
    for (final row in list) {
      final activeIng = row['active_ingredients'] as Map<String, dynamic>?;
      _ingredientRows.add(
        IngredientRowModel(
          ingredientId: row['ingredient_id'] as String,
          name: activeIng?['name'] as String? ?? '',
          concentration: row['concentration']?.toString() ?? '',
          unit: row['unit'] as String? ?? '',
        ),
      );
    }
    if (_ingredientRows.isNotEmpty) _ingredientsEnabled = true;
    _syncState();
  }

  Future<void> _fetchVariants(String productId) async {
    try {
      final drafts = await _unwrap(_getVariantsDraftsUC.call(productId));
      _variantDrafts.addAll(drafts.map(VariantDraftFormModel.fromEntity));
    } catch (_) {}
    _syncState();
  }

  // ── Detalles ─────────────────────────────────────────────────────────────────

  void addDetailRow() {
    _detailRows = [..._detailRows, DetailModel()];
    markAsDirty();
    _syncState();
  }

  void removeDetailRow(int index) {
    _detailRows = List.of(_detailRows)..removeAt(index);
    markAsDirty();
    _syncState();
  }

  // ── Ingredientes ─────────────────────────────────────────────────────────────

  void addIngredientRow() {
    _ingredientRows = [..._ingredientRows, IngredientRowModel()];
    markAsDirty();
    _syncState();
  }

  void removeIngredientRow(int index) {
    _ingredientRows = List.of(_ingredientRows)..removeAt(index);
    markAsDirty();
    _syncState();
  }

  /// Actualiza los datos de una fila de ingrediente desde la UI.
  void updateIngredientRow(int index, IngredientRowModel updated) {
    final rows = List.of(_ingredientRows);
    rows[index] = updated;
    _ingredientRows = rows;
    markAsDirty();
    _syncState();
  }

  // ── Imágenes ─────────────────────────────────────────────────────────────────

  /// Abre el selector de imágenes y procesa las seleccionadas.
  /// El resultado (mensajes de advertencia) se emite como estado — sin [BuildContext].
  Future<void> pickImages() async {
    final picker = ImagePicker();
    final archivos = await picker.pickMultiImage();
    if (archivos.isEmpty) return;

    const maxImages = 5;
    final currentCount = _formImages.length;

    if (currentCount >= maxImages) {
      emit(
        state.copyWith(
          snackMessage: 'Límite de imágenes alcanzado ($maxImages).',
        ),
      );
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
      if (_formImages.any((img) => !img.isExisting && img.newName == nombre)) {
        duplicadas++;
        continue;
      }

      final bytesOriginales = await archivo.readAsBytes();
      final bytesOptimizados = await _optimizarImagen(bytesOriginales);
      nuevosItems.add(
        FormImageItem(newBytes: bytesOptimizados, newName: nombre),
      );
    }

    _formImages = [..._formImages, ...nuevosItems];
    markAsDirty();

    String? snackMsg;
    if (duplicadas > 0 || excedidas > 0) {
      String msg = '';
      if (duplicadas > 0) msg += '$duplicadas repetida(s). ';
      if (excedidas > 0) msg += '$excedidas exceden el límite de $maxImages.';
      snackMsg = msg.trim();
    }

    emit(
      state.copyWith(
        formImages: List.of(_formImages),
        isDirty: _isDirty,
        snackMessage: snackMsg,
      ),
    );
  }

  Future<void> removeImage(int index) async {
    final item = _formImages[index];

    if (item.isExisting) {
      try {
        await _unwrap(
          _deleteProductImageUC.call(
            item.existing!.id,
            item.existing!.imageUrl,
          ),
        );
      } catch (e) {
        emit(state.copyWith(snackError: _parseNetworkError(e)));
        return;
      }
    }

    _formImages = List.of(_formImages)..removeAt(index);
    markAsDirty();
    emit(
      state.copyWith(
        formImages: List.of(_formImages),
        isDirty: _isDirty,
        snackMessage: item.isExisting ? 'Imagen eliminada.' : null,
      ),
    );
  }

  void reorderImages(int oldIndex, int newIndex) {
    final list = List.of(_formImages);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _formImages = list;
    markAsDirty();
    _syncState();
  }

  // ── Variantes ────────────────────────────────────────────────────────────────

  void addVariantDraft() {
    _variantDrafts = [..._variantDrafts, VariantDraftFormModel()];
    markAsDirty();
    _syncState();
  }

  void duplicateVariantDraft(int index) {
    final original = _variantDrafts[index];
    final copiedAttributes =
        original.selectedAttributes
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
    final copy = original.copyWith(
      id: null,
      sku: original.sku.isNotEmpty ? '${original.sku}-COPY' : '',
      reorderPoint: original.reorderPoint,
      unitCost: original.unitCost,
      price: original.price,
      wholesalePrice: original.wholesalePrice,
      wholesaleMinQuantity: original.wholesaleMinQuantity,
      isActive: original.isActive,
      selectedAttributes: copiedAttributes,
      urlsExistentes: List.of(original.urlsExistentes),
      nuevasImagenes: List.of(original.nuevasImagenes),
    );
    final list = List.of(_variantDrafts)..insert(index + 1, copy);
    _variantDrafts = list;
    markAsDirty();
    _syncState();
  }

  Future<void> removeVariantDraft(int index) async {
    final draft = _variantDrafts[index];

    if (draft.id == null) {
      _variantDrafts = List.of(_variantDrafts)..removeAt(index);
      markAsDirty();
      _syncState();
      return;
    }

    try {
      final hasSales = await _unwrap(_hasVariantSalesUC(draft.id!));
      if (hasSales) {
        emit(
          state.copyWith(
            snackError:
                'No se puede eliminar: Esta variante tiene ventas asociadas.',
          ),
        );
        return;
      }

      await _unwrap(_deleteVariantUC.call(draft.id!));
      _variantDrafts = List.of(_variantDrafts)..removeAt(index);
      markAsDirty();
      emit(
        state.copyWith(
          variantDrafts: List.of(_variantDrafts),
          isDirty: _isDirty,
          snackMessage: 'Variante y su imagen eliminadas correctamente.',
        ),
      );
    } catch (e) {
      emit(state.copyWith(snackError: _parseNetworkError(e)));
    }
  }

  Future<void> pickVariantImage(int index) async {
    final draft = _variantDrafts[index];
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytesOriginales = await file.readAsBytes();
      final bytesOptimizados = await _optimizarImagen(bytesOriginales);

      final updated = draft.copyWith(
        urlsExistentes: [],
        nuevasImagenes: [bytesOptimizados],
      );
      final list = List.of(_variantDrafts);
      list[index] = updated;
      _variantDrafts = list;
      markAsDirty();
      _syncState();
    }
  }

  void updateVariantDraft(int index, VariantDraftFormModel updated) {
    final list = List.of(_variantDrafts);
    list[index] = updated;
    _variantDrafts = list;
    markAsDirty();
    _syncState();
  }

  // ── Guardado ─────────────────────────────────────────────────────────────────

  /// Guarda el producto. No recibe [BuildContext] ni [GlobalKey<FormState>].
  /// Los datos del formulario (controllers) son leídos por la pantalla y pasados
  /// como primitivos. El resultado se señala mediante [ProductFormState.saveSuccess]
  /// o [ProductFormState.snackError].
  Future<void> saveProduct({
    required String nombre,
    required String costo,
    required String precio,
    required String precioMayor,
    required String cantidadMayor,
    required String desc,
    required List<IngredientRowModel> ingredients,
  }) async {
    // Validación de SKUs duplicados (regla de negocio)
    final skus = _variantDrafts
        .where((d) => d.sku.trim().isNotEmpty)
        .map((d) => d.sku.trim().toLowerCase());
    if (skus.toSet().length != skus.length) {
      emit(state.copyWith(snackError: 'Hay SKUs duplicados en las variantes.'));
      return;
    }

    _isSaving = true;
    _syncState();

    try {
      final isUpdating = _productToEdit != null;
      final unitCost = _parseDecimal(costo)!;
      final salePrice = _parseDecimal(precio)!;
      final wholesalePriceVal =
          precioMayor.trim().isEmpty ? null : _parseDecimal(precioMayor);

      final profileIdRes = await _getCurrentProfileIdUC.call();
      final profileId = profileIdRes.fold((l) => null, (r) => r);

      final productEntity = ProductEntity(
        id: isUpdating ? _productToEdit!.id : '',
        name: nombre.trim(),
        unitCost: unitCost,
        salePrice: salePrice,
        wholesalePrice: wholesalePriceVal,
        wholesaleMinQuantity:
            cantidadMayor.trim().isEmpty
                ? 3
                : (int.tryParse(cantidadMayor) ?? 3),
        isActive: isUpdating ? _productToEdit!.isActive : true,
        description: desc.trim().isEmpty ? null : desc.trim(),
        categoryId: _selectedCategoryId,
        details: {
          for (final d in _detailRows)
            if (d.key.trim().isNotEmpty) d.key.trim(): d.value.trim(),
        },
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
          _formImages.map((item) {
            return ImagePayload(
              existingId: item.isExisting ? item.existing!.id : null,
              existingUrl: item.isExisting ? item.existing!.imageUrl : null,
              newBytes: item.newBytes,
            );
          }).toList();

      final variantsPayload =
          _variantDrafts.map((draft) {
            final valueIds =
                draft.selectedAttributes
                    .map((attr) => attr['value_id'] as String)
                    .toList();
            final skuValue = draft.sku.trim();
            return VariantPayload(
              id: draft.id,
              sku: skuValue.isEmpty ? null : skuValue,
              unitCost: _parseDecimal(draft.unitCost) ?? 0.0,
              salePrice: _parseDecimal(draft.price),
              wholesalePrice: _parseDecimal(draft.wholesalePrice),
              wholesaleMinQuantity: int.tryParse(draft.wholesaleMinQuantity),
              reorderPoint: int.tryParse(draft.reorderPoint),
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
          ingredients
              .where((r) => r.ingredientId != null && r.name.trim().isNotEmpty)
              .map(
                (row) => IngredientPayload(
                  ingredientId: row.ingredientId!,
                  concentration:
                      row.concentration.trim().isEmpty
                          ? null
                          : double.tryParse(
                            row.concentration.trim().replaceAll(',', '.'),
                          ),
                  unit: row.unit.trim().isEmpty ? null : row.unit.trim(),
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

      result.fold(
        (failure) {
          emit(state.copyWith(snackError: _parseNetworkError(failure.message)));
        },
        (_) {
          _removedVariantIds.clear();
          _isDirty = false;
          emit(
            state.copyWith(saveSuccess: true, isDirty: false, isSaving: false),
          );
        },
      );
    } catch (e) {
      emit(state.copyWith(snackError: _parseNetworkError(e)));
    } finally {
      _isSaving = false;
      // Solo sincronizamos si no fue un saveSuccess (que ya emitió estado)
      if (!state.saveSuccess) _syncState();
    }
  }

  // ── Helpers privados ─────────────────────────────────────────────────────────

  String _parseNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup') ||
        s.contains('timeout')) {
      return 'Error de red. Verifica tu conexión e intenta de nuevo.';
    }
    return 'Ocurrió un error al guardar el producto.';
  }

  Future<Uint8List> _optimizarImagen(Uint8List bytesOriginales) async {
    if (bytesOriginales.lengthInBytes < 250 * 1024) return bytesOriginales;
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
    } catch (_) {}
    return bytesOriginales;
  }

  String _normalizarNombreArchivo(XFile archivo) {
    final rawName = archivo.name.trim();
    if (rawName.isNotEmpty) return rawName.toLowerCase();
    final segments = archivo.path.split(RegExp(r'[/\\]'));
    return segments.isEmpty
        ? archivo.path.toLowerCase()
        : segments.last.toLowerCase();
  }

  double? _parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}

/// Valores de texto iniciales que el Cubit retorna a la pantalla para
/// inicializar sus propios [TextEditingController].
class ProductFormInitialValues {
  final String nombre;
  final String costo;
  final String precio;
  final String precioMayor;
  final String cantidadMayor;
  final String desc;

  const ProductFormInitialValues({
    required this.nombre,
    required this.costo,
    required this.precio,
    required this.precioMayor,
    required this.cantidadMayor,
    required this.desc,
  });
}
