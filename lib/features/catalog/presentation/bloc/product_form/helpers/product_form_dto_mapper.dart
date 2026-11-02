import 'dart:async';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/helpers/product_form_seo_helper.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';

/// Helper desacoplado responsable del ensamblado de DTOs, validaciones comerciales
/// y mapeo de errores del backend para el formulario de producto.
class ProductFormDtoMapper {
  const ProductFormDtoMapper._();

  /// Parsea un texto con coma o punto a número decimal.
  static double? parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  /// Valida la integridad comercial de las variantes (SKU único, barcode único, precio > 0, etc.).
  static String? validateVariants(
    List<VariantDraftFormModel> drafts,
    bool hasMultipleVariants,
  ) {
    if (drafts.isEmpty) {
      return 'Agrega al menos una variante con su precio de venta.';
    }

    final seenSkus = <String, int>{};
    final seenBarcodes = <String, int>{};

    for (int i = 0; i < drafts.length; i++) {
      final v = drafts[i];
      final sku = v.sku.trim();
      if (sku.isNotEmpty) {
        if (seenSkus.containsKey(sku)) {
          final firstIndex = seenSkus[sku]! + 1;
          return 'El SKU "$sku" está repetido en la variante #$firstIndex y la variante #${i + 1}. Cada variante debe tener un SKU único.';
        }
        seenSkus[sku] = i;
      }

      final barcode = v.barcode.trim();
      if (barcode.isNotEmpty) {
        if (seenBarcodes.containsKey(barcode)) {
          final firstIndex = seenBarcodes[barcode]! + 1;
          return 'El código de barras "$barcode" está repetido en la variante #$firstIndex y la variante #${i + 1}.';
        }
        seenBarcodes[barcode] = i;
      }

      final p = parseDecimal(v.price);
      if (p == null || p <= 0) {
        return hasMultipleVariants
            ? 'Variante #${i + 1}: Ingresa un precio de venta válido (> 0).'
            : 'Ingresa un precio de venta válido (> 0).';
      }
      if (v.wholesalePrice.trim().isNotEmpty) {
        final wp = parseDecimal(v.wholesalePrice);
        if (wp == null || wp <= 0) {
          return hasMultipleVariants
              ? 'Variante #${i + 1}: El precio mayorista debe ser mayor a 0.'
              : 'El precio mayorista debe ser mayor a 0.';
        }
      }
      if (v.unitCost.trim().isNotEmpty) {
        final cost = parseDecimal(v.unitCost);
        if (cost == null || cost < 0) {
          return hasMultipleVariants
              ? 'Variante #${i + 1}: El costo unitario no puede ser negativo.'
              : 'El costo unitario no puede ser negativo.';
        }
      }
    }

    return null;
  }

  /// Valida que no existan ingredientes con selección incompleta.
  static String? validateIngredients(List<IngredientRowModel> ingredients) {
    final hasIncomplete = ingredients.any(
      (r) => r.ingredientId == null || r.ingredientId!.trim().isEmpty,
    );
    if (ingredients.isEmpty || hasIncomplete) {
      return 'Completa o elimina los componentes activos no seleccionados.';
    }
    return null;
  }

