class ActiveIngredientEntity {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  const ActiveIngredientEntity({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  ActiveIngredientEntity copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return ActiveIngredientEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
