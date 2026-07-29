import 'package:equatable/equatable.dart';

class CustomerLocationEntity extends Equatable {
  static String typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'casa':
      case 'home':
        return 'Casa';
      case 'chacra':
        return 'Chacra';
      case 'fundo':
      case 'work':
        return 'Fundo';
      case 'local':
      case 'store':
        return 'Local / Tienda';
      default:
        return type.isNotEmpty
            ? type[0].toUpperCase() + type.substring(1)
            : 'Otro';
    }
  }

  final String id;
  final String profileId;
  final String name;
  final String locationType;
  final double latitude;
  final double longitude;
  final String? addressLine;
  final String? reference;
  final String? notes;
  final bool isDefault;
  final DateTime? createdAt;

  const CustomerLocationEntity({
    required this.id,
    required this.profileId,
    required this.name,
    required this.locationType,
    required this.latitude,
    required this.longitude,
    this.addressLine,
    this.reference,
    this.notes,
    this.isDefault = false,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    profileId,
    name,
    locationType,
    latitude,
    longitude,
    addressLine,
    reference,
    notes,
    isDefault,
    createdAt,
  ];
}
