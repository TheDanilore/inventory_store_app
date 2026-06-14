// ─── Modelo para los atributos estructurados (nueva BD) ──────────────────────
class VariantAttributeValueModel {
  final String attributeValueId;
  final String attributeName;
  final String value;

  const VariantAttributeValueModel({
    required this.attributeValueId,
    required this.attributeName,
    required this.value,
  });

  factory VariantAttributeValueModel.fromJson(Map<String, dynamic> json) {
    // Viene del join: variant_attribute_values → attribute_values → attributes
    final av = json['attribute_values'] as Map<String, dynamic>? ?? json;
    final attr = av['attributes'] as Map<String, dynamic>? ?? {};
    return VariantAttributeValueModel(
      attributeValueId: av['id'] as String? ?? '',
      attributeName: attr['name'] as String? ?? '',
      value: av['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'attribute_value_id': attributeValueId,
    'attribute_name': attributeName,
    'value': value,
  };
}
