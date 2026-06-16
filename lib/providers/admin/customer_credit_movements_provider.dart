import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/credit_movement_model.dart';
import 'package:inventory_store_app/services/admin/customer_credits_service.dart';

class CustomerCreditMovementsProvider extends ChangeNotifier {
  final CustomerCreditsService _service = CustomerCreditsService();

  late String _creditId;
  String _customerName = '';

  bool _isLoading = true;
  bool _isExporting = false;

  List<CreditMovementModel> _movements = [];
  int _totalCount = 0;
  int _currentPage = 0;
  static const int _pageSize = 8;

  double _totalCharged = 0.0;
  double _totalPaid = 0.0;
  double _currentDebt = 0.0;
  double _creditLimit = 0.0;

  // Filtro
  String _dateFilter = 'all'; // 'all', '30_days', 'this_month'

  // Getters
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  List<CreditMovementModel> get movements => _movements;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalPages => (_totalCount / _pageSize).ceil();

  double get totalCharged => _totalCharged;
  double get totalPaid => _totalPaid;
  double get currentDebt => _currentDebt;
  double get creditLimit => _creditLimit;
  String get customerName => _customerName;
  String get dateFilter => _dateFilter;

  void init({
    required String creditId,
    required String customerName,
    required double currentDebt,
    required double creditLimit,
  }) {
    _creditId = creditId;
    _customerName = customerName;
    _currentDebt = currentDebt;
    _creditLimit = creditLimit;
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final futures = await Future.wait([
        _service.fetchCreditMovementsPaginated(
          creditId: _creditId,
          page: _currentPage,
          pageSize: _pageSize,
          dateFilter: _dateFilter == 'all' ? null : _dateFilter,
        ),
        _service.fetchCreditMovementsTotals(
          creditId: _creditId,
          dateFilter: _dateFilter == 'all' ? null : _dateFilter,
        ),
      ]);

      final movementsData =
          futures[0] as ({List<CreditMovementModel> movements, int count});
      final totalsData =
          futures[1] as ({double totalCharged, double totalPaid});

      _movements = movementsData.movements;
      _totalCount = movementsData.count;
      _totalCharged = totalsData.totalCharged;
      _totalPaid = totalsData.totalPaid;
    } catch (e) {
      debugPrint('Error loading credit movements: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPage(int page) async {
    if (page == _currentPage) return;
    _currentPage = page;
    await loadData();
  }

  Future<void> setDateFilter(String filter) async {
    if (filter == _dateFilter) return;
    _dateFilter = filter;
    _currentPage = 0; // Reset pagination
    await loadData();
  }

  // Exportar a PDF (Simulado para que sea igual que CustomersProvider)
  Future<void> exportToPdf() async {
    if (_isExporting) return;
    _isExporting = true;
    notifyListeners();

    try {
      // Implementar generación de PDF
      // 1. Obtener todos los movimientos del filtro actual
      // 2. Generar el documento PDF
      // 3. Guardar / Compartir
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error exportando a PDF: $e');
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
