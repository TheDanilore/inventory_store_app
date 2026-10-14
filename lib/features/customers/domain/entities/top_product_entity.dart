import 'package:equatable/equatable.dart';

class TopProductEntity extends Equatable {
  final String productName;
  final int totalQuantity;
  final double totalSpent;
  final String? imageUrl;

  const TopProductEntity({
    required this.productName,
    required this.totalQuantity,
    required this.totalSpent,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [productName, totalQuantity, totalSpent, imageUrl];
}
