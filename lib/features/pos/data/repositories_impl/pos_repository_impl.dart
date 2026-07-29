import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

@LazySingleton(as: PosRepository)
class PosRepositoryImpl implements PosRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, PosInitData>> loadInitialData({
    bool forceRefresh = false,
  }) async {
    try {
      final whRes = await _supabase
          .from('warehouses')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      final warehouses =
          (whRes as List).map((w) => WarehouseModel.fromJson(w)).toList();

      final accRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('type')
          .order('name');

      final accounts = List<Map<String, dynamic>>.from(accRes);

      return right(PosInitData(warehouses: warehouses, accounts: accounts));
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, CashShiftEntity?>> checkActiveShift(
    String accountId,
  ) async {
    try {
      final shiftData =
          await _supabase
              .from('cash_shifts')
              .select(
                'id, status, opening_amount, opened_at, expected_amount, actual_amount, difference_amount, notes, closed_at, account_id',
              )
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();

      if (shiftData == null) return right(null);

      final shift = CashShiftEntity(
        id: shiftData['id'],
        status: CashShiftStatus.fromString(shiftData['status']),
        openingAmount: (shiftData['opening_amount'] as num).toDouble(),
        openedAt: DateTime.parse(shiftData['opened_at']),
        expectedAmount:
            shiftData['expected_amount'] != null
                ? (shiftData['expected_amount'] as num).toDouble()
                : null,
        actualAmount:
            shiftData['actual_amount'] != null
                ? (shiftData['actual_amount'] as num).toDouble()
                : null,
        differenceAmount:
            shiftData['difference_amount'] != null
                ? (shiftData['difference_amount'] as num).toDouble()
                : null,
        notes: shiftData['notes'],
        closedAt:
            shiftData['closed_at'] != null
                ? DateTime.parse(shiftData['closed_at'])
                : null,
        accountId: shiftData['account_id'],
      );

      return right(shift);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchClients(
    String text,
  ) async {
    try {
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
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> fetchClientCredit(
    String clientId,
  ) async {
    try {
      final response =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', clientId)
              .maybeSingle();
      return right(response);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, List<BatchAssignmentModel>>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    try {
      final resp = await _supabase
          .from('warehouse_stock_batches')
          .select('id, batch_number, expiry_date, available_quantity')
          .eq('variant_id', variantId)
          .eq('warehouse_id', warehouseId)
          .gt('available_quantity', 0)
          .order('expiry_date', ascending: true, nullsFirst: false);

      final batches =
          (resp as List).map((b) {
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

      return right(batches);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, String>> processSale(SaleEntity sale) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) throw Exception('No hay usuario autenticado');

      final profileResp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .single();
      final String currentProfileId = profileResp['id'];

      List<Map<String, dynamic>> batchUpdates = [];
      List<Map<String, dynamic>> movementInserts = [];

      for (final item in sale.items) {
        final safeVariantId = item.variantId;
        if (safeVariantId == null) {
          throw Exception('No variant ID for item ${item.productId}');
        }

        List<({String id, int take, int available, String batchNumber})>
        segments = [];

        final batchAssigned = item.batchAssignments;
        if (batchAssigned != null && batchAssigned.isNotEmpty) {
          final totalAssigned = batchAssigned.fold(0, (s, b) => s + b.assigned);
          if (totalAssigned != item.quantity) {
            throw 'La asignación de lotes suma $totalAssigned pero la cantidad vendida es ${item.quantity}.';
          }
          for (final b in batchAssigned) {
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
              .eq('warehouse_id', sale.warehouseId)
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
            throw 'Stock insuficiente para item con variantId $safeVariantId';
          }
        }

        if (!sale.isDraft) {
          for (final seg in segments) {
            batchUpdates.add({
              'id': seg.id,
              'new_quantity': seg.available - seg.take,
            });
            movementInserts.add({
              'variant_id': safeVariantId,
              'warehouse_id': sale.warehouseId,
              'stock_batch_id': seg.id,
              'quantity': -seg.take,
              'previous_stock': seg.available,
              'new_stock': seg.available - seg.take,
              'unit_cost': item.unitCost,
              'reason': 'SALE',
              'notes':
                  'Venta POS - ${sale.paymentMethod} • Lote: ${seg.batchNumber}',
              'created_by': currentProfileId,
            });
          }
        }
      }

      final orderStatus = sale.isDraft ? 'PENDING' : 'COMPLETED';

      final orderResp =
          await _supabase
              .from('orders')
              .insert({
                'customer_id': sale.customerId,
                'customer_name':
                    sale.customerId == null ? sale.customerName : null,
                'warehouse_id': sale.warehouseId,
                'total_amount': sale.totalAmount,
                'total_profit': sale.totalProfit,
                'discount_amount': sale.discountAmount,
                'payment_method': sale.paymentMethod,
                'payment_status': sale.paymentStatus.toSupabaseString(),
                'amount_paid': sale.amountPaid,
                'status': orderStatus,
                'points_used': sale.isDraft ? 0 : sale.pointsUsed,
                'points_earned': sale.isDraft ? 0 : sale.pointsEarned,
                'created_by': currentProfileId,
              })
              .select('id')
              .single();

      final orderId = orderResp['id'];

      for (final item in sale.items) {
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.productId,
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_cost': item.unitCost,
          'unit_price': item.appliedPrice,
          'subtotal': item.subtotal,
          'net_profit': item.netProfit,
        });
      }

      if (!sale.isDraft) {
        if (sale.activeShift != null && sale.accountId != null) {
          await _supabase.from('account_movements').insert({
            'account_id': sale.accountId,
            'shift_id': sale.activeShift!.id,
            'movement_type': 'INCOME',
            'amount': sale.amountPaid,
            'reason': 'SALE',
            'reference_id': orderId,
            'reference_type': 'ORDER',
            'notes': 'Venta POS #${orderId.substring(0, 8)}',
            'created_by': currentProfileId,
          });

          final accResp =
              await _supabase
                  .from('financial_accounts')
                  .select('balance')
                  .eq('id', sale.accountId!)
                  .single();
          final currentBalance = (accResp['balance'] as num).toDouble();

          await _supabase
              .from('financial_accounts')
              .update({'balance': currentBalance + sale.amountPaid})
              .eq('id', sale.accountId!);
        }

        for (final upd in batchUpdates) {
          await _supabase
              .from('warehouse_stock_batches')
              .update({'available_quantity': upd['new_quantity']})
              .eq('id', upd['id']);
        }

        if (movementInserts.isNotEmpty) {
          await _supabase.from('inventory_movements').insert(movementInserts);
        }

        if (sale.pointsEarned > 0 || sale.pointsUsed > 0) {
          if (sale.customerId != null) {
            final profileWalletResp =
                await _supabase
                    .from('profiles')
                    .select('wallet_balance')
                    .eq('id', sale.customerId!)
                    .single();
            final currentPoints =
                (profileWalletResp['wallet_balance'] as num).toInt();
            final newPoints =
                currentPoints + sale.pointsEarned - sale.pointsUsed;

            await _supabase
                .from('profiles')
                .update({'wallet_balance': newPoints})
                .eq('id', sale.customerId!);

            await _supabase.from('wallet_movements').insert({
              'profile_id': sale.customerId,
              'amount': sale.pointsEarned - sale.pointsUsed,
              'movement_type':
                  (sale.pointsEarned - sale.pointsUsed) >= 0
                      ? 'EARNED'
                      : 'REDEEMED',
              'description': 'Puntos por Venta #${orderId.substring(0, 8)}',
              'reference_id': orderId,
              'reference_type': 'ORDER',
              'created_by': currentProfileId,
            });
          }
        }

        if (sale.isCredit && sale.customerId != null) {
          final creditResp =
              await _supabase
                  .from('customer_credits')
                  .select('id, current_debt')
                  .eq('profile_id', sale.customerId!)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();

          if (creditResp != null) {
            final creditId = creditResp['id'];
            final currentDebt = (creditResp['current_debt'] as num).toDouble();
            final newDebt = currentDebt + sale.totalAmount;

            await _supabase
                .from('customer_credits')
                .update({'current_debt': newDebt})
                .eq('id', creditId);

            await _supabase.from('customer_credit_movements').insert({
              'credit_id': creditId,
              'amount': sale.totalAmount,
              'movement_type': 'CHARGE',
              'description': 'Crédito Venta POS #${orderId.substring(0, 8)}',
              'reference_id': orderId,
              'created_by': currentProfileId,
            });
          }
        }
      }

      return right(orderId);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
