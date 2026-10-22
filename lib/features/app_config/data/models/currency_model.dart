import 'package:inventory_store_app/features/app_config/domain/entities/currency_entity.dart';

class CurrencyModel extends CurrencyEntity {
  const CurrencyModel({
    required super.id,
    required super.code,
    required super.name,
    required super.symbol,
    required super.exchangeRate,
    super.isBase = false,
    super.isActive = true,
    super.updatedAt,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: json['id'] as String? ?? '',
      code: (json['code'] as String? ?? 'PEN').toUpperCase(),
      name: json['name'] as String? ?? '',
      symbol: json['symbol'] as String? ?? 'S/',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      isBase: json['is_base'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'symbol': symbol,
      'exchange_rate': exchangeRate,
      'is_base': isBase,
      'is_active': isActive,
    };
  }

  CurrencyEntity toEntity() => this;
}
