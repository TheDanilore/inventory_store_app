import 'package:equatable/equatable.dart';

class CustomerCreditEntity extends Equatable {
  final String id;
  final String profileId;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  // Propiedades adicionales opcionales para vistas cruzadas
  final String? customerName;
  final String? customerDocument;
  final String? customerPhone;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  const CustomerCreditEntity({
    required this.id,
    required this.profileId,
    this.creditLimit = 0.0,
    this.currentDebt = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.customerName,
    this.customerDocument,
    this.customerPhone,
  });

  @override
  List<Object?> get props => [
        id,
        profileId,
        creditLimit,
        currentDebt,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        customerName,
        customerDocument,
        customerPhone,
      ];
}
