import 'package:equatable/equatable.dart';

class TopProductEntity extends Equatable {
  final String productName;
  final int totalQuantity;
  final double totalSpent;

  const TopProductEntity({
    required this.productName,
    required this.totalQuantity,
    required this.totalSpent,
  });

  @override
  List<Object?> get props => [productName, totalQuantity, totalSpent];
}
