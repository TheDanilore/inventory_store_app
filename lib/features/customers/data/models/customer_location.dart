import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

class CustomerLocationModel {
  final String id;
  final String profileId;
  final String name;
  final String locationType; // casa, chacra, fundo, local, otro
  final double latitude;
  final double longitude;
  final String? addressLine;
  final String? reference;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;

  const CustomerLocationModel({
    required this.id,
    required this.profileId,
    required this.name,
    required this.locationType,
    required this.latitude,
    required this.longitude,
    this.addressLine,
    this.reference,
    this.notes,
    required this.isDefault,
    required this.createdAt,
  });

  factory CustomerLocationModel.fromMap(Map<String, dynamic> map) {
    return CustomerLocationModel(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      name: map['name'] as String? ?? '',
      locationType: map['location_type'] as String? ?? 'otro',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      addressLine: map['address_line'] as String?,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap({required String profileId}) => {
    'profile_id': profileId,
    'name': name,
    'location_type': locationType,
    'latitude': latitude,
    'longitude': longitude,
    'address_line': addressLine,
    'reference': reference,
    'notes': notes,
    'is_default': isDefault,
  };

  CustomerLocationModel copyWith({
    String? id,
    String? profileId,
    String? name,
    String? locationType,
    double? latitude,
    double? longitude,
    String? addressLine,
    String? reference,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return CustomerLocationModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      locationType: locationType ?? this.locationType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressLine: addressLine ?? this.addressLine,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Etiqueta legible del tipo de ubicación
  static String typeLabel(String type) {
    switch (type) {
      case 'casa':
        return 'Casa';
      case 'chacra':
        return 'Chacra';
      case 'fundo':
        return 'Fundo';
      case 'local':
        return 'Local';
      default:
        return 'Otro';
    }
  }

  /// Todos los tipos disponibles
  static const List<String> types = [
    'casa',
    'chacra',
    'fundo',
    'local',
    'otro',
  ];

  CustomerLocationEntity toEntity() {
    return CustomerLocationEntity(
      id: id,
      profileId: profileId,
      name: name,
      locationType: locationType,
      latitude: latitude,
      longitude: longitude,
      addressLine: addressLine,
      reference: reference,
      notes: notes,
      isDefault: isDefault,
      createdAt: createdAt,
    );
  }
}
