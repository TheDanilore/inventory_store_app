import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';

/// Columnas canónicas y sus alias aceptados (ya normalizados, con "_").
const Map<String, List<String>> kImportColumnAliases = {
  'nombre': ['nombre', 'producto', 'nombre_producto'],
  'marca': ['marca', 'laboratorio', 'marca_laboratorio', 'laboratorio_marca'],
  'categoria': ['categoria'],
  'variante': ['variante', 'presentacion'],
  'sku': ['sku', 'codigo'],
  'precio_compra': ['precio_compra', 'costo', 'precio_costo', 'costo_compra'],
  'precio_venta': ['precio_venta', 'venta', 'pvp'],
  'precio_mayor': [
    'precio_mayor',
    'precio_mayorista',
    'precio_por_mayor',
    'mayorista',
  ],
  'cantidad_mayor': ['cantidad_mayor', 'cantidad_minima_mayor', 'min_mayor'],
  'stock': ['stock', 'stock_inicial', 'cantidad'],
  'usa_lotes': ['usa_lotes', 'lotes', 'maneja_lotes', 'tiene_lotes'],
  'lote': ['lote', 'nro_lote', 'codigo_lote'],
  'vencimiento': ['vencimiento', 'fecha_vencimiento', 'vence'],
  'componentes': [
    'componentes',
    'principio_activo',
    'componentes_quimicos',
    'composicion',
  ],
  'descripcion': ['descripcion'],
  'imagen_url': ['imagen_url', 'imagen', 'foto'],
};

