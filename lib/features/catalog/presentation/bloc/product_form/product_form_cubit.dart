import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/helpers/product_form_dto_mapper.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/helpers/product_form_image_helper.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/helpers/product_form_seo_helper.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_brands_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_variant_ucs.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/save_product_usecase.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

@injectable
class ProductFormCubit extends Cubit<ProductFormState> {
  final GetCategoriesUC _getCategoriesUC;
  final GetBrandsUC _getBrandsUC;
  final GetProductByIdUC _getProductByIdUC;
  final GetProductIngredientsUC _getProductIngredientsUC;
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
  bool _hasMultipleVariants = false;

  String? _selectedCategoryId;
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = true;

  String? _selectedBrandId;
  List<BrandEntity> _brands = [];
  bool _isLoadingBrands = true;

  bool _isInitializingData = false;
  bool _isBackgroundSyncing = false;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _hasErrorLoading = false;
  String _errorMessage = '';

  List<DetailModel> _detailRows = [];
  List<IngredientRowModel> _ingredientRows = [];
  List<FormImageItem> _formImages = [];
  List<VariantDraftFormModel> _variantDrafts = [];
  final List<String> _removedVariantIds = [];

  // Omnicanalidad, Estado y SEO
  bool _isActive = true;
  Map<String, bool> _salesChannels = const {
    'web': true,
    'pos': true,
    'mercadolibre': true,
    'social': true,
  };
  String _slug = '';
  String _seoTitle = '';
  String _seoDescription = '';
  List<Map<String, dynamic>> _changelog = [];

  ProductFormCubit(
    this._getCategoriesUC,
    this._getBrandsUC,
    this._getProductByIdUC,
    this._getProductIngredientsUC,
    this._hasVariantSalesUC,
    this._getCurrentProfileIdUC,
    this._saveProductUC,
  ) : super(ProductFormState.initial());

  // ── Getters ──────────────────────────────────────────────────────────────────
  bool get isInitializingData => _isInitializingData;
  bool get isBackgroundSyncing => _isBackgroundSyncing;
  bool get hasErrorLoading => _hasErrorLoading;
  String get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _isDirty;
  bool get hasMultipleVariants => _hasMultipleVariants;
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

  void setHasMultipleVariants(bool val) {
    if (_hasMultipleVariants == val) return;
    _hasMultipleVariants = val;
    if (_variantDrafts.isEmpty) {
      _variantDrafts = [VariantDraftFormModel()];
    }
    markAsDirty();
    _syncState();
  }

