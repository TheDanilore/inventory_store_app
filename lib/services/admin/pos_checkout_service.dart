import 'package:inventory_store_app/models/batch_assignment_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PosCheckoutService {
  static final PosCheckoutService _instance = PosCheckoutService._internal();
  factory PosCheckoutService() => _instance;
  PosCheckoutService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  List<WarehouseModel>? _cachedWarehouses;
  List<Map<String, dynamic>>? _cachedAccounts;

  Future<Map<String, dynamic>> loadInitialData({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _cachedWarehouses = null;
      _cachedAccounts = null;
    }

    if (_cachedWarehouses == null) {
      final whRes = await _supabase
          .from('warehouses')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      _cachedWarehouses =
          (whRes as List).map((w) => WarehouseModel.fromJson(w)).toList();
    }

    if (_cachedAccounts == null) {
      final accRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('type')
          .order('name');
      _cachedAccounts = List<Map<String, dynamic>>.from(accRes);
    }

    return {'warehouses': _cachedWarehouses!, 'accounts': _cachedAccounts!};
  }

  Future<Map<String, dynamic>?> checkActiveShift(String accountId) async {
    return await _supabase
        .from('cash_shifts')
        .select('id, status')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> searchClients(String text) async {
    final response = await _supabase
        .from('profiles')
        .select(
          'id, full_name, phone, document_number, wallet_balance, role, is_active',
        )
        .eq('is_active', true)
        .or(
          'full_name.ilike.%$text%,document_number.ilike.%$text%,phone.ilike.%$text%',
        )
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchClientCredit(String clientId) async {
    return await _supabase
        .from('customer_credits')
        .select('id, credit_limit, current_debt, is_active')
        .eq('profile_id', clientId)
        .maybeSingle();
  }

  Future<List<BatchAssignmentModel>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    final resp = await _supabase
        .from('warehouse_stock_batches')
        .select('id, batch_number, expiry_date, available_quantity')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);

    return (resp as List).map((b) {
      return BatchAssignmentModel(
        batchId: b['id'] as String,
        batchNumber: b['batch_number'] as String,
        expiryDate:
            b['expiry_date'] != null
                ? DateTime.tryParse(b['expiry_date'] as String)
                : null,
        available: (b['available_quantity'] as num).toInt(),
        assigned: 0,
      );
    }).toList();
  }

  Future<void> processSale({
    required PosProvider pos,
    required bool isDraft,
    required bool isCredito,
    required String? selectedAccountId,
    required Map<String, dynamic>? activeShift,
    required List<Map<String, dynamic>> accountsList,
    required double pointsToSolesRatio,
    required double earningRate,
    required int puntosUsados,
    required double totalFinal,
    required double totalProfit,
    required double descuentoExtra,
    required String? customerManualName,
    List<BatchAssignmentModel>? Function(PosProvider pos, String cartKey)?
    getBatchOverride,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    final profileResp =
        await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', authUserId!)
            .single();
    final String currentProfileId = profileResp['id'];

    List<Map<String, dynamic>> batchUpdates = [];
    List<Map<String, dynamic>> movementInserts = [];

    if (!isDraft) {
      for (final item in pos.items.values) {
        final safeVariantId = item.variantId!;
        final cartKey = item.cartKey;

        List<({String id, int take, int available, String batchNumber})>
        segments = [];

        final batchAssigned = getBatchOverride?.call(pos, cartKey);
        if (batchAssigned != null && batchAssigned.isNotEmpty) {
          final overrides = batchAssigned;
          final totalAssigned = overrides.fold(0, (s, b) => s + b.assigned);
          if (totalAssigned != item.quantity) {
            throw Exception(
              'La asignación de lotes para "${item.product.name}" '
              'suma $totalAssigned pero la cantidad vendida es ${item.quantity}.',
            );
          }
          for (final b in overrides) {
            if (b.assigned > 0) {
              segments.add((
                id: b.batchId,
                take: b.assigned,
                available: b.available,
                batchNumber: b.batchNumber,
              ));
            }
          }
        } else {
          final batches = await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity, batch_number, expiry_date')
              .eq('variant_id', safeVariantId)
              .eq('warehouse_id', pos.selectedWarehouseId!)
              .gt('available_quantity', 0)
              .order('expiry_date', ascending: true, nullsFirst: false);

          int remaining = item.quantity;
          for (final batch in (batches as List)) {
            if (remaining <= 0) break;
            final int available = (batch['available_quantity'] as num).toInt();
            final int take = (remaining > available) ? available : remaining;
            segments.add((
              id: batch['id'] as String,
              take: take,
              available: available,
              batchNumber: batch['batch_number'] as String,
            ));
            remaining -= take;
          }

          if (remaining > 0) {
            throw Exception('Stock insuficiente para "${item.product.name}"');
          }
        }

        for (final seg in segments) {
          batchUpdates.add({
            'id': seg.id,
            'new_quantity': seg.available - seg.take,
          });
          movementInserts.add({
            'variant_id': safeVariantId,
            'warehouse_id': pos.selectedWarehouseId,
            'stock_batch_id': seg.id,
            'quantity': -seg.take,
            'previous_stock': seg.available,
            'new_stock': seg.available - seg.take,
            'unit_cost': item.unitCost,
            'reason': 'SALE',
            'notes':
                'Venta POS - ${pos.paymentMethod} · Lote: ${seg.batchNumber}',
            'created_by': currentProfileId,
          });
        }
      }
    }

    String paymentStatus;
    double amountPaid;

    if (isDraft || isCredito) {
      paymentStatus = 'PENDING';
      amountPaid = 0;
    } else {
      paymentStatus = 'PAID';
      amountPaid = totalFinal;
    }

    final puntosGanados =
        isDraft ? 0 : (totalFinal * earningRate / pointsToSolesRatio).toInt();
    final orderStatus = isDraft ? 'PENDING' : 'COMPLETED';

    final orderResp =
        await _supabase
            .from('orders')
            .insert({
              'customer_id': pos.selectedClientId,
              'customer_name':
                  pos.selectedClientId == null ? customerManualName : null,
              'warehouse_id': pos.selectedWarehouseId,
              'total_amount': totalFinal,
              'total_profit': totalProfit,
              'discount_amount': descuentoExtra,
              'payment_method': pos.paymentMethod,
              'payment_status': paymentStatus,
              'amount_paid': amountPaid,
              'status': orderStatus,
              'points_used': isDraft ? 0 : puntosUsados,
              'points_earned': puntosGanados,
              'created_by': currentProfileId,
            })
            .select('id')
            .single();

    final orderId = orderResp['id'];

    for (final item in pos.items.values) {
      await _supabase.from('order_items').insert({
        'order_id': orderId,
        'product_id': item.product.id,
        'variant_id': item.variantId,
        'quantity': item.quantity,
        'unit_cost': item.unitCost,
        'applied_price': item.unitPrice,
        'net_profit': (item.unitPrice - item.unitCost) * item.quantity,
      });
    }

    if (!isDraft) {
      for (final up in batchUpdates) {
        await _supabase
            .from('warehouse_stock_batches')
            .update({'available_quantity': up['new_quantity']})
            .eq('id', up['id']);
      }
      for (final mov in movementInserts) {
        mov['order_id'] = orderId;
        await _supabase.from('inventory_movements').insert(mov);
      }
    }

    if (!isDraft && !isCredito && amountPaid > 0) {
      final accountData = accountsList.firstWhere(
        (a) => a['id'] == selectedAccountId,
        orElse: () => <String, dynamic>{},
      );
      final isCaja = accountData['type'] == 'CAJA';
      final shiftId =
          isCaja && activeShift != null ? activeShift['id'] as String? : null;

      await _supabase.from('account_movements').insert({
        'account_id': selectedAccountId,
        if (shiftId != null) 'shift_id': shiftId,
        'movement_type': 'INCOME',
        'amount': amountPaid,
        'description': 'Ingreso por Venta POS - Orden #$orderId',
        'reference_type': 'orders',
        'reference_id': orderId,
        'created_by': currentProfileId,
      });

      final accResp =
          await _supabase
              .from('financial_accounts')
              .select('balance')
              .eq('id', selectedAccountId!)
              .single();

      final currentBalance = (accResp['balance'] as num).toDouble();
      await _supabase
          .from('financial_accounts')
          .update({'balance': currentBalance + amountPaid})
          .eq('id', selectedAccountId);
    }

    if (!isDraft && pos.selectedClientId != null) {
      if (puntosUsados > 0) {
        final profileData =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', pos.selectedClientId!)
                .single();
        final currentBalance = (profileData['wallet_balance'] as num).toInt();
        final newBalance = (currentBalance - puntosUsados).clamp(
          0,
          currentBalance,
        );

        await _supabase
            .from('profiles')
            .update({'wallet_balance': newBalance})
            .eq('id', pos.selectedClientId!);

        await _supabase.from('wallet_movements').insert({
          'profile_id': pos.selectedClientId,
          'order_id': orderId,
          'points': -puntosUsados,
          'movement_type': 'REDEEMED',
          'description': 'Canje de monedas en venta POS #$orderId',
        });
      }

      if (puntosGanados > 0) {
        final profileData =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', pos.selectedClientId!)
                .single();
        final currentBalance = (profileData['wallet_balance'] as num).toInt();

        await _supabase
            .from('profiles')
            .update({'wallet_balance': currentBalance + puntosGanados})
            .eq('id', pos.selectedClientId!);

        await _supabase.from('wallet_movements').insert({
          'profile_id': pos.selectedClientId,
          'order_id': orderId,
          'points': puntosGanados,
          'movement_type': 'EARNED',
          'description': 'Monedas ganadas en venta POS #$orderId',
        });
      }
    }

    if (!isDraft && isCredito && pos.selectedClientId != null) {
      final latestCredit =
          await _supabase
              .from('customer_credits')
              .select('id, current_debt')
              .eq('profile_id', pos.selectedClientId!)
              .single();

      final creditId = latestCredit['id'] as String;
      final currentDebt = (latestCredit['current_debt'] as num).toDouble();
      final newDebt = currentDebt + totalFinal;

      await _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);

      await _supabase.from('customer_credit_movements').insert({
        'credit_id': creditId,
        'order_id': orderId,
        'movement_type': 'CHARGE',
        'amount': totalFinal,
        'payment_method': 'CRÉDITO',
        'notes': 'Cargo por venta POS Pedido #$orderId',
        'created_by': currentProfileId,
      });
    }
  }
}
