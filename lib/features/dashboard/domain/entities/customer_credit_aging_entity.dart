import 'package:equatable/equatable.dart';

/// Representa a un cliente con crédito vigente y la métrica de cuánto se demora en pagar
class CustomerCreditAgingEntity extends Equatable {
  final String creditId;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerDocument;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;
  final int
  daysWithDebt; // Días que lleva la deuda vigente desde el cargo más reciente
  final double
  averagePaymentDays; // Tiempo promedio que se demora en pagar históricamente
  final int totalPaymentsCount; // Cantidad de pagos históricos realizados
  final DateTime? lastChargeDate;
  final DateTime? lastPaymentDate;
  final DateTime? dueDate;

  const CustomerCreditAgingEntity({
    required this.creditId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerDocument,
    required this.creditLimit,
    required this.currentDebt,
    this.isActive = true,
    required this.daysWithDebt,
    required this.averagePaymentDays,
    this.totalPaymentsCount = 0,
    this.lastChargeDate,
    this.lastPaymentDate,
    this.dueDate,
  });

  /// Cupo utilizado en porcentaje (0.0 a 1.0)
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;

  /// Nivel de riesgo según los días de deuda
  String get riskLevel {
    if (daysWithDebt > 30) return 'MOROSO';
    if (daysWithDebt > 15) return 'ATENCIÓN';
    return 'AL_DÍA';
  }

  /// Texto descriptivo de cuánto se demora en pagar
  String get paymentSpeedLabel {
    if (totalPaymentsCount == 0) {
      return 'Primer crédito (Sin pagos previos)';
    }
    if (averagePaymentDays <= 0) {
      return 'Paga el mismo día';
    }
    final days = averagePaymentDays.round();
    return 'Demora prom: $days d';
  }

  /// Antigüedad de la deuda vigente
  String get currentDebtAgingLabel {
    if (daysWithDebt <= 0) {
      return 'Crédito de hoy';
    }
    return '$daysWithDebt días con deuda';
  }

  @override
  List<Object?> get props => [
    creditId,
    customerId,
    customerName,
    customerPhone,
    customerDocument,
    creditLimit,
    currentDebt,
    isActive,
    daysWithDebt,
    averagePaymentDays,
    totalPaymentsCount,
    lastChargeDate,
    lastPaymentDate,
    dueDate,
  ];
}
