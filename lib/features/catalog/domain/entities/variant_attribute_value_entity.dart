class VariantAttributeValueEntity {
  final String attributeValueId; 
  final String attributeId; 
  final String attributeName;
  final String value;

  const VariantAttributeValueEntity({
    required this.attributeValueId,
    required this.attributeId,
    required this.attributeName,
    required this.value,
  });

  VariantAttributeValueEntity copyWith({
    String? attributeValueId,
    String? attributeId,
    String? attributeName,
    String? value,
  }) {
    return VariantAttributeValueEntity(
      attributeValueId: attributeValueId ?? this.attributeValueId,
      attributeId: attributeId ?? this.attributeId,
      attributeName: attributeName ?? this.attributeName,
      value: value ?? this.value,
    );
  }
}
