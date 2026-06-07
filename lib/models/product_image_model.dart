class ProductImageModel {
  final String id;
  final String productId;
  final String? variantId;
  final String imageUrl;
  final int displayOrder;
  final DateTime? createdAt;
  final bool isMain;

  ProductImageModel({
    required this.id,
    required this.productId,
    this.variantId,
    required this.imageUrl,
    this.displayOrder = 0,
    this.createdAt,
    this.isMain = false,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      imageUrl: json['image_url'] as String,
      displayOrder: (json['display_order'] as num? ?? 0).toInt(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      isMain: json['is_main'] as bool? ?? false,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'image_url': imageUrl,
      'display_order': displayOrder,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'is_main': isMain,
    };
  }

  /// Método copyWith ideal para el manejo de estados
  ProductImageModel copyWith({
    String? id,
    String? productId,
    String? variantId,
    String? imageUrl,
    int? displayOrder,
    DateTime? createdAt,
    bool? isMain,
  }) {
    return ProductImageModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      isMain: isMain ?? this.isMain,
    );
  }
}
