import 'package:equatable/equatable.dart';

class DocumentSeriesEntity extends Equatable {
  final String id;
  final String documentType; // 'NOTA_VENTA', 'BOLETA', 'FACTURA'
  final String series; // 'NV01', 'B001', 'F001'
  final int currentCorrelative;
  final int correlativePadding;
  final bool isDefault;
  final bool isActive;
  final String? warehouseId;

  const DocumentSeriesEntity({
    required this.id,
    required this.documentType,
    required this.series,
    this.currentCorrelative = 0,
    this.correlativePadding = 8,
    this.isDefault = true,
    this.isActive = true,
    this.warehouseId,
  });

  String get nextFormattedNumber {
    final next = currentCorrelative + 1;
    final padded = next.toString().padLeft(correlativePadding, '0');
    return '$series-$padded';
  }

  @override
  List<Object?> get props => [
    id,
    documentType,
    series,
    currentCorrelative,
    correlativePadding,
    isDefault,
    isActive,
    warehouseId,
  ];
}
