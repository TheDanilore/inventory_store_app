import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';

enum BulkImportStatus {
  initial,
  loadingContext,
  parsing,
  review,
  importing,
  success,
}

class BulkImportState extends Equatable {
  final BulkImportStatus status;

  // Contexto cargado del servidor
  final List<ImportWarehouse> warehouses;
  final List<String> brandNames;
  final List<String> categoryNames;

  // Configuración elegida por el usuario
  final String? selectedWarehouseId;
  final ImportStockMode stockMode;
  final bool updatePrices;

  // Archivo analizado
  final String? fileName;
  final List<ImportRow> rows;
  final List<String> fileErrors;
  final ImportSummary summary;

  // Importación
  final double progress;
  final bool canResume;
  final String? importError;
  final ImportBatchResult? result;

  /// Mensaje transitorio (snackbar).
  final String? errorMessage;

  const BulkImportState({
    this.status = BulkImportStatus.initial,
    this.warehouses = const [],
    this.brandNames = const [],
    this.categoryNames = const [],
    this.selectedWarehouseId,
    this.stockMode = ImportStockMode.add,
    this.updatePrices = false,
    this.fileName,
    this.rows = const [],
    this.fileErrors = const [],
    this.summary = const ImportSummary(),
    this.progress = 0,
    this.canResume = false,
    this.importError,
    this.result,
    this.errorMessage,
  });

  ImportWarehouse? get selectedWarehouse {
    for (final w in warehouses) {
      if (w.id == selectedWarehouseId) return w;
    }
    return null;
  }

  bool get needsWarehouseChoice =>
      warehouses.length > 1 && selectedWarehouseId == null;

  BulkImportState copyWith({
    BulkImportStatus? status,
    List<ImportWarehouse>? warehouses,
    List<String>? brandNames,
    List<String>? categoryNames,
    String? selectedWarehouseId,
    ImportStockMode? stockMode,
    bool? updatePrices,
    String? fileName,
    List<ImportRow>? rows,
    List<String>? fileErrors,
    ImportSummary? summary,
    double? progress,
    bool? canResume,
    String? importError,
    bool clearImportError = false,
    ImportBatchResult? result,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return BulkImportState(
      status: status ?? this.status,
      warehouses: warehouses ?? this.warehouses,
      brandNames: brandNames ?? this.brandNames,
      categoryNames: categoryNames ?? this.categoryNames,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      stockMode: stockMode ?? this.stockMode,
      updatePrices: updatePrices ?? this.updatePrices,
      fileName: fileName ?? this.fileName,
      rows: rows ?? this.rows,
      fileErrors: fileErrors ?? this.fileErrors,
      summary: summary ?? this.summary,
      progress: progress ?? this.progress,
      canResume: canResume ?? this.canResume,
      importError: clearImportError ? null : (importError ?? this.importError),
      result: result ?? this.result,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    warehouses,
    brandNames,
    categoryNames,
    selectedWarehouseId,
    stockMode,
    updatePrices,
    fileName,
    rows,
    fileErrors,
    summary,
    progress,
    canResume,
    importError,
    result,
    errorMessage,
  ];
}
