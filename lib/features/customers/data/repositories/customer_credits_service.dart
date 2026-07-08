import 'package:inventory_store_app/features/customers/data/models/customer_credit_movement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_models.dart';

class CustomerCreditsService {
  final _supabase = Supabase.instance.client;

  // 1. Obtener cuentas paginadas (y estadísticas si se desea en otro lado o aquí mismo)
  // Como los filtros locales son de búsqueda, Supabase puede filtrarlo directamente.
  Future<
    ({List<CreditAccountModel> accounts, int count, Map<String, dynamic> stats})
  >
  fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Calculamos las estadísticas primero sin rango
    var statsQuery = _supabase.from('partner_credit_summary').select();
    if (searchQuery.isNotEmpty) {
      statsQuery = statsQuery.or(
        'partner_name.ilike.%$searchQuery%,partner_document.ilike.%$searchQuery%,partner_phone.ilike.%$searchQuery%',
      );
    }

    final statsResponse = await statsQuery;
    double totalDebt = 0;
    int activeCount = 0;
    int suspendedCount = 0;
    int maxedOutCount = 0;

    for (final item in statsResponse as List) {
      final a = CreditAccountModel.fromView(item);
      totalDebt += a.currentDebt;
      if (a.isActive) {
        activeCount++;
        if (a.isMaxedOut) maxedOutCount++;
      } else {
        suspendedCount++;
      }
    }

    // Ahora la consulta paginada
    var query = _supabase.from('partner_credit_summary').select();

    if (searchQuery.isNotEmpty) {
      query = query.or(
        'partner_name.ilike.%$searchQuery%,partner_document.ilike.%$searchQuery%,partner_phone.ilike.%$searchQuery%',
      );
    }

    if (withDebtOnly) {
      query = query.gt('current_debt', 0).eq('is_active', true);
    }

    // Para la paginación de la vista principal, aplicamos order al final
    final response = await query
        .order('current_debt', ascending: false)
        .range(from, to)
        .count(CountOption.exact);
    final count = response.count;
    final list =
        (response.data as List)
            .map((item) => CreditAccountModel.fromView(item))
            .toList();

