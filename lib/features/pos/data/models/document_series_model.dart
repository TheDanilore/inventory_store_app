import 'package:inventory_store_app/features/pos/domain/entities/document_series_entity.dart';

class DocumentSeriesModel extends DocumentSeriesEntity {
  const DocumentSeriesModel({
    required super.id,
    required super.documentType,
    required super.series,
    super.currentCorrelative,
    super.correlativePadding,
    super.isDefault,
    super.isActive,
    super.warehouseId,
  });

  factory DocumentSeriesModel.fromJson(Map<String, dynamic> json) {
    return DocumentSeriesModel(
      id: json['id'] as String,
      documentType: json['document_type'] as String? ?? 'NOTA_VENTA',
      series: json['series'] as String? ?? 'NV01',
      currentCorrelative: (json['current_correlative'] as num?)?.toInt() ?? 0,
      correlativePadding: (json['correlative_padding'] as num?)?.toInt() ?? 8,
      isDefault: json['is_default'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      warehouseId: json['warehouse_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_type': documentType,
      'series': series,
      'current_correlative': currentCorrelative,
      'correlative_padding': correlativePadding,
      'is_default': isDefault,
      'is_active': isActive,
      'warehouse_id': warehouseId,
    };
  }
}
