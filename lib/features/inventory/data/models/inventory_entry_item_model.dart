class InventoryEntryItemModel {
  final String id;
  final String entryId;
  final String productId;
  final String variantId;
  final double quantity;
  final double unitCost;
  final double? unitCostBase;
  final String batchNumber; // 'DEFAULT' por defecto
  final DateTime? expiryDate;
  final DateTime? createdAt;

  // Extra fields from joins for UI display
  final String productName;
  final String variantAttrs;
  final bool usesBatches;
  final String? imageUrl;

  double get subtotal => quantity * unitCost;
  double get subtotalBase => quantity * (unitCostBase ?? unitCost);

  InventoryEntryItemModel({
    required this.id,
    required this.entryId,
    required this.productId,
    required this.variantId,
    required this.quantity,
    required this.unitCost,
    this.unitCostBase,
    this.batchNumber = 'DEFAULT',
    this.expiryDate,
    this.createdAt,
    this.productName = '',
    this.variantAttrs = '',
    this.usesBatches = false,
    this.imageUrl,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryEntryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryEntryItemModel(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num).toDouble(),
      unitCostBase: (json['unit_cost_base'] as num?)?.toDouble(),
      batchNumber: json['batch_number'] as String? ?? 'DEFAULT',
      expiryDate:
          json['expiry_date'] != null
              ? DateTime.parse(json['expiry_date'] as String)
              : null,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      productName: json['product_name'] as String? ?? '',
      variantAttrs: json['variant_attrs'] as String? ?? '',
      usesBatches: json['uses_batches'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
    );
  }

  /// Factory para resolver el árbol de joins relacionales complejos de Supabase
  /// extrayendo atributos de variantes y cascada de imágenes a 3 niveles.
  factory InventoryEntryItemModel.fromSupabaseQueryResult(
    Map<String, dynamic> r,
    String entryId,
  ) {
    final prod = r['products'] as Map<String, dynamic>?;
    final variantData = r['product_variants'] as Map<String, dynamic>?;
    final variantId = r['variant_id'] as String?;

    final vavList =
        variantData?['variant_attribute_values'] as List<dynamic>? ?? [];
    final List<String> attrValues = [];

    for (final vav in vavList) {
      final av = vav['attribute_values'] as Map<String, dynamic>?;
      if (av != null && av['value'] != null) {
        attrValues.add(av['value'].toString());
      }
    }

    final attrsText = attrValues.join(' · ');
    final bool usesBatches = prod?['uses_batches'] == true;

    String? finalImageUrl;

    // 1. Buscar en las imágenes del producto la asociada a la variante
    final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
    if (variantId != null && variantId.isNotEmpty && imagesList.isNotEmpty) {
      for (final img in imagesList) {
        if (img is Map<String, dynamic> &&
            img['variant_id'] == variantId &&
            (img['image_url'] as String?)?.isNotEmpty == true) {
          finalImageUrl = img['image_url'] as String;
          break;
        }
      }
    }

    // 2. Si es nulo, buscar en las imágenes anidadas en product_variants
    if (finalImageUrl == null || finalImageUrl.isEmpty) {
      final variantImagesList =
          variantData?['product_images'] as List<dynamic>? ?? [];
      for (final img in variantImagesList) {
        if (img is Map<String, dynamic> &&
            (img['image_url'] as String?)?.isNotEmpty == true) {
          finalImageUrl = img['image_url'] as String;
          if (img['is_main'] == true) break;
        }
      }
    }

    // 3. Herencia automática: si la variante no tiene imagen propia, usar la imagen principal del producto
    if (finalImageUrl == null || finalImageUrl.isEmpty) {
      if (imagesList.isNotEmpty) {
        for (final img in imagesList) {
          if (img is Map<String, dynamic> &&
              (img['image_url'] as String?)?.isNotEmpty == true) {
            finalImageUrl = img['image_url'] as String;
            if (img['is_main'] == true) break;
          }
        }
      }
    }

    return InventoryEntryItemModel(
      id: r['id'] as String? ?? '',
      entryId: entryId,
      productId: prod?['id'] as String? ?? '',
      variantId: variantId ?? '',
      productName: prod?['name'] as String? ?? '—',
      variantAttrs: attrsText.isNotEmpty ? attrsText : '',
      quantity: (r['quantity'] as num).toDouble(),
      unitCost: (r['unit_cost'] as num).toDouble(),
      batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
      expiryDate:
          r['expiry_date'] != null
              ? DateTime.tryParse(r['expiry_date'] as String)
              : null,
      usesBatches: usesBatches,
      imageUrl: finalImageUrl,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_id': entryId,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      'unit_cost': unitCost,
      if (unitCostBase != null) 'unit_cost_base': unitCostBase,
      'batch_number': batchNumber,
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados
  InventoryEntryItemModel copyWith({
    String? id,
    String? entryId,
    String? productId,
    String? variantId,
    double? quantity,
    double? unitCost,
    double? unitCostBase,
    String? batchNumber,
    DateTime? expiryDate,
    DateTime? createdAt,
    String? productName,
    String? variantAttrs,
    bool? usesBatches,
    String? imageUrl,
  }) {
    return InventoryEntryItemModel(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      unitCostBase: unitCostBase ?? this.unitCostBase,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      variantAttrs: variantAttrs ?? this.variantAttrs,
      usesBatches: usesBatches ?? this.usesBatches,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
