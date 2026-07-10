import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
  final String id;
  final String fullName;
  final String? phone;
  final String? documentNumber;
  final String? documentType;
  final String? avatarUrl;
  final double walletBalance;
  final bool isActive;
  final DateTime? createdAt;

  final double currentDebt;
  final double creditLimit;
  final double totalRevenue; // Dinero generado por este cliente
  final int orderCount;
  final DateTime? lastOrderAt;

  const CustomerEntity({
    required this.id,
    required this.fullName,
    this.phone,
    this.documentNumber,
    this.documentType,
    this.avatarUrl,
    this.walletBalance = 0.0,
    this.isActive = true,
    this.createdAt,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
    this.totalRevenue = 0.0,
    this.orderCount = 0,
    this.lastOrderAt,
  });

  @override
  List<Object?> get props => [
        id,
        fullName,
        phone,
        documentNumber,
        documentType,
        avatarUrl,
        walletBalance,
        isActive,
        createdAt,
        currentDebt,
        creditLimit,
        totalRevenue,
        orderCount,
        lastOrderAt,
      ];
}
