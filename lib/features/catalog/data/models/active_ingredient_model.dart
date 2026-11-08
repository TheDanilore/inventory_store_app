import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';

class ActiveIngredientModel {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  ActiveIngredientModel({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory ActiveIngredientModel.fromJson(Map<String, dynamic> json) {
    return ActiveIngredientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      // 'search_vector' se omite porque la base de datos lo calcula automáticamente
    };
  }

  ActiveIngredientModel copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return ActiveIngredientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ActiveIngredientEntity toEntity() {
    return ActiveIngredientEntity(
      id: id,
      name: name,
      description: description,
      createdAt: createdAt,
    );
  }

  factory ActiveIngredientModel.fromEntity(ActiveIngredientEntity entity) {
    return ActiveIngredientModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      createdAt: entity.createdAt,
    );
  }
}
