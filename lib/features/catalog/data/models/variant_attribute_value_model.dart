// ─── Modelo para los atributos estructurados (nueva BD) ──────────────────────
import 'package:inventory_store_app/features/catalog/domain/entities/variant_attribute_value_entity.dart';

class VariantAttributeValueModel {
  final String attributeValueId; // ID del valor (Ej: ID de "Rojo")
  final String attributeId; // ID de la propiedad (Ej: ID de "Color")
  final String attributeName;
  final String value;

  const VariantAttributeValueModel({
    required this.attributeValueId,
    required this.attributeId,
    required this.attributeName,
    required this.value,
  });

  VariantAttributeValueModel copyWith({
    String? attributeValueId,
    String? attributeId,
    String? attributeName,
    String? value,
  }) {
    return VariantAttributeValueModel(
      attributeValueId: attributeValueId ?? this.attributeValueId,
      attributeId: attributeId ?? this.attributeId,
      attributeName: attributeName ?? this.attributeName,
      value: value ?? this.value,
    );
  }

  VariantAttributeValueEntity toEntity() {
    return VariantAttributeValueEntity(
      attributeValueId: attributeValueId,
      attributeId: attributeId,
      attributeName: attributeName,
      value: value,
    );
  }

  factory VariantAttributeValueModel.fromEntity(VariantAttributeValueEntity entity) {
    return VariantAttributeValueModel(
      attributeValueId: entity.attributeValueId,
      attributeId: entity.attributeId,
      attributeName: entity.attributeName,
      value: entity.value,
    );
  }

  factory VariantAttributeValueModel.fromJson(Map<String, dynamic> json) {
    // Viene del join: variant_attribute_values → attribute_values → attributes
    final av = json['attribute_values'] as Map<String, dynamic>? ?? json;
    final attr = av['attributes'] as Map<String, dynamic>? ?? {};

    return VariantAttributeValueModel(
      attributeValueId: av['id'] as String? ?? '',
      attributeId:
          attr['id'] as String? ?? '', // Recuperamos el ID del atributo
      attributeName: attr['name'] as String? ?? '',
      value: av['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'attribute_value_id': attributeValueId,
    'attribute_id': attributeId,
    'attribute_name': attributeName,
    'value': value,
  };
}