  /// Construye el payload completo [SaveProductPayload] para persistir en Supabase.
  static SaveProductPayload buildSavePayload({
    required ProductEntity? productToEdit,
    required String nombre,
    required String desc,
    required String? categoryId,
    required String? brandId,
    required String productType,
    required bool stockControl,
    required bool batchManagementEnabled,
    required bool isActive,
    required Map<String, bool> salesChannels,
    required String slug,
    required String seoTitle,
    required String seoDescription,
    required List<Map<String, dynamic>> changelog,
    required List<DetailModel> detailRows,
    required List<FormImageItem> formImages,
    required List<VariantDraftFormModel> variantDrafts,
    required List<String> removedVariantIds,
    required bool ingredientsEnabled,
    required List<IngredientRowModel> ingredientRows,
    required String? profileId,
  }) {
    final isUpdating = productToEdit != null;
    final firstVariant = variantDrafts.first;
    final salePrice = parseDecimal(firstVariant.price)!;
    final wholesalePriceVal = parseDecimal(firstVariant.wholesalePrice);

    final productEntity = ProductEntity(
      id: isUpdating ? productToEdit.id : '',
      name: nombre.trim(),
      isActive: isActive,
      description: desc.trim().isEmpty ? null : desc.trim(),
      categoryId: categoryId,
      brandId: brandId,
      details: {
        for (final d in detailRows)
          if (d.key.trim().isNotEmpty) d.key.trim(): d.value.trim(),
        'sales_channels': salesChannels,
        'slug':
            slug.trim().isEmpty
                ? ProductFormSeoHelper.slugify(nombre)
                : slug.trim(),
        'seo_title':
            seoTitle.trim().isEmpty
                ? ProductFormSeoHelper.defaultSeoTitle(nombre)
                : seoTitle.trim(),
        'seo_description': seoDescription.trim(),
        'changelog': changelog,
      },
      productType: productType,
      stockControl: stockControl,
      usesBatches: batchManagementEnabled,
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
            externalImageUrl: item.externalUrl,
          );
        }).toList();

    final variantsPayload =
        variantDrafts.map((draft) {
          final valueIds =
              draft.selectedAttributes
                  .map((attr) => attr['value_id'] as String)
                  .toList();
          final skuValue = draft.sku.trim();
          final barcodeValue = draft.barcode.trim();
          return VariantPayload(
            id: draft.id,
            sku: skuValue.isEmpty ? null : skuValue,
            barcode: barcodeValue.isEmpty ? null : barcodeValue,
            unitCost: parseDecimal(draft.unitCost) ?? 0.0,
            salePrice: parseDecimal(draft.price),
            wholesalePrice: parseDecimal(draft.wholesalePrice),
            wholesaleMinQuantity: int.tryParse(draft.wholesaleMinQuantity),
            reorderPoint: int.tryParse(draft.reorderPoint),
            isActive: draft.isActive,
            attributeValueIds: valueIds,
            clearImages:
                draft.id != null &&
                (draft.urlsExistentes.isEmpty &&
                    draft.nuevasImagenes.isEmpty &&
                    draft.externalImageUrl == null),
            newImageBytes:
                draft.nuevasImagenes.isNotEmpty
                    ? draft.nuevasImagenes.first
                    : null,
            externalImageUrl: draft.externalImageUrl,
          );
        }).toList();

    final ingredientsPayload =
        ingredientRows
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

    return SaveProductPayload(
      product: productEntity,
      profileId: profileId,
      isUpdating: isUpdating,
      baseSalePrice: salePrice,
      baseWholesalePrice: wholesalePriceVal,
      baseWholesaleMinQuantity:
          int.tryParse(firstVariant.wholesaleMinQuantity) ?? 3,
      images: imagesPayload,
      removedVariantIds: removedVariantIds.toList(),
      variants: variantsPayload,
      ingredientsEnabled: ingredientsEnabled,
      ingredients: ingredientsPayload,
    );
  }

  /// Transforma excepciones y fallos de base de datos a mensajes legibles para el usuario.
  static String parseNetworkError(Object e) {
    if (e is TimeoutException) {
      return e.message ?? 'La operación tardó demasiado. Intenta de nuevo.';
    }
    final s = e.toString();
    final sLower = s.toLowerCase();
    if (sLower.contains('23505') ||
        sLower.contains('unique_violation') ||
        sLower.contains('ya existe')) {
      return 'El código o SKU ingresado ya existe en la base de datos.';
    }
    if (sLower.contains('socketexception') ||
        sLower.contains('clientexception') ||
        sLower.contains('failed host lookup') ||
        sLower.contains('timeout')) {
      return 'Error de red. Verifica tu conexión e intenta de nuevo.';
    }
    if (s.contains('PostgrestException') || s.contains('code:')) {
      final match = RegExp(r'message:\s*([^,)]+)').firstMatch(s);
      if (match != null && match.group(1) != null) {
        return 'Error BD (${match.group(1)!.trim()})';
      }
      return 'Error en Supabase: $s';
    }
    if (e is String &&
        e.isNotEmpty &&
        e != 'Ocurrió un error al guardar el producto.') {
      return e;
    }
    return 'Ocurrió un error al guardar el producto: $s';
  }
}
