import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class VariantDraftModel {
  final String? id;

  // ── Campos básicos ──────────────────────────────────────────────────────────
  final TextEditingController skuCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController wholesalePriceCtrl;
  final TextEditingController wholesaleMinQuantityCtrl;
  final TextEditingController reorderPointCtrl;
  final TextEditingController unitCostCtrl;

  // ── Atributos nuevos (tablas estructuradas) ─────────────────────────────────
  /// IDs de [attribute_values] seleccionados para esta variante.
  /// Se guardan en [variant_attribute_values].
  List<String> selectedAttributeValueIds;

  bool isActive;

  // ── Imágenes ────────────────────────────────────────────────────────────────
  List<Uint8List> nuevasImagenes;
  List<String> urlsExistentes;

  VariantDraftModel({
    this.id,
    String? sku,
    String? barcode,
    List<String>? attributeValueIds,
    String? price,
    String? wholesalePrice,
    String? wholesaleMinQuantity,
    String? reorderPoint,
    String? unitCost,
    List<String>? urlsExistentes,
    List<Uint8List>? nuevasImagenes,
    this.isActive = true,
  }) : skuCtrl = TextEditingController(text: sku ?? ''),
       barcodeCtrl = TextEditingController(text: barcode ?? ''),
       priceCtrl = TextEditingController(text: price ?? ''),
       wholesalePriceCtrl = TextEditingController(text: wholesalePrice ?? ''),
       wholesaleMinQuantityCtrl = TextEditingController(
         text: wholesaleMinQuantity ?? '',
       ),
       reorderPointCtrl = TextEditingController(text: reorderPoint ?? '3'),
       unitCostCtrl = TextEditingController(text: unitCost ?? ''),
       selectedAttributeValueIds = attributeValueIds ?? [],
       urlsExistentes = urlsExistentes ?? [],
       nuevasImagenes = nuevasImagenes ?? [];

  // ── Desde modelo existente ──────────────────────────────────────────────────
  factory VariantDraftModel.fromVariant(ProductVariantModel variant) {
    return VariantDraftModel(
      id: variant.id,
      sku: variant.sku,
      barcode: variant.barcode,
      attributeValueIds:
          variant.attributeValues.map((av) => av.attributeValueId).toList(),
      price: variant.salePrice?.toString() ?? '',
      wholesalePrice: variant.wholesalePrice?.toString() ?? '',
      wholesaleMinQuantity: variant.wholesaleMinQuantity?.toString() ?? '',
      reorderPoint: variant.reorderPoint.toString(),
      unitCost: variant.unitCost?.toString() ?? '',
      urlsExistentes:
          variant.images.isNotEmpty ? [variant.images.first.imageUrl] : [],
      isActive: variant.isActive,
    );
  }

  // ── Payload para Supabase ───────────────────────────────────────────────────
  Map<String, dynamic> toPayload() {
    return {
      if (id != null) 'id': id,
      'sku': skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
      'barcode':
          barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
      'sale_price': _parseDecimal(priceCtrl.text),
      'wholesale_price': _parseDecimal(wholesalePriceCtrl.text),
      'wholesale_min_quantity': _parseInt(wholesaleMinQuantityCtrl.text),
      'reorder_point': _parseInt(reorderPointCtrl.text) ?? 3,
      'unit_cost': _parseDecimal(unitCostCtrl.text),
      'is_active': isActive,
    };
  }

  static double? _parseDecimal(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static int? _parseInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  // ── Limpieza ────────────────────────────────────────────────────────────────
  void dispose() {
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    wholesalePriceCtrl.dispose();
    wholesaleMinQuantityCtrl.dispose();
    reorderPointCtrl.dispose();
    unitCostCtrl.dispose();
  }
}
