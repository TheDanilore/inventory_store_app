import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/variant_draft.dart';
import 'package:inventory_store_app/screens/admin/widgets/variant_draft_card.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class FormularioScreen extends StatefulWidget {
  final ProductModel? productToEdit;
  const FormularioScreen({super.key, this.productToEdit});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nombreCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _precioMayorCtrl = TextEditingController();
  final _cantidadMayorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // NUEVO: Controladores dinámicos para Detalles del Producto (JSON)
  final List<_DetailControllers> _detailRows = [];

  // Estados
  String? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  bool _loadingVariants = false;
  bool _guardando = false;

  // ── Configuración del Producto ─────────────────────────────────────────────
  String _productType = 'good';
  bool _stockControl = true;

  // ── Gestión por Lotes ──────────────────────────────────────────────────────
  bool _batchManagementEnabled = false;

  // ── Ingredientes Activos ───────────────────────────────────────────────────
  bool _ingredientsEnabled = false;
  final List<_IngredientRow> _ingredientRows = [];

  // Imágenes y Variantes
  final List<FormImageItem> _formImages = [];
  final List<VariantDraft> _variantDrafts = [];
  final List<String> _removedVariantIds = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProductImages();
    _loadInitialData();
  }

  // ── Cargar ingredientes existentes ─────────────────────────────────────────
  Future<void> _fetchIngredients(String productId) async {
    final resp = await Supabase.instance.client
        .from('product_active_ingredients')
        .select('ingredient_id, concentration, unit, active_ingredients(name)')
        .eq('product_id', productId);

    if (!mounted) return;
    setState(() {
      _ingredientRows.clear();
      for (final row in (resp as List)) {
        final activeIng = row['active_ingredients'] as Map<String, dynamic>?;
        _ingredientRows.add(
          _IngredientRow(
            ingredientId: row['ingredient_id'] as String, // <-- CAMBIO AQUÍ
            name: activeIng?['name'] as String? ?? '',
            concentration: row['concentration']?.toString() ?? '',
            unit: row['unit'] as String? ?? '',
          ),
        );
      }
      if (_ingredientRows.isNotEmpty) _ingredientsEnabled = true;
    });
  }

  void _loadInitialData() {
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nombreCtrl.text = p.name;
      _costoCtrl.text = p.unitCost.toString();
      _precioCtrl.text = p.salePrice.toString();
      _precioMayorCtrl.text = p.wholesalePrice?.toString() ?? '';
      _cantidadMayorCtrl.text = p.wholesaleMinQuantity.toString();
      _descCtrl.text = p.description ?? '';
      _selectedCategoryId = p.categoryId;

      // Asignar los nuevos campos de la base de datos
      _productType = p.productType;
      _stockControl = p.stockControl;
      _batchManagementEnabled = p.usesBatches;

      if (p.details.isNotEmpty) {
        p.details.forEach((key, value) {
          _detailRows.add(
            _DetailControllers(
              keyCtrl: TextEditingController(text: key),
              valueCtrl: TextEditingController(text: value.toString()),
            ),
          );
        });
      }

      _fetchVariants();
      _fetchIngredients(p.id);
    } else {
      _cantidadMayorCtrl.text = '3';
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('categories')
          .select()
          .eq('is_active', true);
      if (mounted) {
        setState(() {
          _categories =
              (response as List).map((e) => CategoryModel.fromJson(e)).toList();
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _fetchVariants() async {
    final productId = widget.productToEdit?.id;
    if (productId == null) return;

    setState(() => _loadingVariants = true);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('product_variants')
          .select(
            '*, product_images(*), reorder_point, wholesale_price, wholesale_min_quantity',
          )
          .eq('product_id', productId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final drafts =
          (response as List).map((item) {
            final variant = ProductVariantModel.fromJson(
              Map<String, dynamic>.from(item),
            );
            final draft = VariantDraft.fromVariant(variant);
            final List<dynamic> imagesData = item['product_images'] ?? [];
            draft.urlsExistentes =
                imagesData.map((img) => img['image_url'] as String).toList();
            return draft;
          }).toList();

      setState(() {
        _variantDrafts.clear();
        _variantDrafts.addAll(drafts);
      });
    } catch (e) {
      debugPrint('Error cargando variantes: $e');
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudieron cargar las variantes existentes.',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingVariants = false);
    }
  }

  Future<void> _fetchProductImages() async {
    if (widget.productToEdit?.id == null) return;

    final response = await Supabase.instance.client
        .from('product_images')
        .select('*')
        .eq('product_id', widget.productToEdit!.id)
        .isFilter('variant_id', null)
        .order('display_order', ascending: true);

    if (mounted) {
      setState(() {
        _formImages.clear();
        _formImages.addAll(
          (response as List).map(
            (e) => FormImageItem(
              existing: ProductImageModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            ),
          ),
        );
      });
    }
  }

  Future<void> _seleccionarImagenes() async {
    final picker = ImagePicker();
    final archivos = await picker.pickMultiImage();

    if (archivos.isNotEmpty) {
      var duplicadas = 0;
      final nuevosItems = <FormImageItem>[];

      for (final archivo in archivos) {
        final nombre = _normalizarNombreArchivo(archivo);

        // Evitar duplicados
        if (_formImages.any(
          (img) => !img.isExisting && img.newName == nombre,
        )) {
          duplicadas++;
          continue;
        }

        final bytesOriginales = await archivo.readAsBytes();
        final bytesOptimizados = await _optimizarImagen(bytesOriginales);

        nuevosItems.add(
          FormImageItem(newBytes: bytesOptimizados, newName: nombre),
        );
      }

      setState(() => _formImages.addAll(nuevosItems));

      if (duplicadas > 0 && mounted) {
        AppSnackbar.show(
          context,
          message: '$duplicadas imagen(es) repetida(s) omitidas.',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    final item = _formImages[index];

    // Si es una imagen que ya estaba en la Base de Datos, la borramos físicamente
    if (item.isExisting) {
      try {
        final supabase = Supabase.instance.client;
        final parts = item.existing!.imageUrl.split('/public/productos/');

        if (parts.length > 1) {
          final pathToRemove = parts.last;
          await supabase.storage.from('productos').remove([pathToRemove]);
        }
        await supabase
            .from('product_images')
            .delete()
            .eq('id', item.existing!.id);

        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Imagen eliminada',
            backgroundColor: AppColors.success,
          );
        }
      } catch (e) {
        debugPrint('Error al eliminar imagen: $e');
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al eliminar',
            backgroundColor: AppColors.error,
          );
        }
        return; // Si falla el borrado, no la quitamos de la UI
      }
    }

    setState(() => _formImages.removeAt(index));
  }

  void _addVariantDraft() {
    setState(() {
      _variantDrafts.add(VariantDraft());
    });
  }

  Future<void> _removeVariantDraft(int index) async {
    final draft = _variantDrafts[index];

    if (draft.id == null) {
      setState(() {
        draft.dispose();
        _variantDrafts.removeAt(index);
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('order_items')
          .select('id')
          .eq('variant_id', draft.id!)
          .limit(1);

      if ((response as List).isNotEmpty) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message:
              "No se puede eliminar: Esta variante tiene ventas asociadas.",
          backgroundColor: Colors.red,
        );
        return;
      }

      // ── NUEVO: Borrar la imagen de la variante del Bucket físico primero ──
      final oldImages = await supabase
          .from('product_images')
          .select('image_url')
          .eq('variant_id', draft.id!);

      for (final oldImg in oldImages) {
        final url = oldImg['image_url'] as String;
        final parts = url.split('/public/productos/');
        if (parts.length > 1) {
          final pathToRemove =
              parts.last; // Obtiene 'variantes/nombre_archivo.jpg'
          await supabase.storage.from('productos').remove([pathToRemove]);
        }
      }
      // ──────────────────────────────────────────────────────────────────────

      // Eliminar la variante de la base de datos (esto también borra en cascada de product_images)
      await supabase.from('product_variants').delete().eq('id', draft.id!);

      setState(() {
        draft.dispose();
        _variantDrafts.removeAt(index);
      });

      AppSnackbar.show(
        // ignore: use_build_context_synchronously
        context,
        message: "Variante y su imagen eliminadas correctamente.",
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      AppSnackbar.show(context, message: "Error al intentar eliminar: $e");
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _precioMayorCtrl.dispose();
    _cantidadMayorCtrl.dispose();
    _descCtrl.dispose();
    for (final draft in _variantDrafts) {
      draft.dispose();
    }
    for (final row in _detailRows) {
      row.dispose();
    }
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVariantImage(VariantDraft draft) async {
    final picker = ImagePicker();
    // Pedimos la imagen original sin tocar
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytesOriginales = await file.readAsBytes();

      // La pasamos por nuestro optimizador inteligente
      final bytesOptimizados = await _optimizarImagen(bytesOriginales);

      setState(() {
        draft.urlsExistentes.clear();
        draft.nuevasImagenes.clear();
        draft.nuevasImagenes.add(bytesOptimizados);
      });
    }
  }

  Future<Uint8List> _optimizarImagen(Uint8List bytesOriginales) async {
    // 1. Si pesa menos de 250 KB, pasa directo.
    if (bytesOriginales.lengthInBytes < 250 * 1024) {
      return bytesOriginales;
    }

    try {
      // 2. Intentamos comprimir nativamente
      final bytesComprimidos = await FlutterImageCompress.compressWithList(
        bytesOriginales,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      // A veces si falla silenciosamente devuelve un arreglo vacío
      if (bytesComprimidos.isNotEmpty &&
          bytesComprimidos.lengthInBytes < bytesOriginales.lengthInBytes) {
        return bytesComprimidos; // ¡Éxito!
      }
    } catch (e) {
      debugPrint('Error interno de compresión: $e');
      // NUEVO: Mostrar alerta en pantalla para saber por qué falla
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al comprimir: $e',
          backgroundColor: Colors.red,
        );
      }
    }

    // Fallback de seguridad: devuelve la original si todo lo demás falla
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

  String? _validateUnitCost(String? value) {
    final parsed = _parseDecimal(value ?? '');
    if (parsed == null) return 'Ingresa un costo valido';
    if (parsed <= 0) return 'El costo debe ser mayor a 0';
    return null;
  }

  String? _validateSalePrice(String? value) {
    final salePrice = _parseDecimal(value ?? '');
    if (salePrice == null) return 'Ingresa un precio de venta valido';
    if (salePrice <= 0) return 'El precio de venta debe ser mayor a 0';

    final unitCost = _parseDecimal(_costoCtrl.text);
    if (unitCost != null && salePrice < unitCost) {
      return 'El precio de venta no puede ser menor al costo';
    }
    return null;
  }

  String? _validateWholesalePrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final wholesalePrice = _parseDecimal(text);
    if (wholesalePrice == null) return 'Ingresa un precio mayorista valido';
    if (wholesalePrice <= 0) return 'El precio mayorista debe ser mayor a 0';

    final unitCost = _parseDecimal(_costoCtrl.text);
    if (unitCost != null && wholesalePrice < unitCost) {
      return 'El precio mayorista no puede ser menor al costo';
    }

    final salePrice = _parseDecimal(_precioCtrl.text);
    if (salePrice != null && wholesalePrice > salePrice) {
      return 'El precio mayorista no puede ser mayor al precio de venta';
    }
    return null;
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    final skus = _variantDrafts
        .where((d) => d.skuCtrl.text.trim().isNotEmpty)
        .map((d) => d.skuCtrl.text.trim().toLowerCase());

    if (skus.toSet().length != skus.length) {
      AppSnackbar.show(
        context,
        message: "Hay SKUs duplicados en las variantes.",
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _guardando = true);
    await Future.delayed(const Duration(milliseconds: 150));

    final supabase = Supabase.instance.client;

    try {
      // NUEVO: Generar el JSON de detalles a partir de las filas dinámicas
      final Map<String, String> detailsMap = {};
      for (final row in _detailRows) {
        final key = row.keyCtrl.text.trim();
        final value = row.valueCtrl.text.trim();
        if (key.isNotEmpty) {
          detailsMap[key] = value;
        }
      }

      // 1. Guardar/Actualizar Producto Padre
      final isUpdating = widget.productToEdit != null;
      final unitCost = _parseDecimal(_costoCtrl.text)!;
      final salePrice = _parseDecimal(_precioCtrl.text)!;
      final wholesalePrice =
          _precioMayorCtrl.text.trim().isEmpty
              ? null
              : _parseDecimal(_precioMayorCtrl.text);

      // ── SOLUCIÓN: Buscar el ID del Profile en lugar de usar el Auth ID ──
      final authUserId = supabase.auth.currentUser?.id;
      String? profileId;

      if (authUserId != null) {
        final profileResp =
            await supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();

        if (profileResp != null) {
          profileId = profileResp['id'] as String;
        } else {
          // Opcional: Manejar el caso donde el usuario no tiene perfil creado
          throw Exception("No se encontró un perfil para este usuario.");
        }
      }

      final mapData = {
        'name': _nombreCtrl.text.trim(),
        'unit_cost': unitCost,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'wholesale_min_quantity':
            _cantidadMayorCtrl.text.trim().isEmpty
                ? 3
                : (int.tryParse(_cantidadMayorCtrl.text) ?? 3),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'category_id': _selectedCategoryId,
        'details': detailsMap,
        // ── NUEVOS CAMPOS ENVIADOS A LA BD ──
        'product_type': _productType,
        'stock_control': _stockControl,
        'uses_batches': _batchManagementEnabled,
        // ────────────────────────────────────
        if (isUpdating && profileId != null) 'updated_by': profileId,
        if (!isUpdating && profileId != null) 'created_by': profileId,
      };
      String productId;
      if (isUpdating) {
        productId = widget.productToEdit!.id;
        await supabase.from('products').update(mapData).eq('id', productId);
      } else {
        final res =
            await supabase
                .from('products')
                .insert(mapData)
                .select('id')
                .single();
        productId = res['id'] as String;
      }

      // 2. Procesar imágenes principales (Orden y Portada)

      // PASO CLAVE: Si estamos actualizando, quitamos temporalmente todas las
      // portadas para evitar que el índice único de BD choque durante el reordenamiento.
      if (isUpdating && _formImages.isNotEmpty) {
        await supabase
            .from('product_images')
            .update({'is_main': false})
            .eq('product_id', productId);
      }

      for (var i = 0; i < _formImages.length; i++) {
        final item = _formImages[i];
        final isMain = (i == 0); // La primera imagen siempre será la portada

        if (item.isExisting) {
          // Solo actualiza su orden y estado principal
          await supabase
              .from('product_images')
              .update({'display_order': i, 'is_main': isMain})
              .eq('id', item.existing!.id);
        } else {
          // Sube la imagen nueva y la registra con su posición correcta
          final url = await _uploadImageToStorage(item.newBytes!, 'productos');
          if (url != null) {
            await supabase.from('product_images').insert({
              'product_id': productId,
              'image_url': url,
              'display_order': i,
              'is_main': isMain,
            });
          }
        }
      }

      for (final variantId in _removedVariantIds) {
        await supabase
            .from('product_variants')
            .update({'is_active': false})
            .eq('id', variantId);
      }
      _removedVariantIds.clear();

      // 3. Procesar Variantes y sus imágenes
      String primaryVariantId = ''; // Variable clave para vincular lotes

      if (_variantDrafts.isEmpty) {
        // CREAR VARIANTE POR DEFECTO SILENCIOSAMENTE
        if (isUpdating) {
          final vResp =
              await supabase
                  .from('product_variants')
                  .select('id')
                  .eq('product_id', productId)
                  .limit(1)
                  .maybeSingle();
          if (vResp != null) {
            primaryVariantId = vResp['id'] as String;
          }
        } else {
          final payload = {
            'product_id': productId,
            'attributes': {'Variante': 'Única'},
            'sale_price': salePrice,
            'wholesale_price': wholesalePrice,
            'wholesale_min_quantity':
                _cantidadMayorCtrl.text.trim().isEmpty
                    ? 3
                    : (int.tryParse(_cantidadMayorCtrl.text) ?? 3),
            'is_active': true,
            if (profileId != null) 'created_by': profileId,
          };
          final res =
              await supabase
                  .from('product_variants')
                  .insert(payload)
                  .select('id')
                  .single();
          primaryVariantId = res['id'] as String;
        }
      } else {
        for (var i = 0; i < _variantDrafts.length; i++) {
          final draft = _variantDrafts[i];

          Map<String, dynamic> attrsMap = {};
          if (draft.attributesCtrl.text.trim().isNotEmpty) {
            try {
              attrsMap = jsonDecode(draft.attributesCtrl.text.trim());
            } catch (e) {
              debugPrint('Error decodificando atributos JSON: $e');
            }
          }

          final skuValue = draft.skuCtrl.text.trim();
          final payload = {
            'sku': skuValue.isEmpty ? null : skuValue,
            'attributes': attrsMap,
            'sale_price': _parseDecimal(draft.priceCtrl.text),
            'wholesale_price': _parseDecimal(draft.wholesalePriceCtrl.text),
            'wholesale_min_quantity': int.tryParse(
              draft.wholesaleMinQuantityCtrl.text,
            ),
            'reorder_point': int.tryParse(draft.reorderPointCtrl.text),
            'is_active': draft.isActive,
            if (draft.id != null && profileId != null) 'updated_by': profileId,
            if (draft.id == null && profileId != null) 'created_by': profileId,
          };

          if (draft.id != null) {
            await supabase
                .from('product_variants')
                .update(payload)
                .eq('id', draft.id!);
            if (i == 0) primaryVariantId = draft.id!;

            if (draft.urlsExistentes.isEmpty ||
                draft.nuevasImagenes.isNotEmpty) {
              final oldImages = await supabase
                  .from('product_images')
                  .select('image_url')
                  .eq('variant_id', draft.id!);
              for (final oldImg in oldImages) {
                final url = oldImg['image_url'] as String;
                final parts = url.split('/public/productos/');
                if (parts.length > 1) {
                  final pathToRemove = parts.last;
                  await supabase.storage.from('productos').remove([
                    pathToRemove,
                  ]);
                }
              }
              await supabase
                  .from('product_images')
                  .delete()
                  .eq('variant_id', draft.id!);
            }

            if (draft.nuevasImagenes.isNotEmpty) {
              final bytes = draft.nuevasImagenes.first;
              final url = await _uploadImageToStorage(bytes, 'variantes');
              if (url != null) {
                await supabase.from('product_images').insert({
                  'product_id': productId,
                  'variant_id': draft.id,
                  'image_url': url,
                  'is_main': false,
                });
              }
            }
          } else {
            // INSERCIÓN DE NUEVA VARIANTE
            final res =
                await supabase
                    .from('product_variants')
                    .insert({...payload, 'product_id': productId})
                    .select('id')
                    .single();

            // CORRECCIÓN: Usamos una variable local en lugar de intentar mutar draft.id
            final newVariantId = res['id'] as String;

            if (i == 0) primaryVariantId = newVariantId;

            if (draft.nuevasImagenes.isNotEmpty) {
              final bytes = draft.nuevasImagenes.first;
              final url = await _uploadImageToStorage(bytes, 'variantes');
              if (url != null) {
                await supabase.from('product_images').insert({
                  'product_id': productId,
                  'variant_id': newVariantId, // Usamos la variable local aquí
                  'image_url': url,
                  'is_main': false,
                });
              }
            }
          }
        }
      }

      // ── 4. Guardar ingredientes activos ────────────────────────────────
      if (_ingredientsEnabled) {
        // Borramos las relaciones previas
        await supabase
            .from('product_active_ingredients')
            .delete()
            .eq('product_id', productId);

        for (final row in _ingredientRows) {
          // Validamos que tenga un ingrediente válido seleccionado
          if (row.ingredientId == null || row.nameCtrl.text.trim().isEmpty)
            continue;

          // Simplemente vinculamos el ingrediente al producto
          final payload = {
            'product_id': productId,
            'ingredient_id':
                row.ingredientId, // <-- USA EL ID QUE VIENE DEL BUSCADOR
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

          await supabase.from('product_active_ingredients').insert(payload);
        }
      } else {
        await supabase
            .from('product_active_ingredients')
            .delete()
            .eq('product_id', productId);
      }

      // ELIMINADO: Bloque 5 de Guardar Lotes. La creación del producto solo define "uses_batches".
      // Los lotes reales se registran al recibir mercadería en el almacén.

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Producto guardado exitosamente',
          backgroundColor: AppColors.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error: $e',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<String?> _uploadImageToStorage(Uint8List bytes, String folder) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${bytes.hashCode}.jpg';
      final path = '$folder/$fileName';
      await Supabase.instance.client.storage
          .from('productos')
          .uploadBinary(path, bytes);
      return Supabase.instance.client.storage
          .from('productos')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title:
          widget.productToEdit != null ? 'Editar Producto' : 'Nuevo Producto',
      showBackButton: true,
      showProfileButton: false,
      body:
          _guardando
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── NUEVO: Botón superior para guardar rápido ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _guardarProducto,
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: Text(
                            widget.productToEdit != null
                                ? 'Actualizar'
                                : 'Guardar',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ───────────────────────────────────────────────
                      _buildSectionCard(
                        title: 'Imágenes del Producto',
                        child: _buildImageGallery(),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Información Básica',
                        child: _buildBasicInfo(),
                      ),
                      const SizedBox(height: 16),
                      // ── NUEVA SECCIÓN DE CONFIGURACIÓN ──
                      _buildSectionCard(
                        title: 'Configuración',
                        child: _buildConfigInfo(),
                      ),
                      const SizedBox(height: 16),
                      // ────────────────────────────────────
                      _buildSectionCard(
                        title: 'Detalles y Especificaciones',
                        child: _buildDetailsInfo(),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Precios e Inventario',
                        child: _buildPricingInfo(),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Ingredientes Activos / Componentes',
                        child: _buildIngredientsSection(),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Gestión por Lotes',
                        child: _buildBatchSection(),
                      ),
                      const SizedBox(height: 16),
                      _buildVariantsSection(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: AppPrimaryButton(
                          label:
                              widget.productToEdit != null
                                  ? 'Actualizar Producto'
                                  : 'Guardar Producto',
                          onPressed: _guardarProducto,
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mantén presionada una imagen para moverla, o arrástrala rápidamente usando el ícono de las rayas.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              // Botón de agregar fijo a la izquierda
              InkWell(
                onTap: _seleccionarImagenes,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Agregar',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Lista horizontal reordenable
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles:
                      false, // Apagamos el default para controlarlo
                  proxyDecorator: (child, index, animation) {
                    // Este decorador hace que la imagen se "levante" con sombra al moverla
                    return Material(
                      color: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                  itemCount: _formImages.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _formImages.removeAt(oldIndex);
                      _formImages.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _formImages[index];
                    final isMain = index == 0;

                    return Container(
                      key: ValueKey(item.id),
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isMain ? AppColors.primary : Colors.grey.shade300,
                          width: isMain ? 2.5 : 1,
                        ),
                      ),
                      // Permite hacer scroll normal, y arrastrar solo si mantienes presionado
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Imagen
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  item.isExisting
                                      ? Image.network(
                                        item.existing!.imageUrl,
                                        fit: BoxFit.cover,
                                      )
                                      : Image.memory(
                                        item.newBytes!,
                                        fit: BoxFit.cover,
                                      ),
                            ),

                            // 2. Sombreado superior para que los botones blancos siempre se lean
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 35,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 3. NUEVO: Botón de arrastre instantáneo (Drag Handle)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: ReorderableDragStartListener(
                                index: index,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.drag_indicator_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // 4. Etiqueta de Portada
                            if (isMain)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.9,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(9),
                                      bottomRight: Radius.circular(9),
                                    ),
                                  ),
                                  child: const Text(
                                    'PORTADA',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                            // 5. Botón eliminar (X)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      children: [
        AppTextField(
          controller: _nombreCtrl,
          label: 'Nombre del producto',
          icon: Icons.inventory_2_outlined,
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        _loadingCategories
            ? const CircularProgressIndicator()
            : DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Categoría',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                ..._categories.map(
                  (cat) =>
                      DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                ),
              ],
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _descCtrl,
          label: 'Descripción general',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildConfigInfo() {
    // Si es servicio, forzamos visualmente a false
    final bool isService = _productType == 'service';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _productType,
          decoration: InputDecoration(
            labelText: 'Tipo de Producto',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'good',
              child: Text('Bien Físico (Producto)'),
            ),
            DropdownMenuItem(value: 'service', child: Text('Servicio')),
            DropdownMenuItem(value: 'digital', child: Text('Producto Digital')),
          ],
          onChanged: (val) {
            setState(() {
              _productType = val ?? 'good';
              // LÓGICA AUTOMÁTICA: Si es servicio, apagamos stock y lotes
              if (_productType == 'service') {
                _stockControl = false;
                _batchManagementEnabled = false;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(
            'Control de Stock',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  isService
                      ? Colors.grey
                      : AppColors.textPrimary, // Se pone gris si es servicio
            ),
          ),
          subtitle: Text(
            isService
                ? 'Los servicios no llevan control de inventario'
                : 'Llevar el conteo de inventario para este producto',
            style: TextStyle(
              fontSize: 12,
              color: isService ? Colors.grey : AppColors.textSecondary,
            ),
          ),
          value:
              isService ? false : _stockControl, // Siempre falso si es servicio
          // Si es servicio, pasamos null para deshabilitar el botón
          onChanged:
              isService ? null : (val) => setState(() => _stockControl = val),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // NUEVO: Interfaz para los Detalles Técnicos Dinámicos
  Widget _buildDetailsInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Agrega detalles como Marca, Material, Medidas, etc.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _detailRows.add(
                    _DetailControllers(
                      keyCtrl: TextEditingController(),
                      valueCtrl: TextEditingController(),
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir detalle'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_detailRows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Sin detalles adicionales',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _detailRows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final row = _detailRows[idx];
              return Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: row.keyCtrl,
                      decoration: InputDecoration(
                        hintText: 'Propiedad (ej: Material)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ':',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: row.valueCtrl,
                      decoration: InputDecoration(
                        hintText: 'Valor (ej: Acero)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _detailRows[idx].dispose();
                        _detailRows.removeAt(idx);
                      });
                    },
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildPricingInfo() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _costoCtrl,
                label: 'Costo (S/.)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: _validateUnitCost,
                onChanged: (_) => _formKey.currentState?.validate(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _precioCtrl,
                label: 'Precio Venta (S/.)',
                icon: Icons.sell_outlined,
                keyboardType: TextInputType.number,
                validator: _validateSalePrice,
                onChanged: (_) => _formKey.currentState?.validate(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _precioMayorCtrl,
                label: 'Precio Mayorista',
                icon: Icons.local_offer_outlined,
                keyboardType: TextInputType.number,
                validator: _validateWholesalePrice,
                onChanged: (_) => _formKey.currentState?.validate(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _cantidadMayorCtrl,
                label: 'Cant. Mínima',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final parsed = int.tryParse(text);
                  if (parsed == null) return 'Inválido';
                  if (parsed < 1) return 'Mayor a 0';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariantsSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Variantes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: _addVariantDraft,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingVariants)
          const CircularProgressIndicator()
        else if (_variantDrafts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
            ),
          )
        else ...[
          ...List.generate(_variantDrafts.length, (index) {
            return VariantDraftCard(
              index: index,
              draft: _variantDrafts[index],
              onRemove: () => _removeVariantDraft(index),
              onActiveChanged:
                  (val) => setState(() => _variantDrafts[index].isActive = val),
              onPickImage: () => _pickVariantImage(_variantDrafts[index]),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addVariantDraft,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Agregar otra variante'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── WIDGET: Gestión por Lotes ──────────────────────────────────────────────
  Widget _buildBatchSection() {
    // NUEVA VALIDACIÓN: Si es servicio, ocultamos la sección por completo
    if (_productType == 'service') {
      return const SizedBox.shrink(); // Retorna un widget vacío invisible
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:
            _batchManagementEnabled
                ? Colors.teal.withValues(alpha: 0.07)
                : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            color: _batchManagementEnabled ? Colors.teal : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _batchManagementEnabled
                      ? 'Gestión por lotes habilitada'
                      : 'Sin gestión por lotes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _batchManagementEnabled
                            ? Colors.teal.shade700
                            : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Requerirá número de lote y vencimiento al ingresar stock en el Módulo de Inventario.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _batchManagementEnabled,
            onChanged: (v) => setState(() => _batchManagementEnabled = v),
            activeColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                _ingredientsEnabled
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  _ingredientsEnabled
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.science_rounded,
                color: _ingredientsEnabled ? AppColors.primary : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestión de componentes activos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            _ingredientsEnabled
                                ? AppColors.primary
                                : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Permite buscar este producto por componente químico',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _ingredientsEnabled,
                onChanged: (v) => setState(() => _ingredientsEnabled = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
        if (_ingredientsEnabled) ...[
          const SizedBox(height: 14),
          if (_ingredientRows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Sin componentes. Agrega uno con el botón.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ingredientRows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final row = _ingredientRows[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                // Abre el buscador interactivo
                                final result =
                                    await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      builder:
                                          (_) =>
                                              const _IngredientSearchDialog(),
                                    );

                                // Si seleccionó o creó uno, actualizamos la UI
                                if (result != null) {
                                  setState(() {
                                    row.ingredientId = result['id'] as String;
                                    row.nameCtrl.text =
                                        result['name'] as String;
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                // AbsorbPointer hace que el TextField sea de solo lectura para abrir el Dialog
                                child: TextField(
                                  controller: row.nameCtrl,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Componente / Ingrediente Activo *',
                                    hintText: 'Toca para buscar o crear...',
                                    isDense: true,
                                    suffixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppColors.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                () => setState(() {
                                  row.dispose();
                                  _ingredientRows.removeAt(idx);
                                }),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.concentrationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Concentración (Nro)',
                                hintText: 'Ej: 500',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.unitCtrl,
                              decoration: InputDecoration(
                                labelText: 'Unidad de medida',
                                hintText: 'Ej: mg',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  () => setState(() => _ingredientRows.add(_IngredientRow())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar componente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── NUEVA CLASE: Helper para mantener el estado de los controladores dinámicos
class _DetailControllers {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  _DetailControllers({required this.keyCtrl, required this.valueCtrl});

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

// ── Modelo: fila de ingrediente ────────────────────────────────────────────────
class _IngredientRow {
  String? ingredientId; // <-- Ahora guardará el ID real de la base de datos
  final TextEditingController nameCtrl;
  final TextEditingController concentrationCtrl;
  final TextEditingController unitCtrl;

  _IngredientRow({
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

// ─── DIALOGO INTERACTIVO DE BÚSQUEDA Y CREACIÓN DE INGREDIENTES ──────────────

class _IngredientSearchDialog extends StatefulWidget {
  const _IngredientSearchDialog();

  @override
  State<_IngredientSearchDialog> createState() =>
      _IngredientSearchDialogState();
}

class _IngredientSearchDialogState extends State<_IngredientSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  void _search(String term) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (term.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      try {
        final res = await Supabase.instance.client
            .from('active_ingredients')
            .select('id, name')
            .ilike('name', '%${term.trim()}%')
            .order('name')
            .limit(10);

        if (mounted) {
          setState(() {
            _results = List<Map<String, dynamic>>.from(res);
            _hasSearched = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _createIngredient() async {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // 1. Doble validación: Evitar que alguien cree uno que ya exista exactamente igual
      final exist =
          await Supabase.instance.client
              .from('active_ingredients')
              .select('id, name')
              .ilike('name', name)
              .maybeSingle();

      if (exist != null) {
        if (mounted) Navigator.pop(context, exist);
        return;
      }

      // 2. Insertamos el nuevo ingrediente en su tabla
      final res =
          await Supabase.instance.client
              .from('active_ingredients')
              .insert({'name': name})
              .select('id, name')
              .single();

      // 3. Devolvemos el ingrediente creado para que se seleccione automáticamente
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buscar Componente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Ej: Paracetamol, Clorpirifos...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // ESTADO: Cargando
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            // ESTADO: No se encontró nada (Botón de crear)
            else if (_hasSearched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.science_outlined,
                        size: 36,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se encontró "${_searchCtrl.text}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '¿Deseas agregar este ingrediente activo a la base de datos?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _createIngredient,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text(
                        'Sí, crear ingrediente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            // ESTADO: Resultados encontrados
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder:
                      (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.science_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              )
            // ESTADO: Inicial (Vacío)
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Escribe para buscar...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
