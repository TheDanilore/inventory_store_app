import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/features/catalog/data/models/category_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart';
import 'package:inventory_store_app/features/catalog/data/repositories/product_form_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

// Clases de utilidad locales para el Provider
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
  final ProductImageModel? existing;
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
  }) : nameCtrl = TextEditingController(text: name),
       concentrationCtrl = TextEditingController(text: concentration),
       unitCtrl = TextEditingController(text: unit);

  void dispose() {
    nameCtrl.dispose();
    concentrationCtrl.dispose();
    unitCtrl.dispose();
  }
}

class ProductFormProvider extends ChangeNotifier {
  final ProductFormService _service;
  ProductModel? _productToEdit;

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
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;

  // Flags de progreso
  bool _isInitializingData = false;
  bool _isSaving = false;
  bool _isDirty = false;

  ProductFormProvider({ProductFormService? service})
    : _service = service ?? ProductFormService();

  bool _hasErrorLoading = false;
  String _errorMessage = '';

  // Getters
  bool get isInitializingData => _isInitializingData;
  bool get hasErrorLoading => _hasErrorLoading;
  String get errorMessage => _errorMessage;

  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _isDirty;
  bool get isLoadingCategories => _isLoadingCategories;
  List<CategoryModel> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;

  String get productType => _productType;
  bool get stockControl => _stockControl;
  bool get batchManagementEnabled => _batchManagementEnabled;
  bool get ingredientsEnabled => _ingredientsEnabled;

  ProductModel? get productToEdit => _productToEdit;

  // Setters
  void setProductType(String type) {
    _productType = type;
    if (_productType == 'service') {
      _stockControl = false;
      _batchManagementEnabled = false;
    }
    markAsDirty();
    notifyListeners();
  }

  void setStockControl(bool val) {
    _stockControl = val;
    markAsDirty();
    notifyListeners();
  }

  void setBatchManagement(bool val) {
    _batchManagementEnabled = val;
    markAsDirty();
    notifyListeners();
  }

  void setIngredientsEnabled(bool val) {
    _ingredientsEnabled = val;
    markAsDirty();
    notifyListeners();
  }

  void setSelectedCategory(String? id) {
    _selectedCategoryId = id;
    markAsDirty();
    notifyListeners();
  }

  void markAsDirty() {
    if (!_isDirty) {
      _isDirty = true;
    }
  }

  // --- Inicialización ---

