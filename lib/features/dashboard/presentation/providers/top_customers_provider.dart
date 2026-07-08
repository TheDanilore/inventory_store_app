import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customers_provider.dart';

class TopCustomersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _limit = 10;
  int get limit => _limit;

  List<CustomerSummary> _participants = [];
  List<CustomerSummary> get participants => _participants;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  CustomerSummary? _winner;
  CustomerSummary? get winner => _winner;

  TopCustomersProvider() {
    _fetchParticipants();
  }

  void setLimit(int newLimit) {
    if (_limit != newLimit) {
      _limit = newLimit;
      _fetchParticipants();
    }
  }

  Future<void> _fetchParticipants() async {
    _isLoading = true;
    _winner = null;
    notifyListeners();

    try {
      // 1. Obtener los totales gastados por cliente
      final ordersRes = await _supabase
          .from('orders')
          .select('customer_id, total_amount')
          .eq('status', 'COMPLETED');

      final Map<String, double> spentByCustomer = {};
      for (final o in ordersRes) {
        final cid = o['customer_id'] as String?;
        if (cid == null) continue;
        final amount = (o['total_amount'] as num).toDouble();
        spentByCustomer[cid] = (spentByCustomer[cid] ?? 0) + amount;
      }

      // 2. Ordenar de mayor a menor y tomar el top X
      final sortedEntries = spentByCustomer.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
      final topIds = sortedEntries.take(_limit).map((e) => e.key).toList();

      if (topIds.isNotEmpty) {
        // 3. Obtener los perfiles
        final profilesRes = await _supabase
            .from('profiles')
            .select('id, full_name, avatar_url, is_active, wallet_balance, created_at')
            .inFilter('id', topIds);

        final Map<String, dynamic> profilesMap = {
          for (var p in profilesRes) p['id'] as String: p,
        };

        _participants = topIds.map((id) {
          final p = profilesMap[id];
          if (p == null) return null;
          return CustomerSummary(
            id: p['id'],
            fullName: p['full_name'] ?? 'Desconocido',
            avatarUrl: p['avatar_url'],
            isActive: p['is_active'] ?? true,
            walletBalance: p['wallet_balance'] ?? 0,
            createdAt: DateTime.parse(p['created_at']),
            totalSpent: spentByCustomer[id] ?? 0,
          );
        }).whereType<CustomerSummary>().toList();
      } else {
        _participants = [];
      }
    } catch (e) {
      debugPrint('Error fetchParticipants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startSpinning(CustomerSummary randomWinner) {
    _isSpinning = true;
    _winner = randomWinner;
    notifyListeners();
  }

  void stopSpinning() {
    _isSpinning = false;
    notifyListeners();
  }
}
