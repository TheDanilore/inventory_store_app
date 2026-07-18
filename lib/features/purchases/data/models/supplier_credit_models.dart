import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

class SupplierCreditModel extends SupplierCreditEntity {
  const SupplierCreditModel({
    required super.creditId,
    required super.supplierId,
    required super.supplierName,
    super.supplierTaxId,
    super.supplierPhone,
    required super.creditLimit,
    required super.currentDebt,
    required super.isActive,
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
