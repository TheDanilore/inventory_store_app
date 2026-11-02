import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/services/bulk_import_file_parser_service.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/services/bulk_import_report_service.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/services/bulk_import_validation_service.dart';

export 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/services/bulk_import_validation_service.dart'
    show kImportColumnAliases, kRequiredColumns;

@injectable
class BulkImportCubit extends Cubit<BulkImportState> {
  final ProductsRepository productsRepository;

  static const int _maxRows = 5000;
  static const int _batchSize = 50;

  // Estado interno de la importación (permite reanudar si un lote falla)
  List<Map<String, dynamic>> _payload = const [];
  int _nextBatch = 0;
  String _importId = '';
  ImportBatchResult _accumulated = const ImportBatchResult();

  BulkImportCubit({required this.productsRepository})
    : super(const BulkImportState());

  // ───────────────────────── Contexto y configuración ─────────────────────────

  /// Carga almacenes, marcas y categorías.
  /// Política Zero-Shimmer: Si ya hay datos en memoria y no se fuerza refresco,
  /// se muestran los datos en Frame 0 sin parpadeo de carga.
  Future<void> loadContext({bool forceRefresh = false}) async {
    if (state.warehouses.isNotEmpty && !forceRefresh) {
      return;
    }

    emit(
      state.copyWith(
        status: BulkImportStatus.loadingContext,
        clearErrorMessage: true,
      ),
    );

    final res = await productsRepository.getImportCatalogContext();
    if (isClosed) return;

    res.fold(
      (failure) => emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'No se pudo cargar almacenes: ${failure.message}',
        ),
      ),
      (ctx) {
        emit(
          state.copyWith(
            status: BulkImportStatus.initial,
            warehouses: ctx.warehouses,
            brandNames: ctx.brandNames,
            categoryNames: ctx.categoryNames,
            // Un solo almacén → se pre-selecciona automáticamente
            selectedWarehouseId:
                ctx.warehouses.length == 1 ? ctx.warehouses.first.id : null,
          ),
        );
      },
    );
  }

  void setWarehouseId(String id) =>
      emit(state.copyWith(selectedWarehouseId: id));
  void setStockMode(ImportStockMode m) => emit(state.copyWith(stockMode: m));
  void setUpdatePrices(bool v) => emit(state.copyWith(updatePrices: v));

  /// Vuelve al paso 1 conservando la configuración.
  void reset() {
    _payload = const [];
    _nextBatch = 0;
    _accumulated = const ImportBatchResult();
    emit(
      BulkImportState(
        warehouses: state.warehouses,
        brandNames: state.brandNames,
        categoryNames: state.categoryNames,
        selectedWarehouseId: state.selectedWarehouseId,
        stockMode: state.stockMode,
        updatePrices: state.updatePrices,
      ),
    );
  }

  // ───────────────────────────── Plantilla / reporte ─────────────────────────────

  Future<void> downloadTemplate({bool asExcel = true}) async {
    try {
      final result = await BulkImportReportService.downloadTemplate(
        asExcel: asExcel,
      );
      _emitDownloadOutcome(result, 'Plantilla descargada correctamente.');
    } catch (e, st) {
      LoggerService.e(
        'Error al descargar plantilla',
        tag: 'BULK_IMPORT',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(errorMessage: 'Error al descargar plantilla: $e'));
    }
  }

  Future<void> downloadIssuesReport({bool asExcel = true}) async {
    try {
      final result = await BulkImportReportService.downloadIssuesReport(
        rows: state.rows,
        fileErrors: state.fileErrors,
        asExcel: asExcel,
      );
      _emitDownloadOutcome(result, 'Reporte descargado correctamente.');
    } catch (e, st) {
      LoggerService.e(
        'Error al descargar reporte de incidencias',
        tag: 'BULK_IMPORT',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(errorMessage: 'Error al descargar reporte: $e'));
    }
  }

  /// Traduce el resultado del guardado del archivo a un aviso para el usuario
  void _emitDownloadOutcome(FileExportResult result, String successMessage) {
    switch (result.outcome) {
      case FileExportOutcome.saved:
        emit(state.copyWith(successMessage: successMessage));
        break;
      case FileExportOutcome.cancelled:
        emit(state.copyWith(errorMessage: 'Descarga cancelada.'));
        break;
      case FileExportOutcome.failed:
        emit(
          state.copyWith(
            errorMessage: 'No se pudo guardar el archivo: ${result.error}',
          ),
        );
        break;
    }
  }

  // ───────────────────────────── Selección y análisis ─────────────────────────────

  Future<void> pickAndParseFile() async {
    if (state.needsWarehouseChoice) {
      emit(
        state.copyWith(errorMessage: 'Selecciona primero el almacén destino.'),
      );
      return;
    }
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      await parseBytes(fileName: file.name, bytes: bytes);
    } catch (e, st) {
      LoggerService.e(
        'Error al seleccionar archivo',
        tag: 'BULK_IMPORT',
        error: e,
        stackTrace: st,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'Error al leer el archivo: $e',
        ),
      );
    }
  }

  /// Procesa bytes desde archivo seleccionado o arrastrado (drag & drop).
  /// Ejecuta el parseo en un Isolate de fondo mediante compute() para 0 jank en UI.
  Future<void> parseBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (state.needsWarehouseChoice) {
      emit(
        state.copyWith(errorMessage: 'Selecciona primero el almacén destino.'),
      );
      return;
    }
    if (bytes.isEmpty) {
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'El archivo está vacío.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BulkImportStatus.parsing,
        clearErrorMessage: true,
        clearImportError: true,
      ),
    );

    try {
      // Procesamiento asíncrono en Isolate secundario (evita freeze del UI thread)
      final table = await compute(
        BulkImportFileParserService.parseSpreadsheetInIsolate,
        {'fileName': fileName, 'bytes': bytes},
      );

      await _analyze(fileName, table);
    } catch (e, st) {
      LoggerService.e(
        'Error al procesar archivo en Isolate',
        tag: 'BULK_IMPORT',
        error: e,
        stackTrace: st,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'Error al procesar archivo: $e',
        ),
      );
    }
  }

  Future<void> _analyze(String fileName, List<List<String>> table) async {
    if (table.length < 2) {
      emit(
        state.copyWith(
          status: BulkImportStatus.review,
          fileName: fileName,
          rows: const [],
          fileErrors: const [
            'El archivo está vacío o solo contiene encabezados.',
          ],
          summary: const ImportSummary(),
        ),
      );
      return;
    }

    // 1) Encabezados → columnas canónicas
    final colIndex = BulkImportValidationService.mapHeaders(table.first);
    final fileErrors = BulkImportValidationService.checkMissingRequiredColumns(
      colIndex,
    );

    if (fileErrors.isNotEmpty) {
      emit(
        state.copyWith(
          status: BulkImportStatus.review,
          fileName: fileName,
          rows: const [],
          fileErrors: fileErrors,
          summary: const ImportSummary(),
        ),
      );
      return;
    }

    // 2) Parseo de filas
    final rows = <ImportRow>[];
    for (var i = 1; i < table.length; i++) {
      final cells = table[i];
      if (cells.every((c) => c.trim().isEmpty)) continue;
      String g(String key) {
        final idx = colIndex[key];
        if (idx == null || idx >= cells.length) return '';
        return cells[idx].trim();
      }

      rows.add(BulkImportValidationService.parseRow(i + 1, g));
    }

    if (rows.length > _maxRows) {
      emit(
        state.copyWith(
          status: BulkImportStatus.review,
          fileName: fileName,
          rows: const [],
          fileErrors: [
            'El archivo tiene ${rows.length} filas. El máximo por importación es $_maxRows; divídelo en varios archivos.',
          ],
          summary: const ImportSummary(),
        ),
      );
      return;
    }

    // 3) Consultar variantes existentes en la BD
    final names =
        rows
            .where((r) => r.productName.isNotEmpty)
            .map((r) => r.productName)
            .toSet()
            .toList();
    final skus =
        rows.where((r) => r.sku.isNotEmpty).map((r) => r.sku).toSet().toList();

    String? lookupError;
    final existing = (await productsRepository.findExistingVariants(
      productNames: names,
      skus: skus,
      warehouseId: state.selectedWarehouseId,
    )).fold<List<ExistingVariant>?>((f) {
      lookupError = f.message;
      return null;
    }, (v) => v);

    if (isClosed) return;
    if (existing == null) {
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'No se pudo verificar el catálogo: $lookupError',
        ),
      );
      return;
    }

    // 4) Clasificación y reglas de negocio
    BulkImportValidationService.classify(
      rows: rows,
      existing: existing,
      selectedWarehouseId: state.selectedWarehouseId,
    );

    emit(
      state.copyWith(
        status: BulkImportStatus.review,
        fileName: fileName,
        rows: rows,
        fileErrors: const [],
        summary: BulkImportValidationService.summarize(
          rows: rows,
          brandNames: state.brandNames,
          categoryNames: state.categoryNames,
        ),
        canResume: false,
        clearImportError: true,
      ),
    );
  }

  // ───────────────────────────── Carga al servidor ─────────────────────────────

  /// Inicia la importación en lotes de los productos válidos
  Future<void> startImport() async {
    final valid = state.rows.where((r) => !r.hasError).toList();
    if (valid.isEmpty || state.status == BulkImportStatus.importing) return;

    _payload = BulkImportValidationService.buildPayload(
      valid: valid,
      stockMode: state.stockMode,
    );
    _nextBatch = 0;
    _accumulated = const ImportBatchResult();
    _importId = DateTime.now().microsecondsSinceEpoch.toString();
    await _runBatches();
  }

  Future<void> resumeImport() async {
    if (_payload.isEmpty || state.status == BulkImportStatus.importing) return;
    await _runBatches();
  }

  Future<void> _runBatches() async {
    emit(
      state.copyWith(
        status: BulkImportStatus.importing,
        progress:
            _payload.isEmpty ? 0 : _nextBatch * _batchSize / _payload.length,
        clearImportError: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
        canResume: false,
      ),
    );

    try {
      while (_nextBatch * _batchSize < _payload.length) {
        final start = _nextBatch * _batchSize;
        final end =
            (start + _batchSize < _payload.length)
                ? start + _batchSize
                : _payload.length;

        final res = await productsRepository.importCatalogBatch(
          products: _payload.sublist(start, end),
          warehouseId: state.selectedWarehouseId,
          stockMode: state.stockMode == ImportStockMode.add ? 'add' : 'replace',
          updatePrices: state.updatePrices,
          batchId: '$_importId-$_nextBatch', // Idempotencia en el servidor
        );
        if (isClosed) return;

        String? failMsg;
        final ok = res.fold<ImportBatchResult?>((f) {
          failMsg = f.message;
          return null;
        }, (r) => r);

        if (ok == null) {
          emit(
            state.copyWith(
              status: BulkImportStatus.review,
              importError:
                  'Falló el lote ${_nextBatch + 1} de ${(_payload.length / _batchSize).ceil()}: $failMsg. '
                  'Ya se importaron $start de ${_payload.length} productos; el resto no se procesó.',
              canResume: true,
            ),
          );
          return;
        }

        _accumulated = _accumulated + ok;
        _nextBatch++;
        emit(state.copyWith(progress: end / _payload.length));
      }

      _payload = const [];
      emit(
        state.copyWith(
          status: BulkImportStatus.success,
          result: _accumulated,
          progress: 1,
          canResume: false,
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado durante la importación por lotes',
        tag: 'BULK_IMPORT',
        error: e,
        stackTrace: st,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.review,
          importError: 'Error inesperado: $e',
          canResume: _payload.isNotEmpty,
        ),
      );
    }
  }
}