const List<String> kRequiredColumns = [
  'nombre',
  'precio_compra',
  'precio_venta',
];

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

  Future<void> loadContext() async {
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
            // Un solo almacén → se usa automáticamente.
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

  // ───────────────────────────── Plantilla / reporte ─────────────────────────────

  Future<void> downloadTemplate({bool asExcel = true}) async {
    try {
      final rows = <List<dynamic>>[
        [
          'nombre',
          'marca',
          'categoria',
          'variante',
          'sku',
          'precio_compra',
          'precio_venta',
          'precio_mayor',
          'cantidad_mayor',
          'stock',
          'usa_lotes',
          'lote',
          'vencimiento',
          'componentes',
          'descripcion',
          'imagen_url',
        ],
        [
          'Paracetamol 500mg',
          'Genfar',
          'Analgésicos',
          '',
          'PAR-500',
          0.20,
          0.50,
          0.40,
          12,
          200,
          'si',
          'L2401',
          '2027-06-30',
          'Paracetamol',
          'Analgésico y antipirético',
          '',
        ],
        [
          'Paracetamol 500mg',
          'Genfar',
          'Analgésicos',
          '',
          'PAR-500',
          0.20,
          0.50,
          0.40,
          12,
          150,
          'si',
          'L2402',
          '2027-12-31',
          'Paracetamol',
          '',
          '',
        ],
        [
          'Ibuprofeno',
          'MK',
          'Antiinflamatorios',
          '400mg',
          'IBU-400',
          0.30,
          0.80,
          0.60,
          12,
          100,
          'si',
          'L9901',
          '2027-03-31',
          'Ibuprofeno',
          '',
          '',
        ],
        [
          'Ibuprofeno',
          'MK',
          'Antiinflamatorios',
          '600mg',
          'IBU-600',
          0.45,
          1.20,
          0.95,
          12,
          60,
          'si',
          'L9902',
          '2027-03-31',
          'Ibuprofeno',
          '',
          '',
        ],
        [
          'Alcohol medicinal 70%',
          'Alkofarma',
          'Insumos',
          '',
          'ALC-70',
          3.00,
          5.00,
          4.20,
          12,
          40,
          'no',
          '',
          '',
          'Alcohol etílico',
          '',
          '',
        ],
      ];

      if (asExcel) {
        final excel = Excel.createExcel();
        final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Plantilla Productos');
        final sheet = excel['Plantilla Productos'];

        for (final row in rows) {
          final cellRow = <CellValue?>[];
          for (final cell in row) {
            if (cell is int) {
              cellRow.add(IntCellValue(cell));
            } else if (cell is double) {
              cellRow.add(DoubleCellValue(cell));
            } else {
              cellRow.add(TextCellValue(cell.toString()));
            }
          }
          sheet.appendRow(cellRow);
        }

        // Usar encode() en lugar de save() para evitar descarga doble de 'FlutterExcel.xlsx' en Web
        final fileBytes = excel.encode();
        if (fileBytes != null) {
          final result = await FileExportService.save(
            fileName: 'plantilla_productos',
            bytes: Uint8List.fromList(fileBytes),
            extension: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
          _emitDownloadOutcome(result, 'Plantilla descargada correctamente.');
        }
      } else {
        final csv = Csv().encode(rows);
        // BOM UTF-8 para que Excel muestre bien las tildes.
        final bytes = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(csv),
        ]);
        final result = await FileExportService.save(
          fileName: 'plantilla_productos',
          bytes: bytes,
          extension: 'csv',
          mimeType: MimeType.csv,
        );
        _emitDownloadOutcome(result, 'Plantilla descargada correctamente.');
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error al descargar plantilla: $e'));
    }
  }

  Future<void> downloadIssuesReport({bool asExcel = true}) async {
    try {
      final rows = <List<dynamic>>[
        ['fila', 'columna', 'tipo', 'mensaje'],
        for (final r in state.rows)
          for (final i in r.issues)
            [
              i.line,
              i.column,
              i.severity == IssueSeverity.error ? 'error' : 'advertencia',
              i.message,
            ],
        for (final e in state.fileErrors) ['-', '-', 'error', e],
      ];

      if (asExcel) {
        final excel = Excel.createExcel();
        final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Reporte Incidencias');
        final sheet = excel['Reporte Incidencias'];

        for (final row in rows) {
          final cellRow = <CellValue?>[];
          for (final cell in row) {
            if (cell is int) {
              cellRow.add(IntCellValue(cell));
            } else {
              cellRow.add(TextCellValue(cell.toString()));
            }
          }
          sheet.appendRow(cellRow);
        }

        // Usar encode() en lugar de save() para evitar descarga doble de 'FlutterExcel.xlsx' en Web
        final fileBytes = excel.encode();
        if (fileBytes != null) {
          final result = await FileExportService.save(
            fileName: 'reporte_importacion',
            bytes: Uint8List.fromList(fileBytes),
            extension: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
          _emitDownloadOutcome(result, 'Reporte descargado correctamente.');
        }
      } else {
        final bytes = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(Csv().encode(rows)),
        ]);
        final result = await FileExportService.save(
          fileName: 'reporte_importacion',
          bytes: bytes,
          extension: 'csv',
          mimeType: MimeType.csv,
        );
        _emitDownloadOutcome(result, 'Reporte descargado correctamente.');
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error al descargar reporte: $e'));
    }
  }

  /// Traduce el resultado del guardado del archivo a un aviso para el usuario.
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
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'Error al leer el archivo: $e',
        ),
      );
    }
  }

  /// Procesa bytes directamente desde un archivo seleccionado o arrastrado (drag & drop).
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
      List<List<String>> table;
      if (_isExcelFile(fileName, bytes)) {
        table = _parseExcel(bytes);
      } else {
        var text = _decode(bytes);
        if (text.startsWith('\uFEFF')) text = text.substring(1);
        table = _parseCsv(text, _detectDelimiter(text));
      }
      await _analyze(fileName, table);
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.initial,
          errorMessage: 'Error al procesar archivo: $e',
        ),
      );
    }
  }

  bool _isExcelFile(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return true;
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) return true;
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      return true;
    }
    return false;
  }

  List<List<String>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    Sheet? sheet;
    for (final name in excel.tables.keys) {
      final s = excel.tables[name];
      if (s != null && s.maxRows > 0) {
        sheet = s;
        break;
      }
    }
    if (sheet == null) return const [];

    final result = <List<String>>[];
    for (final row in sheet.rows) {
      final rowStrings = <String>[];
      for (final cell in row) {
        rowStrings.add(_cellToString(cell?.value));
      }
      result.add(rowStrings);
    }
    return result;
  }

  String _cellToString(CellValue? val) {
    if (val == null) return '';
    if (val is TextCellValue) return val.value.text ?? '';
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) {
      if (val.value % 1 == 0) return val.value.toInt().toString();
      return val.value.toString();
    }
    if (val is BoolCellValue) return val.value ? 'si' : 'no';
    if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is DateTimeCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is TimeCellValue) return val.toString();
    if (val is FormulaCellValue) return val.formula;
    return val.toString();
  }

  String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes); // CSV guardado desde Excel "ANSI"
    }
  }

  String _detectDelimiter(String text) {
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    var best = ',';
    counts.forEach((k, v) {
      if (v > counts[best]!) best = k;
    });
    return best;
  }

  /// Parser CSV (RFC 4180) con delimitador configurable.
  List<List<String>> _parseCsv(String text, String d) {
    final rows = <List<String>>[];
    var row = <String>[];
    final f = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            f.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          f.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == d) {
        row.add(f.toString());
        f.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(f.toString());
        f.clear();
        rows.add(row);
        row = <String>[];
      } else {
        f.write(c);
      }
    }
    if (f.isNotEmpty || row.isNotEmpty) {
      row.add(f.toString());
      rows.add(row);
    }
    return rows;
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
    final colIndex = <String, int>{};
    for (var j = 0; j < table.first.length; j++) {
      final h = normalizeKey(table.first[j]).replaceAll(' ', '_');
      for (final e in kImportColumnAliases.entries) {
        if (e.value.contains(h) && !colIndex.containsKey(e.key)) {
          colIndex[e.key] = j;
        }
      }
    }
    final fileErrors = <String>[
      for (final req in kRequiredColumns)
        if (!colIndex.containsKey(req)) 'Falta la columna obligatoria "$req".',
    ];
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

    // 2) Filas
    final rows = <ImportRow>[];
    for (var i = 1; i < table.length; i++) {
      final cells = table[i];
      if (cells.every((c) => c.trim().isEmpty)) continue;
      String g(String key) {
        final idx = colIndex[key];
        if (idx == null || idx >= cells.length) return '';
        return cells[idx].trim();
      }

      rows.add(_parseRow(i + 1, g));
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

    // 3) Consultar lo que ya existe en la BD
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

    _classify(rows, existing);

    emit(
      state.copyWith(
        status: BulkImportStatus.review,
        fileName: fileName,
        rows: rows,
        fileErrors: const [],
        summary: _summarize(rows),
        canResume: false,
        clearImportError: true,
      ),
    );
  }

  // ───────────────────────────── Parseo de una fila ─────────────────────────────

  ImportRow _parseRow(int line, String Function(String) g) {
    final issues = <ImportIssue>[];
    void err(String c, String m) =>
        issues.add(ImportIssue(line, c, m, IssueSeverity.error));
    void warn(String c, String m) =>
        issues.add(ImportIssue(line, c, m, IssueSeverity.warning));

    final name = g('nombre');
    if (name.isEmpty) err('nombre', 'El nombre del producto es obligatorio.');

    double? money(String col, {required bool required}) {
      final raw = g(col);
      if (raw.isEmpty) {
        if (required) err(col, 'Es obligatorio.');
        return null;
      }
      final v = _num(raw);
      if (v == null) {
        err(col, 'Valor numérico inválido ("$raw").');
        return null;
      }
      if (v < 0) {
        err(col, 'No puede ser negativo.');
        return null;
      }
      return v;
    }

    final cost = money('precio_compra', required: true);
    final sale = money('precio_venta', required: true);
    final wholesale = money('precio_mayor', required: false);

    if (cost != null && sale != null && sale < cost) {
      warn('precio_venta', 'El precio de venta es menor al costo.');
    }
    if (wholesale != null && sale != null && wholesale > sale) {
      warn('precio_mayor', 'El precio por mayor supera al precio de venta.');
    }
    if (wholesale != null && cost != null && wholesale < cost) {
      warn('precio_mayor', 'El precio por mayor es menor al costo.');
    }

    int? minQty;
    final minQtyRaw = g('cantidad_mayor');
    if (minQtyRaw.isNotEmpty) {
      final v = _num(minQtyRaw);
      if (v == null || v < 1 || v != v.roundToDouble()) {
        err('cantidad_mayor', 'Debe ser un entero mayor o igual a 1.');
      } else {
        minQty = v.round();
        if (wholesale == null) {
          warn('cantidad_mayor', 'Se ignora: no hay precio por mayor.');
        }
      }
    } else if (wholesale != null) {
      warn(
        'cantidad_mayor',
        'Hay precio por mayor sin cantidad mínima; se guardará sin mínimo.',
      );
    }

    int? stock;
    final stockRaw = g('stock');
    if (stockRaw.isNotEmpty) {
      final v = _num(stockRaw);
      if (v == null) {
        err('stock', 'Cantidad inválida ("$stockRaw").');
      } else if (v < 0) {
        err('stock', 'La cantidad no puede ser negativa.');
      } else if (v != v.roundToDouble()) {
        err('stock', 'La cantidad debe ser un número entero.');
      } else {
        stock = v.round();
      }
    }

    bool? usesLots;
    final lotsRaw = normalizeKey(g('usa_lotes'));
    if (lotsRaw.isNotEmpty) {
      if (const ['si', 's', '1', 'true', 'yes', 'y'].contains(lotsRaw)) {
        usesLots = true;
      } else if (const ['no', 'n', '0', 'false'].contains(lotsRaw)) {
        usesLots = false;
      } else {
        err('usa_lotes', 'Use "si" o "no" (recibido "${g('usa_lotes')}").');
      }
    }

    final lot = g('lote');
    final expiryRaw = g('vencimiento');
    DateTime? expiry;
    if (expiryRaw.isNotEmpty) {
      expiry = _date(expiryRaw);
      if (expiry == null) {
        err('vencimiento', 'Fecha inválida. Use AAAA-MM-DD o DD/MM/AAAA.');
      } else {
        final today = DateTime.now();
        if (expiry.isBefore(DateTime(today.year, today.month, today.day))) {
          warn('vencimiento', 'La fecha de vencimiento ya pasó.');
        }
      }
    }
    // Si trae lote/vencimiento pero no dice usa_lotes → se infiere que sí.
    usesLots ??= (lot.isNotEmpty || expiryRaw.isNotEmpty) ? true : null;

    return ImportRow(
      line: line,
      productName: name,
      brand: g('marca'),
      category: g('categoria'),
      variantName: g('variante'),
      sku: g('sku'),
      description: g('descripcion'),
      imageUrl: g('imagen_url'),
      components: g('componentes'),
      lotCode: lot,
      expiryRaw: expiryRaw,
      expiry: expiry,
      cost: cost,
      salePrice: sale,
      wholesalePrice: wholesale,
      wholesaleMinQty: minQty,
      stock: stock,
      usesLotsRaw: usesLots,
      issues: issues,
    );
  }

  double? _num(String raw) {
    var s = raw.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll(',', ''); // 1,234.50
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.'); // 10,50
    }
    return double.tryParse(s);
  }

  DateTime? _date(String s) {
    DateTime? mk(int y, int m, int d) {
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      final dt = DateTime(y, m, d);
      return dt.month == m ? dt : null;
    }

    var m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m != null) {
      return mk(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(s);
    if (m != null) {
      return mk(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }
    return null;
  }

  // ───────────────────────────── Clasificación ─────────────────────────────

  void _classify(List<ImportRow> rows, List<ExistingVariant> existing) {
    final bySku = <String, ExistingVariant>{
      for (final e in existing)
        if (e.sku.isNotEmpty) normalizeKey(e.sku): e,
    };
    final byProductVariant = <String, ExistingVariant>{
      for (final e in existing)
        '${e.productKey}|${normalizeKey(e.variantName)}': e,
    };
    final existingProducts = <String, ExistingVariant>{
      for (final e in existing) e.productKey: e,
    };

    // Consistencia a nivel de producto (usa_lotes / categoría / componentes)
    final byProduct = <String, List<ImportRow>>{};
    for (final r in rows) {
      byProduct.putIfAbsent(r.productKey, () => []).add(r);
    }
    final productLots = <String, bool>{};
    byProduct.forEach((key, list) {
      final set = list.map((r) => r.usesLotsRaw).whereType<bool>().toSet();
      if (set.length > 1) {
        for (final r in list) {
          r.error(
            'usa_lotes',
            'Las filas de este producto mezclan "si" y "no" en usa_lotes.',
          );
        }
      }
      productLots[key] = set.contains(true);

      String? cat;
      String? comp;
      for (final r in list) {
        if (r.category.isNotEmpty) {
          cat ??= r.category;
          if (normalizeKey(cat) != normalizeKey(r.category)) {
            r.warn(
              'categoria',
              'Categoría distinta dentro del mismo producto; se usará "$cat".',
            );
          }
        }
        if (r.components.isNotEmpty) {
          comp ??= r.components;
          if (normalizeKey(comp) != normalizeKey(r.components)) {
            r.warn(
              'componentes',
              'Componentes distintos dentro del mismo producto; se usarán los de la primera fila.',
            );
          }
        }
      }
    });

    final seen = <String, int>{}; // variantKey|lote → línea
    final seenVariants = <String>{}; // variantes ya vistas en el archivo
    final skuOwner = <String, String>{}; // sku → productKey

    for (final r in rows) {
      if (r.productName.isEmpty) continue;

      // Producto/variante existente
      ExistingVariant? ex;
      if (r.sku.isNotEmpty) {
        ex = bySku[normalizeKey(r.sku)];
        if (ex != null && ex.productKey != r.productKey) {
          r.error(
            'sku',
            'El SKU ya pertenece a otro producto: "${ex.productName}"${ex.brandName.isEmpty ? '' : ' (${ex.brandName})'}.',
          );
          ex = null;
        } else if (ex == null) {
          final sameName =
              byProductVariant['${r.productKey}|${normalizeKey(r.variantName)}'];
          if (sameName != null) {
            r.error(
              'sku',
              'Esa variante ya existe con otro SKU (${sameName.sku.isEmpty ? 'sin SKU' : sameName.sku}). Usa ese SKU o cambia la variante.',
            );
          }
        }
        // SKU repetido en el archivo con productos distintos
        final owner = skuOwner[normalizeKey(r.sku)];
        if (owner != null && owner != r.productKey) {
          r.error('sku', 'El SKU se repite en otro producto del archivo.');
        } else {
          skuOwner[normalizeKey(r.sku)] = r.productKey;
        }
      } else {
        ex = byProductVariant['${r.productKey}|${normalizeKey(r.variantName)}'];
      }

      r.existing = ex;
      if (ex != null) {
        r.action = ImportRowAction.updateVariant;
      } else if (existingProducts.containsKey(r.productKey)) {
        r.action = ImportRowAction.addVariant;
      } else {
        r.action = ImportRowAction.createProduct;
      }

      // Lotes efectivos
      final lots =
          existingProducts[r.productKey]?.usesLots ??
          productLots[r.productKey] ??
          false;
      r.effectiveUsesLots = lots;
      final qty = r.stock ?? 0;
      if (lots) {
        if (qty > 0) {
          if (r.lotCode.isEmpty) {
            r.error('lote', 'El producto usa lotes: indica el código de lote.');
          }
          if (r.expiryRaw.isEmpty) {
            r.error(
              'vencimiento',
              'El producto usa lotes: indica el vencimiento.',
            );
          }
        }
      } else if (r.lotCode.isNotEmpty || r.expiryRaw.isNotEmpty) {
        r.warn(
          'lote',
          'El producto no maneja lotes; se ignorarán lote y vencimiento.',
        );
      }

      // Stock sin almacén
      if (qty > 0 && state.selectedWarehouseId == null) {
        r.error(
          'stock',
          'No hay almacén creado para cargar stock. Crea uno primero.',
        );
      }

      // Misma variante con otro lote → no es una variante/producto nuevo
      r.isExtraLot = !seenVariants.add(r.variantKey) && lots;

      // Duplicados dentro del archivo
      final dupKey = '${r.variantKey}|${lots ? normalizeKey(r.lotCode) : ''}';
      final first = seen[dupKey];
      if (first != null) {
        r.error(
          'nombre',
          'Duplicado de la fila $first${lots ? ' (mismo lote)' : ''}. Cada variante${lots ? '/lote' : ''} debe aparecer una sola vez.',
        );
      } else {
        seen[dupKey] = r.line;
      }
    }
  }

  ImportSummary _summarize(List<ImportRow> rows) {
    final valid = rows.where((r) => !r.hasError).toList();
    final brands = {for (final b in state.brandNames) normalizeKey(b)};
    final cats = {for (final c in state.categoryNames) normalizeKey(c)};
    final newBrands = <String>{};
    final newCats = <String>{};
    for (final r in valid.where(
      (r) => r.action == ImportRowAction.createProduct,
    )) {
      if (r.brand.isNotEmpty && !brands.contains(normalizeKey(r.brand))) {
        newBrands.add(normalizeKey(r.brand));
      }
      if (r.category.isNotEmpty && !cats.contains(normalizeKey(r.category))) {
        newCats.add(normalizeKey(r.category));
      }
    }
    return ImportSummary(
      totalRows: rows.length,
      validRows: valid.length,
      errorRows: rows.length - valid.length,
      warningRows: valid.where((r) => r.hasWarning).length,
      newProducts:
          valid
              .where((r) => r.action == ImportRowAction.createProduct)
              .map((r) => r.productKey)
              .toSet()
              .length,
      newVariants:
          valid
              .where((r) => r.action != ImportRowAction.updateVariant)
              .map((r) => r.variantKey)
              .toSet()
              .length,
      updatedVariants:
          valid
              .where((r) => r.action == ImportRowAction.updateVariant)
              .map((r) => r.variantKey)
              .toSet()
              .length,
      units: valid.fold<int>(0, (a, r) => a + (r.stock ?? 0)),
      lots:
          valid.where((r) => r.effectiveUsesLots && (r.stock ?? 0) > 0).length,
      newBrands: newBrands.length,
      newCategories: newCats.length,
    );
  }

  // ───────────────────────────── Carga al servidor ─────────────────────────────

  List<Map<String, dynamic>> _buildPayload(List<ImportRow> valid) {
    final replace = state.stockMode == ImportStockMode.replace;
    final products = <String, Map<String, dynamic>>{};

    for (final r in valid) {
      final p = products.putIfAbsent(
        r.productKey,
        () => {
          'product_id': r.existing?.productId,
          'name': r.productName,
          'brand_name': r.brand,
          'category_name': r.category,
          'description': r.description,
          'components': r.components,
          'uses_lots': r.effectiveUsesLots,
          'variants': <String, Map<String, dynamic>>{},
        },
      );
      // Datos a nivel de producto: primera fila que los traiga
      if ((p['category_name'] as String).isEmpty && r.category.isNotEmpty) {
        p['category_name'] = r.category;
      }
      if ((p['components'] as String).isEmpty && r.components.isNotEmpty) {
        p['components'] = r.components;
      }
      if ((p['description'] as String).isEmpty && r.description.isNotEmpty) {
        p['description'] = r.description;
      }
      p['product_id'] ??= r.existing?.productId;

      final variants = p['variants'] as Map<String, Map<String, dynamic>>;
      final v = variants.putIfAbsent(
        r.variantKey,
        () => {
          'variant_id': r.existing?.variantId,
          'sku': r.sku.isEmpty ? null : r.sku,
          'variant_name': r.variantName.isEmpty ? null : r.variantName,
          'unit_cost': r.cost,
          'sale_price': r.salePrice,
          'wholesale_price': r.wholesalePrice,
          'wholesale_min_quantity': r.wholesaleMinQty,
          'image_url': r.imageUrl.isEmpty ? null : r.imageUrl,
          'stock_entries': <Map<String, dynamic>>[],
        },
      );

      final qty = r.stock;
      final isExisting = r.existing != null;
      if (qty != null && (qty > 0 || (replace && isExisting))) {
        (v['stock_entries'] as List<Map<String, dynamic>>).add({
          'quantity': qty,
          'lot_code': r.effectiveUsesLots ? r.lotCode : null,
          'expiry_date':
              r.effectiveUsesLots && r.expiry != null
                  ? _fmtDate(r.expiry!)
                  : null,
        });
      }
    }

    return [
      for (final p in products.values)
        {
          ...p,
          'variants':
              (p['variants'] as Map<String, Map<String, dynamic>>).values
                  .toList(),
        },
    ];
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Importa solo las filas sin error. Si un lote falla se puede reanudar
  /// con [resumeImport] sin duplicar lo ya cargado.
  Future<void> startImport() async {
    final valid = state.rows.where((r) => !r.hasError).toList();
    if (valid.isEmpty || state.status == BulkImportStatus.importing) return;

    _payload = _buildPayload(valid);
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
          batchId: '$_importId-$_nextBatch', // idempotencia en el servidor
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
    } catch (e) {
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