  // ── Omnicanalidad, Estado y SEO ──────────────────────────────────────────
  void setIsActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    markAsDirty();
    _syncState();
  }

  void setPublicationStatus(String status) {
    setIsActive(status == 'active');
  }

  void toggleSalesChannel(String channelKey) {
    final channels = Map<String, bool>.from(_salesChannels);
    channels[channelKey] = !(channels[channelKey] ?? false);
    _salesChannels = channels;
    markAsDirty();
    _syncState();
  }

  void setSlug(String slug) {
    _slug = ProductFormSeoHelper.cleanSlug(slug);
    markAsDirty();
    _syncState();
  }

  void setSeoTitle(String title) {
    _seoTitle = title;
    markAsDirty();
    _syncState();
  }

  void setSeoDescription(String desc) {
    _seoDescription = desc;
    markAsDirty();
    _syncState();
  }

  void autoGenerateSlug(String name) {
    final slug = ProductFormSeoHelper.slugify(name);
    _slug = slug;
    if (_seoTitle.isEmpty) {
      _seoTitle = ProductFormSeoHelper.defaultSeoTitle(name);
    }
    markAsDirty();
    _syncState();
  }

  /// Actualiza los campos comerciales de la variante base (variante #0)
  /// en modo de producto simple.
  void updateDefaultVariant({
    String? sku,
    String? barcode,
    String? price,
    String? wholesalePrice,
    String? wholesaleMinQuantity,
    String? reorderPoint,
    String? unitCost,
    bool syncState = true,
  }) {
    if (_variantDrafts.isEmpty) {
      _variantDrafts = [VariantDraftFormModel()];
    }
    final current = _variantDrafts.first;
    final targetSku = sku ?? current.sku;
    final targetBarcode = barcode ?? current.barcode;
    final targetPrice = price ?? current.price;
    final targetWholesalePrice = wholesalePrice ?? current.wholesalePrice;
    final targetWholesaleMinQuantity =
        wholesaleMinQuantity ?? current.wholesaleMinQuantity;
    final targetReorderPoint = reorderPoint ?? current.reorderPoint;
    final targetUnitCost = unitCost ?? current.unitCost;

    final hasChanged =
        current.sku != targetSku ||
        current.barcode != targetBarcode ||
        current.price != targetPrice ||
        current.wholesalePrice != targetWholesalePrice ||
        current.wholesaleMinQuantity != targetWholesaleMinQuantity ||
        current.reorderPoint != targetReorderPoint ||
        current.unitCost != targetUnitCost;

    if (!hasChanged) return;

    _variantDrafts[0] = current.copyWith(
      sku: targetSku,
      barcode: targetBarcode,
      price: targetPrice,
      wholesalePrice: targetWholesalePrice,
      wholesaleMinQuantity: targetWholesaleMinQuantity,
      reorderPoint: targetReorderPoint,
      unitCost: targetUnitCost,
    );
    markAsDirty();
    if (syncState) {
      _syncState();
    }
  }

  /// Si el usuario desmarca "Tiene múltiples variantes" y existen varias variantes,
  /// conserva la primera variante y programa las demás para remoción.
  void revertToSingleVariant() {
    if (_variantDrafts.isNotEmpty) {
      for (int i = 1; i < _variantDrafts.length; i++) {
        final id = _variantDrafts[i].id;
        if (id != null && id.isNotEmpty) {
          _removedVariantIds.add(id);
        }
      }
      _variantDrafts = [
        _variantDrafts.first.copyWith(selectedAttributes: const []),
      ];
    } else {
      _variantDrafts = [VariantDraftFormModel()];
    }
    _hasMultipleVariants = false;
    markAsDirty();
    _syncState();
  }

  void setSelectedCategory(String? id) {
    _selectedCategoryId = id;
    markAsDirty();
    _syncState();
  }

  void setSelectedBrand(String? id) {
    _selectedBrandId = id;
    markAsDirty();
    _syncState();
  }

  void _syncState() {
    emit(
      state.copyWith(
        productToEdit: _productToEdit,
        isInitializingData: _isInitializingData,
        isBackgroundSyncing: _isBackgroundSyncing,
        hasErrorLoading: _hasErrorLoading,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        isDirty: _isDirty,
        isLoadingCategories: _isLoadingCategories,
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        isLoadingBrands: _isLoadingBrands,
        brands: _brands,
        selectedBrandId: _selectedBrandId,
        productType: _productType,
        stockControl: _stockControl,
        batchManagementEnabled: _batchManagementEnabled,
        ingredientsEnabled: _ingredientsEnabled,
        hasMultipleVariants: _hasMultipleVariants,
        isActive: _isActive,
        publicationStatus: _isActive ? 'active' : 'inactive',
        salesChannels: _salesChannels,
        slug: _slug,
        seoTitle: _seoTitle,
        seoDescription: _seoDescription,
        changelog: List.of(_changelog),
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
    if (!_isDirty) {
      _isDirty = true;
      emit(state.copyWith(isDirty: true));
    }
  }

  // ── Inicialización & Caché SWR ───────────────────────────────────────────────

  ({String nombre, String desc}) _hydrateProduct(ProductEntity targetProduct) {
    _productToEdit = targetProduct;
    final nombre = targetProduct.name;
    final desc = targetProduct.description ?? '';
    _selectedCategoryId = targetProduct.categoryId;
    _selectedBrandId = targetProduct.brandId;
    _productType = targetProduct.productType;
    _stockControl = targetProduct.stockControl;
    _batchManagementEnabled = targetProduct.usesBatches;

    _detailRows.clear();
    targetProduct.details.forEach((key, value) {
      if (![
        'publication_status',
        'sales_channels',
        'slug',
        'seo_title',
        'seo_description',
        'changelog',
      ].contains(key)) {
        _detailRows.add(DetailModel(key: key, value: value.toString()));
      }
    });

    final d = targetProduct.details;
    _isActive = targetProduct.isActive;
    if (d['sales_channels'] is Map) {
      final rawCh = d['sales_channels'] as Map;
      _salesChannels = {
        'web': rawCh['web'] != false,
        'pos': rawCh['pos'] != false,
        'mercadolibre': rawCh['mercadolibre'] != false,
        'social': rawCh['social'] != false,
      };
    } else {
      _salesChannels = const {
        'web': true,
        'pos': true,
        'mercadolibre': true,
        'social': true,
      };
    }
    _slug = (d['slug'] as String?) ?? ProductFormSeoHelper.slugify(nombre);
    _seoTitle =
        (d['seo_title'] as String?) ??
        ProductFormSeoHelper.defaultSeoTitle(nombre);
    _seoDescription =
        (d['seo_description'] as String?) ??
        ProductFormSeoHelper.defaultSeoDescription(desc);
    if (d['changelog'] is List) {
      _changelog =
          (d['changelog'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
    } else {
      _changelog = [
        {
          'action': 'Ficha creada e inventario registrado',
          'time':
              targetProduct.createdAt != null
                  ? '${targetProduct.createdAt!.day}/${targetProduct.createdAt!.month}/${targetProduct.createdAt!.year}'
                  : 'Fecha inicial',
          'author': targetProduct.createdBy ?? 'Admin',
        },
      ];
    }

    _formImages.clear();
    final productImagesOnly =
        targetProduct.images.where((img) => img.variantId == null).toList();
    _formImages.addAll(
      productImagesOnly.map((img) => FormImageItem(existing: img)),
    );

    _variantDrafts.clear();
    final drafts = targetProduct.productVariants.map(
      (v) => VariantDraftEntity.fromVariant(v),
    );
    _variantDrafts.addAll(drafts.map(VariantDraftFormModel.fromEntity));
    if (_variantDrafts.isEmpty) {
      _variantDrafts = [VariantDraftFormModel()];
    }
    _hasMultipleVariants =
        targetProduct.productVariants.length > 1 ||
        (targetProduct.productVariants.length == 1 &&
            targetProduct.productVariants.first.attributeValues.isNotEmpty);

    return (nombre: nombre, desc: desc);
  }

  void _initNewProduct() {
    _variantDrafts = [VariantDraftFormModel()];
    _hasMultipleVariants = false;
    _isActive = true;
    _salesChannels = const {
      'web': true,
      'pos': true,
      'mercadolibre': true,
      'social': true,
    };
    _slug = '';
    _seoTitle = '';
    _seoDescription = '';
    _changelog = [
      {
        'action': 'Borrador iniciado',
        'time': 'Ahora',
        'author': 'Usuario actual',
      },
    ];
  }

  ProductFormInitialValues? hydrateSyncIfCached(
    ProductEntity? product, {
    String? productId,
  }) {
    final effectiveId = product?.id ?? productId;
    final isEditing = effectiveId != null && effectiveId.isNotEmpty;

    final cachedCategories = _getCategoriesUC.getCached();
    final cachedBrands = _getBrandsUC.getCached();

    if (cachedCategories != null) {
      _categories = cachedCategories;
      _isLoadingCategories = false;
    }
    if (cachedBrands != null) {
      _brands = cachedBrands;
      _isLoadingBrands = false;
    }

    ProductEntity? cachedProduct = product;
    if (cachedProduct == null && isEditing) {
      cachedProduct = _getProductByIdUC.getCached(effectiveId);
    }

    // Zero-Shimmer Frame 0: Si tenemos categorías en RAM y (es producto nuevo o ya tenemos el producto)
    final canUseCache =
        _categories.isNotEmpty && (!isEditing || cachedProduct != null);

    if (canUseCache) {
      _isInitializingData = false;
      _isBackgroundSyncing = false;

      String nombre = '';
      String desc = '';

      if (isEditing && cachedProduct != null) {
        final hydrated = _hydrateProduct(cachedProduct);
        nombre = hydrated.nombre;
        desc = hydrated.desc;
      } else {
        _initNewProduct();
      }

      _syncState();
      return ProductFormInitialValues(nombre: nombre, desc: desc);
    }
    return null;
  }

  Future<ProductFormInitialValues> loadInitialData(
    ProductEntity? product, {
    String? productId,
  }) async {
    _hasErrorLoading = false;
    _errorMessage = '';
    _isDirty = false;

    final effectiveId = product?.id ?? productId;
    final isEditing = effectiveId != null && effectiveId.isNotEmpty;

    final cachedCategories = _getCategoriesUC.getCached();
    final cachedBrands = _getBrandsUC.getCached();

    if (cachedCategories != null) {
      _categories = cachedCategories;
      _isLoadingCategories = false;
    }
    if (cachedBrands != null) {
      _brands = cachedBrands;
      _isLoadingBrands = false;
    }

    ProductEntity? cachedProduct = product;
    if (cachedProduct == null && isEditing) {
      cachedProduct = _getProductByIdUC.getCached(effectiveId);
    }

    final canUseCache =
        _categories.isNotEmpty && (!isEditing || cachedProduct != null);

    if (canUseCache) {
      _isInitializingData = false;
      _isBackgroundSyncing = true;

      String nombre = '';
      String desc = '';

      if (isEditing && cachedProduct != null) {
        final hydrated = _hydrateProduct(cachedProduct);
        nombre = hydrated.nombre;
        desc = hydrated.desc;
      } else {
        _initNewProduct();
      }

      _syncState();

      // Revalidación en segundo plano respetando TTL de categorías y marcas
      unawaited(_backgroundRevalidate(effectiveId));

      return ProductFormInitialValues(nombre: nombre, desc: desc);
    }

    // Cold start (sin caché L1 suficiente): Carga inicial completa
    _isInitializingData = true;
    _isBackgroundSyncing = false;
    _syncState();

    String nombre = '';
    String desc = '';

    try {
      ProductEntity? targetProduct = product;
      if (isEditing) {
        final fullProduct = await _unwrap(_getProductByIdUC.call(effectiveId));
        if (fullProduct != null) {
          targetProduct = fullProduct;
        } else {
          throw Exception('El servidor no devolvió el detalle del producto.');
        }
        final hydrated = _hydrateProduct(targetProduct);
        nombre = hydrated.nombre;
        desc = hydrated.desc;

        await Future.wait([
          _fetchCategories(),
          _fetchBrands(),
          _fetchIngredients(targetProduct.id),
        ]);
      } else {
        _initNewProduct();
        await Future.wait([_fetchCategories(), _fetchBrands()]);
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

    return ProductFormInitialValues(nombre: nombre, desc: desc);
  }

  Future<void> _backgroundRevalidate(String? effectiveId) async {
    try {
      // Optimización Egress: Solo solicitar categorías o marcas si no están presentes
      final futures = <Future<dynamic>>[];
      if (_categories.isEmpty) futures.add(_fetchCategories());
      if (_brands.isEmpty) futures.add(_fetchBrands());
      if (effectiveId != null && effectiveId.isNotEmpty) {
        futures.add(_getProductByIdUC.call(effectiveId, forceRefresh: true));
        futures.add(_fetchIngredients(effectiveId));
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (e, st) {
      LoggerService.w(
        'ProductFormCubit: Error menor en revalidación background (se mantienen datos de caché)',
        tag: 'PRODUCT_FORM_CUBIT',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isBackgroundSyncing = false;
      _syncState();
    }
  }

  Future<void> _fetchCategories({bool forceRefresh = false}) async {
    _categories = await _unwrap(
      _getCategoriesUC.call(forceRefresh: forceRefresh),
    );
    _isLoadingCategories = false;
    _syncState();
  }

  Future<void> _fetchBrands({bool forceRefresh = false}) async {
    try {
      _brands = await _unwrap(_getBrandsUC.call(forceRefresh: forceRefresh));
    } catch (e, st) {
      LoggerService.e(
        'Error al cargar marcas en ProductFormCubit',
        tag: 'PRODUCT_FORM_CUBIT',
        error: e,
        stackTrace: st,
      );
      if (_brands.isEmpty) _brands = [];
    }
    _isLoadingBrands = false;
    _syncState();
  }

  Future<void> _fetchIngredients(String productId) async {
    final list = await _unwrap(_getProductIngredientsUC.call(productId));
    _ingredientRows.clear();
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

  void updateDetailRow(
    int index,
    DetailModel updated, {
    bool syncState = false,
  }) {
    final rows = List.of(_detailRows);
    rows[index] = updated;
    _detailRows = rows;
    markAsDirty();
    if (syncState) _syncState();
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

  void updateIngredientRow(
    int index,
    IngredientRowModel updated, {
    bool syncState = false,
  }) {
    final rows = List.of(_ingredientRows);
    rows[index] = updated;
    _ingredientRows = rows;
    markAsDirty();
    if (syncState) _syncState();
  }

  // ── Imágenes ─────────────────────────────────────────────────────────────────

  Future<void> addDroppedFiles(List<XFile> archivos) async {
    final result = await ProductFormImageHelper.processAndAddImageFiles(
      archivos,
      _formImages,
    );
    _formImages = result.updatedImages;
    markAsDirty();
    emit(
      state.copyWith(
        formImages: List.of(_formImages),
        isDirty: _isDirty,
        snackMessage: result.feedbackMessage,
      ),
    );
  }

  Future<void> pickImages() async {
    final archivos = await ProductFormImageHelper.pickImages();
    if (archivos.isEmpty) return;

    final result = await ProductFormImageHelper.processAndAddImageFiles(
      archivos,
      _formImages,
    );
    _formImages = result.updatedImages;
    markAsDirty();
    emit(
      state.copyWith(
        formImages: List.of(_formImages),
        isDirty: _isDirty,
        snackMessage: result.feedbackMessage,
      ),
    );
  }

  void addImageUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    if (_formImages.length >= ProductFormImageHelper.maxImages) {
      emit(
        state.copyWith(
          snackMessage:
              'Límite de imágenes alcanzado (${ProductFormImageHelper.maxImages} fotos máximo).',
        ),
      );
      return;
    }

    _formImages = [..._formImages, FormImageItem(externalUrl: url)];
    markAsDirty();
    _syncState();
  }

  void removeImage(int index) {
    if (index < 0 || index >= _formImages.length) return;
    _formImages = List.of(_formImages)..removeAt(index);
    markAsDirty();
    emit(
      state.copyWith(
        formImages: List.of(_formImages),
        isDirty: _isDirty,
        snackMessage: 'Imagen removida del borrador.',
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
    if (index < 0 || index >= _variantDrafts.length) return;
    final draft = _variantDrafts[index];

    if (draft.id != null && draft.id!.isNotEmpty) {
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
      } catch (e) {
        emit(
          state.copyWith(snackError: ProductFormDtoMapper.parseNetworkError(e)),
        );
        return;
      }

      if (!_removedVariantIds.contains(draft.id!)) {
        _removedVariantIds.add(draft.id!);
      }
    }

    _variantDrafts = List.of(_variantDrafts)..removeAt(index);
    markAsDirty();
    emit(
      state.copyWith(
        variantDrafts: List.of(_variantDrafts),
        removedVariantIds: List.of(_removedVariantIds),
        isDirty: _isDirty,
        snackMessage: 'Variante removida del borrador.',
      ),
    );
  }

  Future<void> pickVariantImage(int index) async {
    final draft = _variantDrafts[index];
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytesOriginales = await file.readAsBytes();
      final bytesOptimizados = await ProductFormImageHelper.optimizeImageBytes(
        bytesOriginales,
      );

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

  void updateVariantDraft(
    int index,
    VariantDraftFormModel updated, {
    bool syncState = false,
  }) {
    if (index >= 0 && index < _variantDrafts.length) {
      final current = _variantDrafts[index];
      final isSame =
          current.sku == updated.sku &&
          current.barcode == updated.barcode &&
          current.price == updated.price &&
          current.wholesalePrice == updated.wholesalePrice &&
          current.wholesaleMinQuantity == updated.wholesaleMinQuantity &&
          current.reorderPoint == updated.reorderPoint &&
          current.unitCost == updated.unitCost &&
          current.isActive == updated.isActive &&
          current.externalImageUrl == updated.externalImageUrl &&
          listEquals(current.urlsExistentes, updated.urlsExistentes) &&
          current.nuevasImagenes.length == updated.nuevasImagenes.length &&
          current.selectedAttributes.length ==
              updated.selectedAttributes.length;

      if (isSame) return;

      _variantDrafts[index] = updated;
      markAsDirty();
      if (syncState) _syncState();
    }
  }

  // ── Guardado ─────────────────────────────────────────────────────────────────

  Future<void> saveProduct({
    required String nombre,
    required String desc,
    required List<IngredientRowModel> ingredients,
  }) async {
    final cleanNombre = nombre.trim();
    if (cleanNombre.isEmpty) {
      emit(
        state.copyWith(snackError: 'El nombre del producto es obligatorio.'),
      );
      return;
    }

    final variantError = ProductFormDtoMapper.validateVariants(
      _variantDrafts,
      _hasMultipleVariants,
    );
    if (variantError != null) {
      emit(state.copyWith(snackError: variantError));
      return;
    }

    final sourceIngredients =
        _ingredientRows.isNotEmpty ? _ingredientRows : ingredients;
    if (_ingredientsEnabled) {
      final ingError = ProductFormDtoMapper.validateIngredients(
        sourceIngredients,
      );
      if (ingError != null) {
        emit(state.copyWith(snackError: ingError));
        return;
      }
    }

    _isSaving = true;
    _syncState();

    try {
      final isUpdating = _productToEdit != null;
      final profileIdRes = await _getCurrentProfileIdUC.call();
      final profileId = profileIdRes.fold((l) => null, (r) => r);

      final updatedChangelog = List<Map<String, dynamic>>.from(_changelog);
      updatedChangelog.insert(0, {
        'action':
            isUpdating
                ? 'Ficha y datos actualizados'
                : 'Ficha creada e inventario registrado',
        'time': 'Hace unos momentos',
        'author': 'Usuario actual',
      });
      _changelog = updatedChangelog;

      final payload = ProductFormDtoMapper.buildSavePayload(
        productToEdit: _productToEdit,
        nombre: nombre,
        desc: desc,
        categoryId: _selectedCategoryId,
        brandId: _selectedBrandId,
        productType: _productType,
        stockControl: _stockControl,
        batchManagementEnabled: _batchManagementEnabled,
        isActive: _isActive,
        salesChannels: _salesChannels,
        slug: _slug,
        seoTitle: _seoTitle,
        seoDescription: _seoDescription,
        changelog: _changelog,
        detailRows: _detailRows,
        formImages: _formImages,
        variantDrafts: _variantDrafts,
        removedVariantIds: _removedVariantIds,
        ingredientsEnabled: _ingredientsEnabled,
        ingredientRows: sourceIngredients,
        profileId: profileId,
      );

      final result = await _saveProductUC.call(payload);

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              snackError: ProductFormDtoMapper.parseNetworkError(
                failure.message,
              ),
            ),
          );
        },
        (_) {
          _removedVariantIds.clear();
          _isDirty = false;
          emit(
            state.copyWith(saveSuccess: true, isDirty: false, isSaving: false),
          );
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error saving product',
        tag: 'PRODUCT_FORM_CUBIT',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(snackError: ProductFormDtoMapper.parseNetworkError(e)),
      );
    } finally {
      _isSaving = false;
      if (!state.saveSuccess) _syncState();
    }
  }
}

/// Valores de texto iniciales que el Cubit retorna a la pantalla para
/// inicializar sus propios [TextEditingController].
class ProductFormInitialValues {
  final String nombre;
  final String desc;

  const ProductFormInitialValues({required this.nombre, required this.desc});
}
