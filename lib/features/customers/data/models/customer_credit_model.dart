import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditModel {
  final String id;
  final String? profileId;
  final String? customerRecordId;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  CustomerCreditModel({
    required this.id,
    this.profileId,
    this.customerRecordId,
    this.creditLimit = 0.00,
    this.currentDebt = 0.00,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory CustomerCreditModel.fromJson(Map<String, dynamic> json) {
    return CustomerCreditModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String?,
      customerRecordId: json['customer_record_id'] as String?,
      creditLimit: (json['credit_limit'] as num? ?? 0.00).toDouble(),
      currentDebt: (json['current_debt'] as num? ?? 0.00).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'customer_record_id': customerRecordId,
      'credit_limit': creditLimit,
      'current_debt': currentDebt,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'created_by': createdBy,
    };
  }

  double get availableCredit => creditLimit - currentDebt;

  CustomerCreditModel copyWith({
    String? id,
    String? profileId,
    String? customerRecordId,
    double? creditLimit,
    double? currentDebt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CustomerCreditModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      customerRecordId: customerRecordId ?? this.customerRecordId,
      creditLimit: creditLimit ?? this.creditLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  CustomerCreditEntity toEntity() {
    return CustomerCreditEntity(
      id: id,
      profileId: profileId,
      customerRecordId: customerRecordId,
      creditLimit: creditLimit,
      currentDebt: currentDebt,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }
}

class CreditAccountModel {
  final String creditId;
  final String? profileId;
  final String? customerRecordId;
  final String partnerName;
  final String? partnerDocument;
  final String? partnerDocumentType;
  final String? partnerPhone;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  CreditAccountModel({
    required this.creditId,
    this.profileId,
    this.customerRecordId,
    required this.partnerName,
    this.partnerDocument,
    this.partnerDocumentType,
    this.partnerPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CreditAccountModel.fromJoin(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? const {};
    return CreditAccountModel(
      creditId: json['id'] as String,
      profileId: json['profile_id'] as String?,
      customerRecordId:
          json['customer_record_id'] as String? ?? profile['id'] as String?,
      partnerName: profile['full_name'] as String? ?? 'Cliente desconocido',
      partnerDocument: profile['document_number'] as String?,
      partnerDocumentType: profile['document_type'] as String?,
      partnerPhone: profile['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  factory CreditAccountModel.fromRpc(Map<String, dynamic> json) {
    return CreditAccountModel(
      creditId: (json['id'] ?? json['credit_id']) as String,
      profileId: json['profile_id'] as String?,
      customerRecordId: json['customer_record_id'] as String?,
      partnerName:
          (json['customer_name'] ?? json['partner_name']) as String? ??
          'Cliente desconocido',
      partnerDocument:
          (json['customer_document'] ?? json['partner_document']) as String?,
      partnerDocumentType:
          (json['customer_document_type'] ?? json['partner_document_type'])
              as String?,
      partnerPhone:
          (json['customer_phone'] ?? json['partner_phone']) as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  CustomerCreditEntity toEntity() {
    return CustomerCreditEntity(
      id: creditId,
      profileId: profileId,
      customerRecordId: customerRecordId,
      creditLimit: creditLimit,
      currentDebt: currentDebt,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      customerName: partnerName,
      customerDocument: partnerDocument,
      customerPhone: partnerPhone,
    );
  }
}

class FinancialAccountOption {
  final String id;
  final String name;
  final String type; // CAJA | BANCO | DIGITAL | OTRO
  final double balance;

  FinancialAccountOption({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  String get paymentMethodLabel => name;
}
