class SupplierCreditModel {
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

  SupplierCreditModel({
    required this.creditId,
    required this.supplierId,
    required this.supplierName,
    this.supplierTaxId,
    this.supplierPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
  });

  factory SupplierCreditModel.fromView(Map<String, dynamic> json) {
    // Cuando filtramos con !inner la vista o join en supabase
    final supplier = json['suppliers'] as Map<String, dynamic>? ?? {};
    return SupplierCreditModel(
      creditId: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: supplier['name'] as String? ?? 'Proveedor desconocido',
      supplierTaxId: supplier['tax_id'] as String?,
      supplierPhone: supplier['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
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
