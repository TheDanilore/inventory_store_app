import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CustomerSummary {
  final String id;
  final String fullName;
  final String? phone;
  final String? documentNumber;
  final String? documentType;
  final String? avatarUrl;
  final bool isActive;
  final int walletBalance;
  final DateTime createdAt;

  final double totalSpent;
  final int orderCount;
  final DateTime? lastOrderAt;

  final double currentDebt;
  final double creditLimit;
  final bool hasActiveCredit;

  const CustomerSummary({
    required this.id,
    required this.fullName,
    this.phone,
    this.documentNumber,
    this.documentType,
    this.avatarUrl,
    required this.isActive,
    required this.walletBalance,
    required this.createdAt,
    this.totalSpent = 0,
    this.orderCount = 0,
    this.lastOrderAt,
    this.currentDebt = 0,
    this.creditLimit = 0,
    this.hasActiveCredit = false,
  });
}

class CustomersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // Estado global
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  // Listas
  final List<CustomerSummary> _customers = [];
  List<CustomerSummary> get customers => _customers;

  List<CustomerSummary> _topCustomers = [];
  List<CustomerSummary> get topCustomers => _topCustomers;

  // Paginación
  int _currentPage = 0;
  int get currentPage => _currentPage;
  final int pageSize = 10;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  // Filtros
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _showOnlyWithDebt = false;
  bool get showOnlyWithDebt => _showOnlyWithDebt;

  // Estadísticas Globales
  int _totalCustomersCount = 0;
  int get totalCustomersCount => _totalCustomersCount;

  int _activeCustomersCount = 0;
  int get activeCustomersCount => _activeCustomersCount;

  double _totalRevenue = 0;
  double get totalRevenue => _totalRevenue;

  double _totalDebt = 0;
  double get totalDebt => _totalDebt;

  Timer? _debounce;

  CustomersProvider() {
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadGlobalStats();
      await fetchCustomers(reset: true);
    } catch (e) {
      debugPrint('Error en _init CustomersProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadGlobalStats();
      await fetchCustomers(reset: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadGlobalStats() async {
    try {
      // 1. Contadores Globales de Clientes (Ligeros)
      final profilesRes = await _supabase
          .from('profiles')
          .select('id, is_active')
          .eq('role', 'customer');

      _totalCustomersCount = profilesRes.length;
      _activeCustomersCount =
          profilesRes.where((p) => p['is_active'] == true).length;

      // 2. Traer órdenes ligeras para sumar ingresos y encontrar Top 5
      final ordersRes = await _supabase
          .from('orders')
          .select('customer_id, total_amount');

      double rev = 0;
      final Map<String, double> spentByCustomer = {};
      for (final o in ordersRes) {
        final cid = o['customer_id'] as String?;
        if (cid == null) continue;
        final amount = (o['total_amount'] as num).toDouble();
        rev += amount;
        spentByCustomer[cid] = (spentByCustomer[cid] ?? 0) + amount;
      }
      _totalRevenue = rev;

      // 3. Traer créditos ligeros para sumar deuda
      final creditsRes = await _supabase
          .from('customer_credits')
          .select('profile_id, current_debt');

      double debt = 0;
      for (final c in creditsRes) {
        debt += (c['current_debt'] as num).toDouble();
      }
      _totalDebt = debt;

      // 4. Calcular Top 5 Global y obtener sus perfiles completos
      final sortedEntries =
          spentByCustomer.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final top5Ids = sortedEntries.take(5).map((e) => e.key).toList();

      if (top5Ids.isNotEmpty) {
        final topProfilesRes = await _supabase
            .from('profiles')
            .select(
              'id, full_name, avatar_url, is_active, wallet_balance, created_at',
            )
            .inFilter('id', top5Ids);

        final Map<String, dynamic> topProfilesMap = {
          for (var p in topProfilesRes) p['id'] as String: p,
        };

        _topCustomers =
            top5Ids
                .map((id) {
                  final p = topProfilesMap[id];
                  if (p == null) return null;
                  return CustomerSummary(
                    id: p['id'],
                    fullName: p['full_name'],
                    avatarUrl: p['avatar_url'],
                    isActive: p['is_active'] ?? true,
                    walletBalance: p['wallet_balance'] ?? 0,
                    createdAt: DateTime.parse(p['created_at']),
                    totalSpent: spentByCustomer[id] ?? 0,
                  );
                })
                .whereType<CustomerSummary>()
                .toList();
      } else {
        _topCustomers = [];
      }
    } catch (e) {
      debugPrint('Error en _loadGlobalStats: $e');
    }
  }

  Future<void> fetchCustomers({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _customers.clear();
      _hasMore = true;
    }

    if (!_hasMore) return;

    try {
      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      var query = _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at',
          )
          .eq('role', 'customer');

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$_searchQuery%,document_number.ilike.%$_searchQuery%',
        );
      }

      // Si queremos solo con deuda, deberíamos cruzar con customer_credits
      // Como Supabase flutter lo requiere, usamos un inner join
      if (_showOnlyWithDebt) {
        query = _supabase
            .from('profiles')
            .select(
              'id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at, customer_credits!inner(current_debt)',
            )
            .eq('role', 'customer')
            .gt('customer_credits.current_debt', 0);

        if (_searchQuery.isNotEmpty) {
          query = query.or(
            'full_name.ilike.%$_searchQuery%,document_number.ilike.%$_searchQuery%',
          );
        }
      }

      final res = await query.order('full_name').range(start, end);

      if (res.isEmpty) {
        _hasMore = false;
        notifyListeners();
        return;
      }

      // Obtener datos agregados para los clientes descargados
      final cIds = res.map((e) => e['id'] as String).toList();

      final ordersAggRes = await _supabase
          .from('orders')
          .select('customer_id, total_amount, created_at')
          .inFilter('customer_id', cIds);

      final creditsRes = await _supabase
          .from('customer_credits')
          .select('profile_id, current_debt, credit_limit, is_active')
          .inFilter('profile_id', cIds);

      final Map<String, _OrderAgg> aggMap = {};
      for (final o in ordersAggRes) {
        final cid = o['customer_id'] as String;
        final amount = (o['total_amount'] as num).toDouble();
        final date = DateTime.parse(o['created_at']);
        if (!aggMap.containsKey(cid)) aggMap[cid] = _OrderAgg();
        aggMap[cid]!.total += amount;
        aggMap[cid]!.count++;
        if (aggMap[cid]!.lastDate == null ||
            date.isAfter(aggMap[cid]!.lastDate!)) {
          aggMap[cid]!.lastDate = date;
        }
      }

      final Map<String, dynamic> creditMap = {
        for (var c in creditsRes) c['profile_id'] as String: c,
      };

      final newCustomers =
          res.map((p) {
            final a = aggMap[p['id']];
            final cr = creditMap[p['id']];
            return CustomerSummary(
              id: p['id'],
              fullName: p['full_name'],
              phone: p['phone'],
              documentNumber: p['document_number'],
              documentType: p['document_type'],
              avatarUrl: p['avatar_url'],
              isActive: p['is_active'] ?? false,
              walletBalance: p['wallet_balance'] ?? 0,
              createdAt: DateTime.parse(p['created_at']),
              totalSpent: a?.total ?? 0,
              orderCount: a?.count ?? 0,
              lastOrderAt: a?.lastDate,
              currentDebt:
                  cr != null ? (cr['current_debt'] as num).toDouble() : 0,
              creditLimit:
                  cr != null ? (cr['credit_limit'] as num).toDouble() : 0,
              hasActiveCredit: cr != null ? cr['is_active'] as bool : false,
            );
          }).toList();

      _customers.addAll(newCustomers);
      _currentPage++;

      if (newCustomers.length < pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error en fetchCustomers: $e');
    } finally {
      notifyListeners();
    }
  }

  void search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchQuery != query) {
        _searchQuery = query;
        _isSearching = true;
        notifyListeners();

        fetchCustomers(reset: true).then((_) {
          _isSearching = false;
          notifyListeners();
        });
      }
    });
  }

  void toggleDebtFilter(bool showDebt) {
    if (_showOnlyWithDebt != showDebt) {
      _showOnlyWithDebt = showDebt;
      _isLoading = true;
      notifyListeners();

      fetchCustomers(reset: true).then((_) {
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  Future<void> exportToPdf() async {
    if (_isExporting) return;

    _isExporting = true;
    notifyListeners();

    try {
      var query = _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, document_number, document_type, is_active, created_at',
          )
          .eq('role', 'customer');

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$_searchQuery%,document_number.ilike.%$_searchQuery%',
        );
      }

      if (_showOnlyWithDebt) {
        query = _supabase
            .from('profiles')
            .select(
              'id, full_name, phone, document_number, document_type, is_active, created_at, customer_credits!inner(current_debt)',
            )
            .eq('role', 'customer')
            .gt('customer_credits.current_debt', 0);

        if (_searchQuery.isNotEmpty) {
          query = query.or(
            'full_name.ilike.%$_searchQuery%,document_number.ilike.%$_searchQuery%',
          );
        }
      }

      final response = await query.order('full_name');

      final pdf = pw.Document();

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
                    pw.Text(
                      'Directorio de Clientes',
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

              if (_searchQuery.isNotEmpty) pw.Text('Búsqueda: "$_searchQuery"'),
              if (_showOnlyWithDebt)
                pw.Text('Filtro: Solo clientes con deuda activa'),

              pw.SizedBox(height: 20),

              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: [
                  'Nombre Completo',
                  'Documento',
                  'Teléfono',
                  'Estado',
                  'Registrado el',
                ],
                data:
                    (response as List).map((c) {
                      return [
                        c['full_name']?.toString() ?? '',
                        '${c['document_type'] ?? ''} ${c['document_number'] ?? ''}'
                            .trim(),
                        c['phone']?.toString() ?? '-',
                        (c['is_active'] == true) ? 'Activo' : 'Inactivo',
                        c['created_at'] != null
                            ? DateFormat(
                              'dd/MM/yy',
                            ).format(DateTime.parse(c['created_at']).toLocal())
                            : '',
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
        filename:
            'Clientes_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      debugPrint('Error al exportar PDF: $e');
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}

class _OrderAgg {
  double total = 0;
  int count = 0;
  DateTime? lastDate;
}
