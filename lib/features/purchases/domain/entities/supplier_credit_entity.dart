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

  SupplierCreditEntity copyWith({
    String? creditId,
    String? supplierId,
    String? supplierName,
    String? supplierTaxId,
    String? supplierPhone,
    double? creditLimit,
    double? currentDebt,
    bool? isActive,
  }) {
    return SupplierCreditEntity(
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

class SupplierCreditStatsEntity extends Equatable {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;
  final int debtCount;

  const SupplierCreditStatsEntity({
    this.totalDebt = 0.0,
    this.activeAccounts = 0,
    this.suspendedAccounts = 0,
    this.maxedOutAccounts = 0,
    this.debtCount = 0,
  });

  const SupplierCreditStatsEntity.empty()
    : totalDebt = 0.0,
      activeAccounts = 0,
      suspendedAccounts = 0,
      maxedOutAccounts = 0,
      debtCount = 0;

  SupplierCreditStatsEntity copyWith({
    double? totalDebt,
    int? activeAccounts,
    int? suspendedAccounts,
    int? maxedOutAccounts,
    int? debtCount,
  }) {
    return SupplierCreditStatsEntity(
      totalDebt: totalDebt ?? this.totalDebt,
      activeAccounts: activeAccounts ?? this.activeAccounts,
      suspendedAccounts: suspendedAccounts ?? this.suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts ?? this.maxedOutAccounts,
      debtCount: debtCount ?? this.debtCount,
    );
  }

  @override
  List<Object?> get props => [
    totalDebt,
    activeAccounts,
    suspendedAccounts,
    maxedOutAccounts,
    debtCount,
  ];
}

class SupplierCreditsPageEntity extends Equatable {
  final List<SupplierCreditEntity> accounts;
  final int totalCount;
  final SupplierCreditStatsEntity? stats;

  const SupplierCreditsPageEntity({
    required this.accounts,
    required this.totalCount,
    this.stats,
  });

  SupplierCreditsPageEntity copyWith({
    List<SupplierCreditEntity>? accounts,
    int? totalCount,
    SupplierCreditStatsEntity? stats,
  }) {
    return SupplierCreditsPageEntity(
      accounts: accounts ?? this.accounts,
      totalCount: totalCount ?? this.totalCount,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [accounts, totalCount, stats];
}

class SupplierCandidateEntity extends Equatable {
  final String id;
  final String name;
  final String? taxId;
  final String? phone;

  const SupplierCandidateEntity({
    required this.id,
    required this.name,
    this.taxId,
    this.phone,
  });

  @override
  List<Object?> get props => [id, name, taxId, phone];
}

class PendingPurchaseOrderEntity extends Equatable {
  final String id;
  final double totalAmount;
  final double amountPaid;
  final String paymentStatus;
  final DateTime createdAt;

  double get pendingAmount =>
      (totalAmount - amountPaid).clamp(0.0, double.infinity);
  bool get isPartial => paymentStatus == 'PARTIAL';
  String get shortId =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  const PendingPurchaseOrderEntity({
    required this.id,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentStatus,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    totalAmount,
    amountPaid,
    paymentStatus,
    createdAt,
  ];
}

class ActiveCashShiftEntity extends Equatable {
  final String id;
  final DateTime openedAt;
  final double openingAmount;

  const ActiveCashShiftEntity({
    required this.id,
    required this.openedAt,
    required this.openingAmount,
  });

  @override
  List<Object?> get props => [id, openedAt, openingAmount];
}

class SupplierFinancialAccountOption extends Equatable {
  final String id;
  final String name;
  final String type; // CAJA, BANCO, DIGITAL
  final double balance;

  const SupplierFinancialAccountOption({
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

  @override
  List<Object?> get props => [id, name, type, balance];
}
