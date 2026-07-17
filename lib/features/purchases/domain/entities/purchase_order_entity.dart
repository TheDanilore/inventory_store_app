import 'package:equatable/equatable.dart';

class PurchaseOrderEntity extends Equatable {
  final String id;
  final DateTime createdAt;
  final String? supplierId;
  final String supplierName;
  final String? warehouseName;
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final double discountAmount;
  final double taxAmount;
  final String documentType;
  final String? documentNumber;
  final String? notes;
  final int itemCount;

  const PurchaseOrderEntity({
    required this.id,
    required this.createdAt,
    this.supplierId,
    required this.supplierName,
    this.warehouseName,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amountPaid,
    this.dueDate,
    required this.discountAmount,
    required this.taxAmount,
    required this.documentType,
    this.documentNumber,
    this.notes,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [
        id,
        createdAt,
        supplierId,
        supplierName,
        warehouseName,
        status,
        totalAmount,
        paymentMethod,
        paymentStatus,
        amountPaid,
        dueDate,
        discountAmount,
        taxAmount,
        documentType,
        documentNumber,
        notes,
        itemCount,
      ];
}