    return (
      accounts: list,
      count: count,
      stats: {
        'totalDebt': totalDebt,
        'activeAccounts': activeCount,
        'suspendedAccounts': suspendedCount,
        'maxedOutAccounts': maxedOutCount,
      },
    );
  }

  // 2. Suspender / Reactivar
  Future<void> toggleAccountStatus(String creditId, bool currentStatus) async {
    await _supabase
        .from('customer_credits')
        .update({
          'is_active': !currentStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', creditId);
  }

  // 3. Crear / Editar Cuenta
  Future<void> saveAccount({
    required String? creditId,
    required String profileId,
    required double creditLimit,
    String? adminProfileId,
  }) async {
    if (creditId != null) {
      await _supabase
          .from('customer_credits')
          .update({
            'credit_limit': creditLimit,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);
    } else {
      await _supabase.from('customer_credits').insert({
        'profile_id': profileId,
        'credit_limit': creditLimit,
        'current_debt': 0.0,
        'is_active': true,
        if (adminProfileId != null) 'created_by': adminProfileId,
      });
    }
  }

  // 4. Buscar clientes sin crédito
  Future<List<Map<String, dynamic>>> searchClients(
    String query,
    Set<String> existingProfileIds,
  ) async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, document_number, document_type, phone')
        .eq('role', 'customer')
        .eq('is_active', true)
        .or(
          'full_name.ilike.%$query%,document_number.ilike.%$query%,phone.ilike.%$query%',
        )
        .limit(20);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .where((p) => !existingProfileIds.contains(p['id'] as String))
        .take(6)
        .toList();
  }

  // Obtener IDs con cuentas de crédito existentes
  Future<Set<String>> getExistingCreditProfileIds({
    String? excludeProfileId,
  }) async {
    final existingCredits = await _supabase
        .from('customer_credits')
        .select('profile_id');
    return (existingCredits as List)
        .map((e) => e['profile_id'] as String)
        .where((id) => id != excludeProfileId)
        .toSet();
  }

  // Obtener pedidos pendientes de un cliente
  Future<List<Map<String, dynamic>>> getPendingOrders(String profileId) async {
    return await _supabase
        .from('orders')
        .select('id, total_amount, amount_paid, payment_status, created_at')
        .eq('customer_id', profileId)
        .eq('payment_method', 'CRÉDITO')
        .inFilter('payment_status', ['PENDING', 'PARTIAL'])
        .eq('status', 'COMPLETED')
        .order('created_at', ascending: true);
  }

  // Obtener cuentas financieras activas
  Future<List<FinancialAccountOption>> getFinancialAccounts() async {
    final resp = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('name');

    const typeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
    return (resp as List)
        .map(
          (a) => FinancialAccountOption(
            id: a['id'] as String,
            name: a['name'] as String,
            type: a['type'] as String,
            balance: (a['balance'] as num).toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) {
        final oa = typeOrder[a.type] ?? 99;
        final ob = typeOrder[b.type] ?? 99;
        if (oa != ob) return oa.compareTo(ob);
        return a.name.compareTo(b.name);
      });
  }

  // Comprobar turno caja
  Future<Map<String, dynamic>?> getActiveCashShift(String accountId) async {
    return await _supabase
        .from('cash_shifts')
        .select('id, opened_at, opening_amount')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle();
  }

  Future<String?> getAdminProfileId() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId != null) {
      final resp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();
      if (resp != null) return resp['id'] as String;
    }
    return null;
  }

  // Registrar abono
  Future<void> registerPayment({
    required CreditAccountModel account,
    required double amount,
    required FinancialAccountOption selectedAccount,
    required String? selectedOrderId,
    required String notes,
    required List<Map<String, dynamic>> pendingOrders,
    required String? adminProfileId,
    required String? shiftId,
    required double pointsToSolesRatio,
    required double pointsEarningRate,
  }) async {
    // 1. Aplicar a órdenes FIFO (o la orden seleccionada) y registrar movimientos
    final ordersToApply =
        selectedOrderId != null
            ? pendingOrders.where((o) => o['id'] == selectedOrderId).toList()
            : List<Map<String, dynamic>>.from(pendingOrders);

    double remaining = amount;
    for (final order in ordersToApply) {
      if (remaining <= 0) break;
      final orderId = order['id'] as String;
      final total = (order['total_amount'] as num).toDouble();
      final alreadyPaid = (order['amount_paid'] as num).toDouble();
      final pendingOfOrder = (total - alreadyPaid).clamp(0.0, double.infinity);
      final toApply = remaining >= pendingOfOrder ? pendingOfOrder : remaining;
      final newAmountPaid = alreadyPaid + toApply;
      remaining -= toApply;

      final newPaymentStatus = newAmountPaid >= total ? 'PAID' : 'PARTIAL';

      int pointsEarned = 0;

      // Si la orden pasa a pagada por completo, se le otorgan puntos.
      if (newPaymentStatus == 'PAID' && pointsEarningRate > 0) {
        // Se le dan puntos por el total final (ya pagado).
        pointsEarned = (total * pointsEarningRate / pointsToSolesRatio).floor();
      }

      await _supabase
          .from('orders')
          .update({
            'amount_paid': newAmountPaid,
            'payment_status': newPaymentStatus,
            if (pointsEarned > 0) 'points_earned': pointsEarned,
          })
          .eq('id', orderId);

      // Insertar movimiento específico para esta orden
      if (toApply > 0) {
        await Future.wait([
          _supabase.from('customer_credit_movements').insert({
            'customer_credit_id': account.creditId,
            'order_id': orderId,
            'movement_type': 'PAYMENT',
            'amount': toApply,
            'payment_method': selectedAccount.paymentMethodLabel,
            'notes': notes,
            if (adminProfileId != null) 'created_by': adminProfileId,
          }),
          _supabase.from('account_movements').insert({
            'account_id': selectedAccount.id,
            'movement_type': 'INCOME',
            'amount': toApply,
            'description': 'Cobro de crédito — Pedido #$orderId',
            'reference_type': 'orders',
            'reference_id': orderId,
            if (shiftId != null) 'shift_id': shiftId,
            if (adminProfileId != null) 'created_by': adminProfileId,
          }),
        ]);
      }

      // Otorgar puntos si aplica
      if (pointsEarned > 0) {
        // Obtener billetera
        final profileResp =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', account.profileId)
                .single();
        final currentWallet =
            (profileResp['wallet_balance'] as num?)?.toInt() ?? 0;

        // Sumar y actualizar
        await _supabase
            .from('profiles')
            .update({'wallet_balance': currentWallet + pointsEarned})
            .eq('id', account.profileId);

        // Registro de wallet
        await _supabase.from('wallet_movements').insert({
          'profile_id': account.profileId,
          'order_id': orderId,
          'points': pointsEarned,
          'movement_type': 'EARNED',
          'description': 'Monedas ganadas al saldar pedido a crédito',
        });
      }
    }

    // Si sobra dinero (pago excede la suma de pedidos), registrarlo como abono global
    if (remaining > 0) {
      await Future.wait([
        _supabase.from('customer_credit_movements').insert({
          'customer_credit_id': account.creditId,
          'movement_type': 'PAYMENT',
          'amount': remaining,
          'payment_method': selectedAccount.paymentMethodLabel,
          'notes': notes,
          if (adminProfileId != null) 'created_by': adminProfileId,
        }),
        _supabase.from('account_movements').insert({
          'account_id': selectedAccount.id,
          'movement_type': 'INCOME',
          'amount': remaining,
          'description': 'Cobro de crédito — ${account.partnerName}',
          'reference_type': 'customer_credits',
          'reference_id': account.creditId,
          if (shiftId != null) 'shift_id': shiftId,
          if (adminProfileId != null) 'created_by': adminProfileId,
        }),
      ]);
    }

    // 3. Reducir deuda
    final newDebt = (account.currentDebt - amount).clamp(0.0, double.infinity);
    await _supabase
        .from('customer_credits')
        .update({
          'current_debt': newDebt,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', account.creditId);

    // 5. Saldo caja
    final newBalance = selectedAccount.balance + amount;
    await _supabase
        .from('financial_accounts')
        .update({'balance': newBalance})
        .eq('id', selectedAccount.id);
  }

  // 6. Obtener movimientos paginados
  Future<({List<CustomerCreditMovementModel> movements, int count})>
  fetchCreditMovementsPaginated({
    required String creditId,
    required int page,
    required int pageSize,
    String? dateFilter, // '30_days', 'this_month', 'all'
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _supabase
        .from('customer_credit_movements_summary')
        .select()
        .eq('customer_credit_id', creditId);

    // Filtros de fecha
    if (dateFilter == '30_days') {
      final date30DaysAgo = DateTime.now().subtract(const Duration(days: 30));
      query = query.gte('created_at', date30DaysAgo.toIso8601String());
    } else if (dateFilter == 'this_month') {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      query = query.gte('created_at', firstDayOfMonth.toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    final count = response.count;
    final list =
        (response.data as List)
            .map((e) => CustomerCreditMovementModel.fromJson(e))
            .toList();

    return (movements: list, count: count);
  }

  // 7. Obtener totales de movimientos
  Future<({double totalCharged, double totalPaid})> fetchCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  }) async {
    var query = _supabase
        .from('customer_credit_movements_summary')
        .select('movement_type, amount')
        .eq('customer_credit_id', creditId);

    // Filtros de fecha
    if (dateFilter == '30_days') {
      final date30DaysAgo = DateTime.now().subtract(const Duration(days: 30));
      query = query.gte('created_at', date30DaysAgo.toIso8601String());
    } else if (dateFilter == 'this_month') {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      query = query.gte('created_at', firstDayOfMonth.toIso8601String());
    }

    final response = await query;

    double charged = 0;
    double paid = 0;

    for (final m in response as List) {
      final amount = (m['amount'] as num).toDouble();
      if (m['movement_type'] == 'CHARGE') {
        charged += amount;
      } else if (m['movement_type'] == 'PAYMENT') {
        paid += amount;
      }
    }

    return (totalCharged: charged, totalPaid: paid);
  }
}
