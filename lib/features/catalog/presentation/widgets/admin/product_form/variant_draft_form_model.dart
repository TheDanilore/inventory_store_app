import 'dart:typed_data';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';

class VariantDraftFormModel {
  final String? id;

  // Campos básicos como primitivos (no controllers)
  String sku;
  String barcode;
  String price;
  String wholesalePrice;
  String wholesaleMinQuantity;
  String reorderPoint;
  String unitCost;

  // Atributos
  List<Map<String, dynamic>> selectedAttributes;

  bool isActive;

  // Imágenes
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
  })  : sku = sku ?? '',
        barcode = barcode ?? '',
        price = price ?? '',
        wholesalePrice = wholesalePrice ?? '',
        wholesaleMinQuantity = wholesaleMinQuantity ?? '',
        reorderPoint = reorderPoint ?? '3',
        unitCost = unitCost ?? '',
        selectedAttributes = selectedAttributes ?? [],
        urlsExistentes = urlsExistentes ?? [],
        nuevasImagenes = nuevasImagenes ?? [];

  factory VariantDraftFormModel.fromEntity(VariantDraftEntity variant) {
    return VariantDraftFormModel(
      id: variant.id,
      sku: variant.sku ?? '',
      barcode: variant.barcode ?? '',
      selectedAttributes: variant.selectedAttributes,
      price: variant.price ?? '',
      wholesalePrice: variant.wholesalePrice ?? '',
      wholesaleMinQuantity: variant.wholesaleMinQuantity?.toString() ?? '',
      reorderPoint: variant.reorderPoint?.toString() ?? '3',
      unitCost: variant.unitCost?.toString() ?? '',
      urlsExistentes: variant.urlsExistentes,
      isActive: variant.isActive,
    );
  }

  VariantDraftFormModel copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? price,
    String? wholesalePrice,
    String? wholesaleMinQuantity,
    String? reorderPoint,
    String? unitCost,
    List<Map<String, dynamic>>? selectedAttributes,
    bool? isActive,
    List<Uint8List>? nuevasImagenes,
    List<String>? urlsExistentes,
  }) {
    return VariantDraftFormModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity ?? this.wholesaleMinQuantity,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      unitCost: unitCost ?? this.unitCost,
      selectedAttributes: selectedAttributes ?? List.of(this.selectedAttributes),
      isActive: isActive ?? this.isActive,
      nuevasImagenes: nuevasImagenes ?? List.of(this.nuevasImagenes),
      urlsExistentes: urlsExistentes ?? List.of(this.urlsExistentes),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      if (id != null) 'id': id,
      'sku': sku.trim().isEmpty ? null : sku.trim(),
      'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
      'sale_price': _parseDecimal(price),
      'wholesale_price': _parseDecimal(wholesalePrice),
      'wholesale_min_quantity': _parseInt(wholesaleMinQuantity),
      'reorder_point': _parseInt(reorderPoint) ?? 3,
      'unit_cost': _parseDecimal(unitCost),
      'is_active': isActive,
    };
  }

  static double? _parseDecimal(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  static int? _parseInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
}
