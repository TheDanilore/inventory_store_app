import 'package:equatable/equatable.dart';

/// Entidad inmutable que representa una moneda en el sistema ERP.
class CurrencyEntity extends Equatable {
  final String id;
  final String code; // 'PEN', 'USD', 'EUR', etc.
  final String name; // 'Soles', 'Dólares Americanos', etc.
  final String symbol; // 'S/', '$', '€'
  final double
  exchangeRate; // Tipo de cambio respecto a la moneda base (PEN = 1.0)
  final bool isBase; // true si es la moneda patrón (PEN)
  final bool isActive; // si está habilitada para transacciones
  final DateTime? updatedAt;

  const CurrencyEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.exchangeRate,
    this.isBase = false,
    this.isActive = true,
    this.updatedAt,
  });

  /// Alias de conveniencia para exchangeRate
  double get exchangeRateToTarget => exchangeRate;

  /// Formatea un monto numérico con el símbolo de la moneda
  String formatAmount(double amount) {
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  /// Convierte un monto en esta moneda a la moneda base
  double toBase(double amount, {double? customRate}) {
    if (isBase) return amount;
    final rate = customRate ?? exchangeRate;
    return amount * rate;
  }

  /// Convierte un monto en la moneda base a esta moneda
  double fromBase(double amountBase, {double? customRate}) {
    if (isBase) return amountBase;
    final rate = customRate ?? exchangeRate;
    if (rate <= 0) return 0.0;
    return amountBase / rate;
  }

  CurrencyEntity copyWith({
    String? id,
    String? code,
    String? name,
    String? symbol,
    double? exchangeRate,
    bool? isBase,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return CurrencyEntity(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isBase: isBase ?? this.isBase,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    symbol,
    exchangeRate,
    isBase,
    isActive,
    updatedAt,
  ];
}
