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

  /// Soporta tanto filas planas retornadas por RPC (`supplier_name`)
  /// como filas anidadas de PostgREST (`suppliers!inner(...)`).
  factory SupplierCreditModel.fromView(Map<String, dynamic> json) {
    final supplier = json['suppliers'] as Map<String, dynamic>?;
    return SupplierCreditModel(
      creditId: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName:
          json['supplier_name'] as String? ??
          supplier?['name'] as String? ??
          'Proveedor desconocido',
      supplierTaxId:
          json['supplier_tax_id'] as String? ??
          supplier?['tax_id'] as String?,
      supplierPhone:
          json['supplier_phone'] as String? ??
          supplier?['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  @override
  SupplierCreditModel copyWith({
    String? creditId,
    String? supplierId,
    String? supplierName,
    String? supplierTaxId,
    String? supplierPhone,
    double? creditLimit,
    double? currentDebt,
    bool? isActive,
  }) {
    return SupplierCreditModel(
      creditId: creditId ?? this.creditId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierTaxId: supplierTaxId ?? this.supplierTaxId,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      creditLimit: creditLimit ?? this.creditLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class SupplierCreditStatsModel {
  const SupplierCreditStatsModel._();

  static SupplierCreditStatsEntity fromJson(Map<String, dynamic> json) {
    return SupplierCreditStatsEntity(
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      activeAccounts: (json['activeAccounts'] as num?)?.toInt() ?? 0,
      suspendedAccounts: (json['suspendedAccounts'] as num?)?.toInt() ?? 0,
      maxedOutAccounts: (json['maxedOutAccounts'] as num?)?.toInt() ?? 0,
      debtCount: (json['debtCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupplierCandidateModel {
  const SupplierCandidateModel._();

  static SupplierCandidateEntity fromJson(Map<String, dynamic> json) {
    return SupplierCandidateEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sin nombre',
      taxId: json['tax_id'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class PendingPurchaseOrderModel {
  const PendingPurchaseOrderModel._();

  static PendingPurchaseOrderEntity fromJson(Map<String, dynamic> json) {
    return PendingPurchaseOrderEntity(
      id: json['id'] as String,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ActiveCashShiftModel {
  const ActiveCashShiftModel._();

  static ActiveCashShiftEntity fromJson(Map<String, dynamic> json) {
    return ActiveCashShiftEntity(
      id: json['id'] as String,
      openedAt:
          DateTime.tryParse(json['opened_at']?.toString() ?? '') ??
          DateTime.now(),
      openingAmount: (json['opening_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
