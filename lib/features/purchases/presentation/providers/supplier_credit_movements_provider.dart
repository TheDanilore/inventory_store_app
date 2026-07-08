import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_movement_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

enum MovementDateFilter { allTime, thisMonth, lastMonth }

class SupplierCreditMovementsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final String creditId;
  final String supplierName;

  SupplierCreditMovementsProvider({
    required this.creditId,
    required this.supplierName,
  }) {
    _loadAll();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SupplierCreditMovementModel> _movements = [];
  List<SupplierCreditMovementModel> get movements => _movements;

  MovementDateFilter _dateFilter = MovementDateFilter.allTime;
  MovementDateFilter get dateFilter => _dateFilter;

  // Pagination
  static const int pageSize = 8;
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int _totalCount = 0;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();

  // Aggregations
  double _totalCharged = 0.0;
  double get totalCharged => _totalCharged;

  double _totalPaid = 0.0;
  double get totalPaid => _totalPaid;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setDateFilter(MovementDateFilter filter) {
    if (_dateFilter == filter) return;
    _dateFilter = filter;
    _currentPage = 0;
    _loadAll();
  }

  void setPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    _loadMovementsPage();
  }

  Future<void> refresh() async {
    _currentPage = 0;
    await _loadAll();
  }

  Future<void> _loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([_loadTotals(), _loadMovementsPage(notify: false)]);
    } catch (e) {
      debugPrint('Error loading movements: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar los datos.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTotals() async {
    try {
      var query = _supabase
          .from('supplier_credit_movements')
          .select('amount, movement_type, created_at')
          .eq('supplier_credit_id', creditId);

      query = _applyDateFilter(query);

      final response = await query;
      final list = response as List;

      double charged = 0;
      double paid = 0;

      for (final item in list) {
        final amount = (item['amount'] as num).toDouble();
        if (item['movement_type'] == 'CHARGE') {
          charged += amount;
        } else {
          paid += amount;
        }
      }

      _totalCharged = charged;
      _totalPaid = paid;
    } catch (e) {
      debugPrint('Error loading totals: $e');
    }
  }

  Future<void> _loadMovementsPage({bool notify = true}) async {
    if (notify) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      var query = _supabase
          .from('supplier_credit_movements')
          .select('*, profiles(full_name), purchase_orders(total_amount)')
          .eq('supplier_credit_id', creditId);

      query = _applyDateFilter(query);

      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      _movements =
          (response.data as List)
              .map((e) => SupplierCreditMovementModel.fromJson(e))
              .toList();
    } catch (e) {
      debugPrint('Error paginating movements: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar la página.';
      }
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  PostgrestFilterBuilder<T> _applyDateFilter<T>(
    PostgrestFilterBuilder<T> query,
  ) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case MovementDateFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return query.gte('created_at', startOfMonth.toIso8601String());
      case MovementDateFilter.lastMonth:
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
        return query
            .gte('created_at', startOfLastMonth.toIso8601String())
            .lte('created_at', endOfLastMonth.toIso8601String());
      case MovementDateFilter.allTime:
        return query;
    }
  }

  Future<void> exportToPdf() async {
    _isExporting = true;
    notifyListeners();

    try {
      // Bring all movements for the current filter for the PDF
      var query = _supabase
          .from('supplier_credit_movements')
          .select('*, profiles(full_name), purchase_orders(total_amount)')
          .eq('supplier_credit_id', creditId);

      query = _applyDateFilter(query);
      final response = await query.order('created_at', ascending: false);
      final allMovements =
          (response as List)
              .map((e) => SupplierCreditMovementModel.fromJson(e))
              .toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Estado de Cuenta',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Proveedor: $supplierName',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Fecha',
                  'Tipo',
                  'Monto',
                  'Método',
                  'Usuario',
                  'Notas',
                ],
                data:
                    allMovements.map((m) {
                      return [
                        m.createdAt != null
                            ? DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(m.createdAt!.toLocal())
                            : '',
                        m.isCharge ? 'Fiado (Cargo)' : 'Amortización (Pago)',
                        'S/ ${m.amount.toStringAsFixed(2)}',
                        m.paymentMethod ?? '-',
                        m.createdByName ?? 'Sistema',
                        m.notes ?? '',
                      ];
                    }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'estado_cuenta_${supplierName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al exportar PDF.';
      }
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
