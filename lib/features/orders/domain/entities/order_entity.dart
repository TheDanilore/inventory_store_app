import 'package:equatable/equatable.dart';

class OrderEntity extends Equatable {
  final String id;
  final String? customerId;
  final double totalAmount;
  final double totalProfit;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final String? warehouseId;
  final int pointsUsed;
  final int pointsEarned;
  final String customerName;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;
  final double discountAmount;

  final String? warehouseName; // Extracted from warehouse relation if needed
  final String? profileFullName;
  final String? profilePhone;

  const OrderEntity({
    required this.id,
    this.customerId,
    this.totalAmount = 0.00,
    this.totalProfit = 0.00,
    this.paymentMethod = 'EFECTIVO',
    this.status = 'COMPLETED',
    this.createdAt,
    this.warehouseId,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.customerName = '',
    this.paymentStatus = 'PENDING',
    this.amountPaid = 0.00,
    this.dueDate,
    this.createdBy,
    this.updatedBy,
    this.updatedAt,
    this.discountAmount = 0.00,
    this.warehouseName,
    this.profileFullName,
    this.profilePhone,
  });

  @override
  List<Object?> get props => [
    id,
    customerId,
    totalAmount,
    totalProfit,
    paymentMethod,
    status,
    createdAt,
    warehouseId,
    pointsUsed,
    pointsEarned,
    customerName,
    paymentStatus,
    amountPaid,
    dueDate,
    createdBy,
    updatedBy,
    updatedAt,
    discountAmount,
    warehouseName,
    profileFullName,
    profilePhone,
  ];

  OrderEntity copyWith({
    String? id,
    String? customerId,
    double? totalAmount,
    double? totalProfit,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    String? warehouseId,
    int? pointsUsed,
    int? pointsEarned,
    String? customerName,
    String? paymentStatus,
    double? amountPaid,
    DateTime? dueDate,
    String? createdBy,
    String? updatedBy,
    DateTime? updatedAt,
    double? discountAmount,
    String? warehouseName,
    String? profileFullName,
    String? profilePhone,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      warehouseId: warehouseId ?? this.warehouseId,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      customerName: customerName ?? this.customerName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      discountAmount: discountAmount ?? this.discountAmount,
      warehouseName: warehouseName ?? this.warehouseName,
      profileFullName: profileFullName ?? this.profileFullName,
      profilePhone: profilePhone ?? this.profilePhone,
    );
  }
}
