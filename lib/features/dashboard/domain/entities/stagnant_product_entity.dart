import 'package:equatable/equatable.dart';

/// Representa un producto sin rotación / con baja salida y capital inmovilizado
class StagnantProductEntity extends Equatable {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;
  final int currentStock;
  final double unitCost;
  final double salePrice;
  final double tiedUpCapital;
  final int daysWithoutSale;
  final DateTime? lastSaleDate;

  const StagnantProductEntity({
    required this.id,
    required this.name,
    this.category = 'General',
    this.imageUrl,
    required this.currentStock,
    this.unitCost = 0.0,
    this.salePrice = 0.0,
    required this.tiedUpCapital,
    required this.daysWithoutSale,
    this.lastSaleDate,
  });

  String get formattedDaysWithoutSale {
    if (lastSaleDate == null) {
      return 'Sin ventas registradas';
    }
    if (daysWithoutSale <= 0) {
      return 'Vendido hoy';
    }
    return '$daysWithoutSale días sin rotación';
  }

  String get statusLabel {
    if (daysWithoutSale >= 60 || lastSaleDate == null) {
      return 'Crítico (Inmóvil)';
    }
    if (daysWithoutSale >= 30) {
      return 'Lenta salida';
    }
    return 'Estancado';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    imageUrl,
    currentStock,
    unitCost,
    salePrice,
    tiedUpCapital,
    daysWithoutSale,
    lastSaleDate,
  ];
}
