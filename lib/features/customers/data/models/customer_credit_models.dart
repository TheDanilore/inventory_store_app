import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CreditAccountModel {
  final String creditId;
  final String profileId;
  final String partnerName;
  final String? partnerDocument;
  final String? partnerDocumentType;
  final String? partnerPhone;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  CreditAccountModel({
    required this.creditId,
    required this.profileId,
    required this.partnerName,
    this.partnerDocument,
    this.partnerDocumentType,
    this.partnerPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
  });

  factory CreditAccountModel.fromJoin(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return CreditAccountModel(
      creditId: json['id'] as String,
      profileId: json['profile_id'] as String,
      partnerName: profile['full_name'] as String? ?? 'Cliente desconocido',
      partnerDocument: profile['document_number'] as String?,
      partnerDocumentType: profile['document_type'] as String?,
      partnerPhone: profile['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  factory CreditAccountModel.fromView(Map<String, dynamic> json) {
    return CreditAccountModel(
      creditId: json['credit_id'],
      profileId: json['profile_id'],
      partnerName: json['partner_name'] ?? 'Cliente desconocido',
      partnerDocument: json['partner_document'],
      partnerDocumentType: json['partner_document_type'],
      partnerPhone: json['partner_phone'],
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }

  CustomerCreditEntity toEntity() {
    return CustomerCreditEntity(
      id: creditId,
      profileId: profileId,
      creditLimit: creditLimit,
      currentDebt: currentDebt,
      isActive: isActive,
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
