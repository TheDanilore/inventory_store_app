class ActiveIngredientEntity {
  final String id;
  final String name;
  final String? description;

  const ActiveIngredientEntity({
    required this.id,
    required this.name,
    this.description,
  });

  ActiveIngredientEntity copyWith({
    String? id,
    String? name,
    String? description,
  }) {
    return ActiveIngredientEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
