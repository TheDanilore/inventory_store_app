class WarehouseModel {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;

  static var warehouseNames = <String, String>{};

  WarehouseModel({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  // Reconstruye el objeto desde el JSON que devuelve Supabase
  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  // Convierte el objeto a JSON para subirlo o actualizarlo en Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (address != null) 'address': address,
      'is_active': isActive,
      // Nota: created_at normalmente lo maneja la base de datos automáticamente
    };
  }

  // Útil para actualizar el estado inmutable
  WarehouseModel copyWith({
    String? id,
    String? name,
    String? address,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
