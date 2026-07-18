import 'package:equatable/equatable.dart';

class CustomerLocationEntity extends Equatable {
  static String typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'HOME':
        return 'Casa';
      case 'WORK':
        return 'Trabajo';
      case 'STORE':
        return 'Tienda / Local';
      default:
        return 'Otro';
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
