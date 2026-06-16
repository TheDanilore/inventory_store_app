import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/kardex_movement_model.dart';

class KardexProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<KardexMovementModel> _movements = [];
  List<KardexMovementModel> get movements => _movements;

  // Filtros
  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  String _typeFilter = 'ALL'; // 'ALL', 'ENTRY', 'EXIT', 'SALE'
  String get typeFilter => _typeFilter;

  // Paginación
  static const int pageSize = 8;
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int _totalCount = 0;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();
  int get totalCount => _totalCount;

  KardexProvider() {
    _loadMovements();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    _currentPage = 0;
    _loadMovements();
  }

  void setTypeFilter(String type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    _currentPage = 0;
    _loadMovements();
  }

  void setPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    _loadMovements();
  }

  Future<void> refresh() async {
    _currentPage = 0;
    await _loadMovements();
  }

  PostgrestFilterBuilder<T> _buildBaseQuery<T>(PostgrestFilterBuilder<T> query) {
    if (_dateRange != null) {
      final startStr = _dateRange!.start.toIso8601String();
      final endStr = _dateRange!.end
          .add(const Duration(hours: 23, minutes: 59, seconds: 59))
          .toIso8601String();
      query = query.gte('created_at', startStr).lte('created_at', endStr);
    }

    if (_typeFilter == 'ENTRY') {
      query = query.not('inventory_entry_id', 'is', null);
    } else if (_typeFilter == 'EXIT') {
      query = query.not('inventory_exit_id', 'is', null);
    } else if (_typeFilter == 'SALE') {
      query = query.not('order_id', 'is', null);
    }
    
    return query;
  }

  Future<void> _loadMovements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var query = _supabase.from('inventory_movements').select('''
        *,
        warehouses!inner(name),
        warehouse_stock_batches(batch_number),
        product_variants!inner(
          sku,
          variant_attribute_values(attribute_values(value)),
          product_images(image_url, is_main, variant_id),
          products!inner(name, uses_batches, product_images(image_url, is_main, variant_id))
        )
      ''');

      query = _buildBaseQuery(query);

      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      _movements = (response.data as List)
          .map((row) => KardexMovementModel.fromSupabaseRow(row))
          .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar kardex: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> exportToPdf() async {
    if (_isExporting) return;
    
    _isExporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Para exportar, traemos todos los registros (sin .range) de acuerdo a los filtros actuales.
      // Advertencia: si son decenas de miles, esto podría ser pesado. 
      // Si llega a serlo, habría que limitar o advertir al usuario.
      var query = _supabase.from('inventory_movements').select('''
        *,
        warehouses!inner(name),
        warehouse_stock_batches(batch_number),
        product_variants!inner(
          sku,
          variant_attribute_values(attribute_values(value)),
          product_images(image_url, is_main, variant_id),
          products!inner(name, uses_batches, product_images(image_url, is_main, variant_id))
        )
      ''');

      query = _buildBaseQuery(query);
      
      final response = await query.order('created_at', ascending: false);
      
      final allMovements = (response as List)
          .map((row) => KardexMovementModel.fromSupabaseRow(row))
          .toList();

      final pdf = pw.Document();

      // Dividir en páginas si son muchos datos
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reporte de Kardex', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              
              if (_dateRange != null)
                pw.Text('Fechas: ${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'),
              
              pw.Text('Tipo de filtro: ${_getTypeFilterName()}'),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Fecha', 'Tipo', 'Producto / SKU', 'Almacén', 'Stock Ant.', 'Cant.', 'Nuevo Stock'],
                data: allMovements.map((m) {
                  return [
                    m.movement.createdAt != null ? DateFormat('dd/MM/yy HH:mm').format(m.movement.createdAt!.toLocal()) : '',
                    m.movementType,
                    '${m.productName} ${m.attrsText != 'Única' ? '(${m.attrsText})' : ''} ${m.sku != null ? '\nSKU: ${m.sku}' : ''}',
                    m.warehouseName,
                    m.movement.previousStock.toString(),
                    '${m.isEntry ? '+' : ''}${m.movement.quantity}',
                    m.movement.newStock.toString(),
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Kardex_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      _errorMessage = 'Error al exportar PDF: $e';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  String _getTypeFilterName() {
    switch (_typeFilter) {
      case 'ENTRY': return 'Ingresos';
      case 'EXIT': return 'Salidas';
      case 'SALE': return 'Ventas';
      default: return 'Todos los movimientos';
    }
  }
}
