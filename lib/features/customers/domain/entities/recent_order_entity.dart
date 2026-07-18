import 'package:equatable/equatable.dart';

class RecentOrderEntity extends Equatable {
  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final double amountPaid;
  final double discountAmount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final int pointsEarned;
  final int pointsUsed;
  final DateTime? dueDate;

  const RecentOrderEntity({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.amountPaid,
    required this.discountAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.pointsEarned,
    required this.pointsUsed,
    this.dueDate,
  });

  double get pendingAmount => totalAmount - amountPaid;

  @override
  List<Object?> get props => [
    id,
    createdAt,
    totalAmount,
    amountPaid,
    discountAmount,
    status,
    paymentStatus,
    paymentMethod,
    pointsEarned,
    pointsUsed,
    dueDate,
  ];
}
