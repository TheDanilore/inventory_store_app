import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';

class BrandModel {
  final String? id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? website;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? productsCount;

  const BrandModel({
    this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.website,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.productsCount,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Sin marca',
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      website: json['website'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String)
              : null,
      productsCount: _parseProductsCount(json['products']),
    );
  }

  static int? _parseProductsCount(dynamic productsData) {
    if (productsData == null) return null;
    if (productsData is List) {
      if (productsData.isNotEmpty && productsData.first is Map) {
        return productsData.first['count'] as int?;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'description': description?.trim(),
      'logo_url': logoUrl?.trim(),
      'website': website?.trim(),
      'is_active': isActive,
    };
  }

  BrandEntity toEntity() {
    return BrandEntity(
      id: id,
      name: name,
      description: description,
      logoUrl: logoUrl,
      website: website,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      productsCount: productsCount,
    );
  }

  factory BrandModel.fromEntity(BrandEntity entity) {
    return BrandModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      logoUrl: entity.logoUrl,
      website: entity.website,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      productsCount: entity.productsCount,
    );
  }
}
