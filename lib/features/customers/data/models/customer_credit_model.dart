import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditModel {
  final String id;
  final String profileId;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  CustomerCreditModel({
    required this.id,
    required this.profileId,
    this.creditLimit = 0.00,
    this.currentDebt = 0.00,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory CustomerCreditModel.fromJson(Map<String, dynamic> json) {
    return CustomerCreditModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      creditLimit: (json['credit_limit'] as num? ?? 0.00).toDouble(),
      currentDebt: (json['current_debt'] as num? ?? 0.00).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      createdBy: json['created_by'] as String?,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'credit_limit': creditLimit,
      'current_debt': currentDebt,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Método para calcular de forma rápida el crédito disponible en el cliente
  double get availableCredit => creditLimit - currentDebt;

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  CustomerCreditModel copyWith({
    String? id,
    String? profileId,
    double? creditLimit,
    double? currentDebt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CustomerCreditModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      creditLimit: creditLimit ?? this.creditLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  CustomerCreditEntity toEntity() {
    return CustomerCreditEntity(
      id: id,
      profileId: profileId,
      creditLimit: creditLimit,
      currentDebt: currentDebt,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }
}
