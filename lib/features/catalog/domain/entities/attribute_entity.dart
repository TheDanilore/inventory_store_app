import 'package:equatable/equatable.dart';

class AttributeEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final List<AttributeValueEntity> values;

  const AttributeEntity({
    required this.id,
    required this.name,
    this.description,
    this.values = const [],
  });

  AttributeEntity copyWith({
    String? id,
    String? name,
    String? description,
    List<AttributeValueEntity>? values,
  }) {
    return AttributeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      values: values ?? this.values,
    );
  }

  @override
  List<Object?> get props => [id, name, description, values];
}

class AttributeValueEntity extends Equatable {
  final String id;
  final String attributeId;
  final String value;

  const AttributeValueEntity({
    required this.id,
    required this.attributeId,
    required this.value,
  });

  AttributeValueEntity copyWith({
    String? id,
    String? attributeId,
    String? value,
  }) {
    return AttributeValueEntity(
      id: id ?? this.id,
      attributeId: attributeId ?? this.attributeId,
      value: value ?? this.value,
    );
  }

  @override
  List<Object?> get props => [id, attributeId, value];
}
