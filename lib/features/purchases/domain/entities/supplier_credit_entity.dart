import 'package:equatable/equatable.dart';

class SupplierCreditEntity extends Equatable {
  final String creditId;
  final String supplierId;
  final String supplierName;
  final String? supplierTaxId;
  final String? supplierPhone;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  const SupplierCreditEntity({
    required this.creditId,
    required this.supplierId,
    required this.supplierName,
    this.supplierTaxId,
    this.supplierPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
  });

  @override
  List<Object?> get props => [
        creditId,
        supplierId,
        supplierName,
        supplierTaxId,
        supplierPhone,
        creditLimit,
        currentDebt,
        isActive,
      ];
}

class SupplierFinancialAccountOption {
  final String id;
  final String name;
  final String type; // CAJA, BANCO, DIGITAL
  final double balance;

  SupplierFinancialAccountOption({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  String get paymentMethodLabel {
    if (type == 'CAJA') return 'EFECTIVO';
    if (type == 'BANCO') return 'TRANSFERENCIA';
    if (type == 'DIGITAL') return 'BILLETERA_DIGITAL';
    return 'OTRO';
  }
}
