import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';

class VariantDraftFormModel {
  final String? id;

  // ── Campos básicos ──────────────────────────────────────────────────────────
  final TextEditingController skuCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController wholesalePriceCtrl;
  final TextEditingController wholesaleMinQuantityCtrl;
  final TextEditingController reorderPointCtrl;
  final TextEditingController unitCostCtrl;

  // ── Atributos (Adaptado a nueva BD relacional con UUIDs) ───────────────────
  /// Lista que mantiene los atributos en memoria durante la edición
  /// Formato esperado: [{'attribute_id': 'uuid...', 'attribute_name': 'Color', 'value_id': 'uuid...', 'value_name': 'Rojo'}]
  List<Map<String, dynamic>> selectedAttributes;

  bool isActive;

  // ── Imágenes ────────────────────────────────────────────────────────────────
  List<Uint8List> nuevasImagenes;
  List<String> urlsExistentes;

  VariantDraftFormModel({
    this.id,
    String? sku,
    String? barcode,
    List<Map<String, dynamic>>? selectedAttributes,
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
       selectedAttributes = selectedAttributes ?? [],
       urlsExistentes = urlsExistentes ?? [],
       nuevasImagenes = nuevasImagenes ?? [];

  // ── Desde entidad existente ──────────────────────────────────────────────────
  factory VariantDraftFormModel.fromEntity(VariantDraftEntity variant) {
    return VariantDraftFormModel(
      id: variant.id,
      sku: variant.sku,
      barcode: variant.barcode,
      selectedAttributes: variant.selectedAttributes,
      price: variant.price,
      wholesalePrice: variant.wholesalePrice,
      wholesaleMinQuantity: variant.wholesaleMinQuantity,
      reorderPoint: variant.reorderPoint,
      unitCost: variant.unitCost,
      urlsExistentes: variant.urlsExistentes,
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