  Future<void> initData(ProductModel? product) async {
    _productToEdit = product;
    _isInitializingData = true;
    _hasErrorLoading = false;
    _errorMessage = '';
    notifyListeners();

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
      notifyListeners();
    }
  }

  Future<void> _fetchCategories() async {
    _categories = await _service.fetchCategories();
    _isLoadingCategories = false;
    notifyListeners();
  }

  Future<void> _fetchProductImages(String productId) async {
    final images = await _service.fetchProductImages(productId);
    formImages.addAll(images.map((img) => FormImageItem(existing: img)));
    notifyListeners();
  }

  Future<void> _fetchIngredients(String productId) async {
    final list = await _service.fetchIngredients(productId);
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
    notifyListeners();
  }

  Future<void> _fetchVariants(String productId) async {
    try {
      final drafts = await _service.fetchVariants(productId);
      variantDrafts.addAll(drafts);
    } catch (e) {
      // El error se silencia o se maneja en el provider. Aquí lo notificaremos por Snackbar desde UI idealmente.
    }
    notifyListeners();
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
    notifyListeners();
  }

  void removeDetailRow(int index) {
    detailRows[index].dispose();
    detailRows.removeAt(index);
    markAsDirty();
    notifyListeners();
  }

  void addIngredientRow() {
    ingredientRows.add(IngredientRow());
    markAsDirty();
    notifyListeners();
  }

  void removeIngredientRow(int index) {
    ingredientRows[index].dispose();
    ingredientRows.removeAt(index);
    markAsDirty();
    notifyListeners();
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
      notifyListeners();

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
        await _service.deleteProductImage(
          item.existing!.id,
          item.existing!.imageUrl,
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
    notifyListeners();
  }

  void reorderImages(int oldIndex, int newIndex) {
    final item = formImages.removeAt(oldIndex);
    formImages.insert(newIndex, item);
    markAsDirty();
    notifyListeners();
  }

  // --- Variantes ---

  void addVariantDraft() {
    variantDrafts.add(VariantDraftModel());
    markAsDirty();
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> removeVariantDraft(BuildContext context, int index) async {
    final draft = variantDrafts[index];

    if (draft.id == null) {
      draft.dispose();
      variantDrafts.removeAt(index);
      markAsDirty();
      notifyListeners();
      return;
    }

    try {
      final hasSales = await _service.hasVariantSales(draft.id!);
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

      await _service.deleteVariant(draft.id!);
      draft.dispose();
      variantDrafts.removeAt(index);
      markAsDirty();
      notifyListeners();

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
      notifyListeners();
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
    notifyListeners();

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

      final mapData = {
        'name': nombreCtrl.text.trim(),
        'unit_cost': unitCost,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'wholesale_min_quantity':
            cantidadMayorCtrl.text.trim().isEmpty
                ? 3
                : (int.tryParse(cantidadMayorCtrl.text) ?? 3),
        'description':
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'category_id': _selectedCategoryId,
        'details': detailsMap,
        'product_type': _productType,
        'stock_control': _stockControl,
        'uses_batches': _batchManagementEnabled,
      };

      final String productId = await _service.saveProductMaster(
        productId: isUpdating ? _productToEdit!.id : null,
        productData: mapData,
      );

      // Imágenes del Producto
      final imagesPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < formImages.length; i++) {
        final item = formImages[i];
        final isMain = (i == 0);

        if (item.isExisting) {
          imagesPayload.add({
            'id': item.existing!.id,
            'product_id': productId,
            'image_url': item.existing!.imageUrl,
            'display_order': i,
            'is_main': isMain,
          });
        } else {
          final url = await _service.uploadImageToStorage(
            item.newBytes!,
            'productos',
          );
          if (url != null) {
            imagesPayload.add({
              'product_id': productId,
              'image_url': url,
              'display_order': i,
              'is_main': isMain,
            });
          }
        }
      }

      if (imagesPayload.isNotEmpty) {
        await _service.syncProductImages(imagesPayload);
      }

      // Variantes Eliminadas
      for (final variantId in _removedVariantIds) {
        await _service.deactivateVariant(variantId);
      }
      _removedVariantIds.clear();

      // Variantes
      String primaryVariantId = '';

      if (variantDrafts.isEmpty) {
        if (isUpdating) {
          final vid = await _service.getFirstVariantId(productId);
          if (vid != null) {
            primaryVariantId = vid;
            await _service.saveVariantAttributes(primaryVariantId, []);
          }
        } else {
          final payload = {
            'sale_price': salePrice,
            'wholesale_price': wholesalePrice,
            'wholesale_min_quantity':
                cantidadMayorCtrl.text.trim().isEmpty
                    ? 3
                    : (int.tryParse(cantidadMayorCtrl.text) ?? 3),
            'is_active': true,
          };
          primaryVariantId = await _service.saveVariant(
            productId: productId,
            variantData: payload,
          );
          await _service.saveVariantAttributes(primaryVariantId, []);
        }
      } else {
        for (var i = 0; i < variantDrafts.length; i++) {
          final draft = variantDrafts[i];
          final valueIds =
              draft.selectedAttributes
                  .map((attr) => attr['value_id'] as String)
                  .toList();

          final skuValue = draft.skuCtrl.text.trim();
          final payload = {
            'sku': skuValue.isEmpty ? null : skuValue,
            'unit_cost': _parseDecimal(draft.unitCostCtrl.text) ?? 0.0,
            'sale_price': _parseDecimal(draft.priceCtrl.text),
            'wholesale_price': _parseDecimal(draft.wholesalePriceCtrl.text),
            'wholesale_min_quantity': int.tryParse(
              draft.wholesaleMinQuantityCtrl.text,
            ),
            'reorder_point': int.tryParse(draft.reorderPointCtrl.text),
            'is_active': draft.isActive,
          };

          final vId = await _service.saveVariant(
            productId: productId,
            variantData: payload,
            variantId: draft.id,
          );

          if (i == 0) primaryVariantId = vId;
          await _service.saveVariantAttributes(vId, valueIds);

          if (draft.id != null) {
            if (draft.urlsExistentes.isEmpty ||
                draft.nuevasImagenes.isNotEmpty) {
              await _service.clearVariantImages(vId);
            }
          }

          if (draft.nuevasImagenes.isNotEmpty) {
            final bytes = draft.nuevasImagenes.first;
            final url = await _service.uploadImageToStorage(bytes, 'variantes');
            if (url != null) {
              await _service.syncProductImages([
                {
                  'product_id': productId,
                  'variant_id': vId,
                  'image_url': url,
                  'display_order': 0,
                  'is_main': false,
                },
              ]);
            }
          }
        }
      }

      // Ingredientes
      if (_ingredientsEnabled) {
        await _service.clearProductIngredients(productId);

        for (final row in ingredientRows) {
          if (row.ingredientId == null || row.nameCtrl.text.trim().isEmpty) {
            continue;
          }

          final payload = {
            'product_id': productId,
            'ingredient_id': row.ingredientId,
            'concentration':
                row.concentrationCtrl.text.trim().isEmpty
                    ? null
                    : double.tryParse(
                      row.concentrationCtrl.text.trim().replaceAll(',', '.'),
                    ),
            'unit':
                row.unitCtrl.text.trim().isEmpty
                    ? null
                    : row.unitCtrl.text.trim(),
          };

          await _service.insertProductIngredient(payload);
        }
      } else {
        await _service.clearProductIngredients(productId);
      }

      _isDirty = false;
      notifyListeners();

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Producto guardado con éxito.',
          type: SnackbarType.success,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error saveProduct: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Ocurrió un error al guardar el producto.';
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('timeout')) {
          msg =
              'Error de red. Verifica tu conexión a internet e intenta de nuevo.';
        }
        AppSnackbar.show(context, message: msg, type: SnackbarType.error);
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
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
    super.dispose();
  }
}
