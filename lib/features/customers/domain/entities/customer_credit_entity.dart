import 'package:equatable/equatable.dart';

class CustomerCreditEntity extends Equatable {
  final String id;
  final String? profileId;
  final String? customerRecordId;
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

  /// Identificador canónico del cliente (`customers.id` o `profiles.id` legado).
  String get effectiveCustomerId =>
      (customerRecordId != null && customerRecordId!.isNotEmpty)
          ? customerRecordId!
          : (profileId ?? id);

  bool get isUnlimited => creditLimit <= 0;
  double get availableCredit =>
      isUnlimited
          ? double.infinity
          : (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      (!isUnlimited && creditLimit > 0)
          ? (currentDebt / creditLimit).clamp(0.0, 1.0)
          : 0.0;
  bool get isMaxedOut =>
      !isUnlimited && creditLimit > 0 && currentDebt >= creditLimit;

  const CustomerCreditEntity({
    required this.id,
    this.profileId,
    this.customerRecordId,
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

  CustomerCreditEntity copyWith({
    String? id,
    String? profileId,
    String? customerRecordId,
    double? creditLimit,
    double? currentDebt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? customerName,
    String? customerDocument,
    String? customerPhone,
  }) {
    return CustomerCreditEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      customerRecordId: customerRecordId ?? this.customerRecordId,
      creditLimit: creditLimit ?? this.creditLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      customerName: customerName ?? this.customerName,
      customerDocument: customerDocument ?? this.customerDocument,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }

  @override
  List<Object?> get props => [
    id,
    profileId,
    customerRecordId,
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
