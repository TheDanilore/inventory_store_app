import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';

class FinancialAccountModel {
  final String id;
  final String name;
  final String type;
  final double balance;
  final bool isActive;
  final DateTime createdAt;

  FinancialAccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.isActive,
    required this.createdAt,
  });

  /// ¡Agrega o reemplaza este método en tu modelo!
  factory FinancialAccountModel.fromJson(Map<String, dynamic> map) {
    return FinancialAccountModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? '',
      // Mapeo ultra seguro para números (acepta int y double desde Postgres)
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] as bool? ?? true,
      // Parseo seguro de la fecha ISO de Supabase a DateTime de Dart
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
    );
  }

  /// Opcional: Por si necesitas enviar datos de vuelta a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convierte el modelo de infraestructura a la entidad de dominio pura.
  FinancialAccountEntity toEntity() {
    return FinancialAccountEntity(
      id: id,
      name: name,
      type: type,
      balance: balance,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}

