import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@injectable
class BulkImportCubit extends Cubit<BulkImportState> {
  final ProductsRepository productsRepository;

  BulkImportCubit({required this.productsRepository}) : super(const BulkImportState());

  void setWarehouseId(String? warehouseId) {
    emit(state.copyWith(selectedWarehouseId: warehouseId));
  }

  Future<void> pickAndParseFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (files.isNotEmpty) {
        emit(state.copyWith(status: BulkImportStatus.parsing, clearErrorMessage: true));
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final csvString = utf8.decode(bytes);
          final List<List<dynamic>> rows = Csv().decode(csvString);
          _validateAndProcessCsv(rows);
        } else {
          emit(state.copyWith(status: BulkImportStatus.error, errorMessage: 'No se pudo leer el contenido del archivo.'));
        }
      }
    } catch (e) {
      emit(state.copyWith(status: BulkImportStatus.error, errorMessage: 'Error al seleccionar archivo: $e'));
    }
  }

  void _validateAndProcessCsv(List<List<dynamic>> rows) {
    if (rows.isEmpty || rows.length == 1) {
      emit(state.copyWith(status: BulkImportStatus.error, errorMessage: 'El archivo está vacío o solo contiene encabezados.'));
      return;
    }

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final dataRows = rows.skip(1).toList();

    List<Map<String, dynamic>> parsedData = [];
    List<String> validationErrors = [];

    // Required columns
    final requiredColumns = ['nombre', 'sku', 'costo'];
    for (var req in requiredColumns) {
      if (!headers.contains(req)) {
        validationErrors.add('Columna requerida faltante: "$req"');
      }
    }

    if (validationErrors.isNotEmpty) {
      emit(state.copyWith(status: BulkImportStatus.error, errors: validationErrors));
      return;
    }

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || row.every((element) => element.toString().trim().isEmpty)) continue; // Skip empty rows

      Map<String, dynamic> rowData = {};
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length) {
          rowData[headers[j]] = row[j];
        } else {
          rowData[headers[j]] = null;
        }
      }

      // Validations
      final name = rowData['nombre']?.toString().trim() ?? '';
      final sku = rowData['sku']?.toString().trim() ?? '';
      final costoStr = rowData['costo']?.toString() ?? '';

      if (name.isEmpty) validationErrors.add('Fila ${i + 2}: Nombre del producto está vacío.');
      if (sku.isEmpty) validationErrors.add('Fila ${i + 2}: SKU está vacío.');
      
      final costo = double.tryParse(costoStr);
      if (costo == null) {
        validationErrors.add('Fila ${i + 2}: Precio de costo inválido ($costoStr).');
      } else {
        rowData['costo_parsed'] = costo;
      }

      final ventaStr = rowData['precio_venta']?.toString() ?? '';
      if (ventaStr.isNotEmpty) {
        final venta = double.tryParse(ventaStr);
        if (venta == null) {
           validationErrors.add('Fila ${i + 2}: Precio de venta inválido ($ventaStr).');
        } else {
           rowData['precio_venta_parsed'] = venta;
        }
      }

      final stockStr = rowData['stock_inicial']?.toString() ?? '';
      if (stockStr.isNotEmpty) {
        final stock = int.tryParse(stockStr.split('.').first); // in case it's 10.0
        if (stock == null) {
          validationErrors.add('Fila ${i + 2}: Stock inicial inválido ($stockStr).');
        } else {
          rowData['stock_inicial_parsed'] = stock;
        }
      }

      parsedData.add(rowData);
    }

    // Duplicate SKU check
    final skus = parsedData.map((e) => e['sku'].toString()).toList();
    if (skus.length != skus.toSet().length) {
      validationErrors.add('Hay SKUs duplicados en el archivo CSV.');
    }

    if (validationErrors.isNotEmpty) {
      emit(state.copyWith(status: BulkImportStatus.error, errors: validationErrors));
    } else {
      emit(state.copyWith(status: BulkImportStatus.validationDone, parsedRows: parsedData, errors: [], clearErrorMessage: true));
    }
  }

  void reset() {
    emit(const BulkImportState());
  }

  Future<void> uploadData() async {
    if (state.parsedRows.isEmpty) return;
    emit(state.copyWith(status: BulkImportStatus.uploading));

    try {
      final payload = state.parsedRows.map((row) => {
        'name': row['nombre'],
        'description': row['descripcion']?.toString() ?? '',
        'category_name': row['categoria']?.toString() ?? '',
        'sku': row['sku'],
        'unit_cost': row['costo_parsed'],
        'sale_price': row['precio_venta_parsed'],
        'initial_stock': row['stock_inicial_parsed'] ?? 0,
        'image_url': row['imagen_url']?.toString() ?? '',
      }).toList();

      final result = await productsRepository.importCatalogBatch(payload, state.selectedWarehouseId);
      
      result.fold(
        (failure) => emit(state.copyWith(status: BulkImportStatus.error, errorMessage: failure.message)),
        (_) => emit(state.copyWith(status: BulkImportStatus.success))
      );
    } catch (e) {
      emit(state.copyWith(status: BulkImportStatus.error, errorMessage: e.toString()));
    }
  }
}
