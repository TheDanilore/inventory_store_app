import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class VariantDraft {
  final String? id;
  final TextEditingController skuCtrl;
  final TextEditingController attributesCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController wholesalePriceCtrl;
  final TextEditingController wholesaleMinQuantityCtrl;
  final TextEditingController reorderPointCtrl;
  bool isActive;

  Uint8List? imageBytes; // Para fotos nuevas desde la galería
  String? imageUrlExistente; // Para fotos que ya están en Supabase

  List<Uint8List> nuevasImagenes = []; // Para fotos nuevas
  List<String> urlsExistentes = []; // Para fotos que ya están en la nube

  VariantDraft({
    this.id,
    String? sku,
    String? attributes,
    String? price,
    String? wholesalePrice,
    String? wholesaleMinQuantity,
    String? reorderPoint,
    this.imageUrlExistente,
    this.isActive = true,
  }) : skuCtrl = TextEditingController(text: sku ?? ''),
       attributesCtrl = TextEditingController(text: attributes ?? ''),
       priceCtrl = TextEditingController(text: price ?? ''),
       wholesalePriceCtrl = TextEditingController(text: wholesalePrice ?? ''),
       wholesaleMinQuantityCtrl = TextEditingController(
         text: wholesaleMinQuantity ?? '',
       ),
       reorderPointCtrl = TextEditingController(text: reorderPoint ?? '3');

  factory VariantDraft.fromVariant(ProductVariantModel variant) {
    return VariantDraft(
      id: variant.id,
      sku: variant.sku,
      attributes:
          variant.attributes.isEmpty ? '' : jsonEncode(variant.attributes),
      price: variant.salePrice?.toString() ?? '',
        wholesalePrice: variant.wholesalePrice?.toString() ?? '',
      wholesaleMinQuantity: variant.wholesaleMinQuantity?.toString() ?? '',
        reorderPoint: variant.reorderPoint.toString(),

      // Extrae la URL de la lista de imágenes si contiene elementos
      imageUrlExistente:
          variant.images.isNotEmpty ? variant.images.first.imageUrl : '',

      isActive: variant.isActive,
    );
  }

  Map<String, dynamic> toPayload(String? finalImageUrl) {
    final attributesText = attributesCtrl.text.trim();
    Map<String, dynamic> attributes = {};

    if (attributesText.isNotEmpty) {
      final decoded = jsonDecode(attributesText);
      if (decoded is! Map) throw const FormatException('JSON inválido');
      attributes = Map<String, dynamic>.from(decoded);
    }

    return {
      if (id != null) 'id': id,
      'sku': skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
      'attributes': attributes,
      'sale_price':
          priceCtrl.text.trim().isEmpty
              ? null
              : double.parse(priceCtrl.text.trim()),
        'wholesale_price':
          wholesalePriceCtrl.text.trim().isEmpty
            ? null
            : double.parse(wholesalePriceCtrl.text.trim()),
        'wholesale_min_quantity':
            wholesaleMinQuantityCtrl.text.trim().isEmpty
              ? null
              : int.parse(wholesaleMinQuantityCtrl.text.trim()),
        'reorder_point':
          reorderPointCtrl.text.trim().isEmpty
            ? 3
            : int.parse(reorderPointCtrl.text.trim()),
      'is_active': isActive,
    };
  }

  void dispose() {
    skuCtrl.dispose();
    attributesCtrl.dispose();
    priceCtrl.dispose();
    wholesalePriceCtrl.dispose();
    wholesaleMinQuantityCtrl.dispose();
    reorderPointCtrl.dispose();
  }
}
