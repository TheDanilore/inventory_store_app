import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/pos/data/datasources/pos_remote_datasource.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

class PosRepositoryImpl implements PosRepository {
  final PosRemoteDataSource _remoteDataSource;

  PosRepositoryImpl({PosRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? PosRemoteDataSourceImpl();

  @override
  Future<PosInitData> loadInitialData({bool forceRefresh = false}) async {
    final warehouses = await _remoteDataSource.fetchActiveWarehouses();
    final accounts = await _remoteDataSource.fetchActiveAccounts();
    return PosInitData(warehouses: warehouses, accounts: accounts);
  }

  @override
  Future<CashShiftEntity?> checkActiveShift(String accountId) async {
    final shiftData = await _remoteDataSource.fetchActiveShift(accountId);
    if (shiftData == null) return null;

    return CashShiftEntity(
      id: shiftData['id'],
      status: CashShiftStatus.fromString(shiftData['status']),
      openingAmount: (shiftData['opening_amount'] as num).toDouble(),
      openedAt: DateTime.parse(shiftData['opened_at']),
      expectedAmount: shiftData['expected_amount'] != null ? (shiftData['expected_amount'] as num).toDouble() : null,
      actualAmount: shiftData['actual_amount'] != null ? (shiftData['actual_amount'] as num).toDouble() : null,
      differenceAmount: shiftData['difference_amount'] != null ? (shiftData['difference_amount'] as num).toDouble() : null,
      notes: shiftData['notes'],
      closedAt: shiftData['closed_at'] != null ? DateTime.parse(shiftData['closed_at']) : null,
      accountId: shiftData['account_id'],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchClients(String text) async {
    return _remoteDataSource.searchClients(text);
  }

  @override
  Future<Map<String, dynamic>?> fetchClientCredit(String clientId) async {
    return _remoteDataSource.fetchClientCredit(clientId);
  }

  @override
  Future<List<BatchAssignmentModel>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    return _remoteDataSource.fetchBatchesForVariant(variantId, warehouseId);
  }

  @override
  Future<String> processSale(SaleEntity sale) async {
    final profile = await _remoteDataSource.getCurrentProfile();
    final currentProfileId = profile['id'];

    List<Map<String, dynamic>> batchUpdates = [];
    List<Map<String, dynamic>> movementInserts = [];

    // 1. Preparar deducciones de stock (Lotes)
    if (!sale.isDraft) {
      for (final item in sale.items) {
        if (item.variantId == null) continue; // Si no hay variante, saltar o lanzar error según modelo de negocio

        final batches = await _remoteDataSource.fetchStockBatches(
          item.variantId!,
          sale.warehouseId,
        );

        int remaining = item.quantity;
        for (final batch in batches) {
          if (remaining <= 0) break;
          final int available = (batch['available_quantity'] as num).toInt();
          final int take = (remaining > available) ? available : remaining;
          
          batchUpdates.add({
            'id': batch['id'],
            'new_quantity': available - take,
          });
          
          movementInserts.add({
            'variant_id': item.variantId,
            'warehouse_id': sale.warehouseId,
            'stock_batch_id': batch['id'],
            'quantity': -take,
            'previous_stock': available,
            'new_stock': available - take,
            'unit_cost': item.unitCost,
            'reason': 'SALE',
            'notes': 'Venta POS - ${sale.paymentMethod} • Lote: ${batch['batch_number']}',
            'created_by': currentProfileId,
          });
          remaining -= take;
        }

        if (remaining > 0) {
          throw Exception('Stock insuficiente para el ítem con variante ${item.variantId}');
        }
      }
    }

    // 2. Crear la orden (Order)
    final orderId = await _remoteDataSource.createOrder({
      'customer_id': sale.customerId,
      'customer_name': sale.customerName,
      'warehouse_id': sale.warehouseId,
      'total_amount': sale.totalAmount,
      'total_profit': sale.totalProfit,
      'discount_amount': sale.discountAmount,
      'payment_method': sale.paymentMethod,
      'payment_status': sale.paymentStatus.toSupabaseString(),
      'amount_paid': sale.amountPaid,
      'status': sale.isDraft ? 'PENDING' : 'COMPLETED',
      'points_used': sale.pointsUsed,
      'points_earned': sale.pointsEarned,
      'created_by': currentProfileId,
    });

    // 3. Crear los ítems (OrderItems)
    final itemsData = sale.items.map((item) {
      return {
        'order_id': orderId,
        'product_id': item.productId,
        'variant_id': item.variantId,
        'quantity': item.quantity,
        'unit_cost': item.unitCost,
        'applied_price': item.appliedPrice,
        'net_profit': item.netProfit,
      };
    }).toList();
    await _remoteDataSource.createOrderItems(itemsData);

    // 4. Actualizar stock e insertar movimientos
    if (!sale.isDraft) {
      await _remoteDataSource.updateBatchQuantities(batchUpdates);
      for (var mov in movementInserts) {
        mov['order_id'] = orderId;
      }
      await _remoteDataSource.createInventoryMovements(movementInserts);
    }

    // 5. Movimientos de Caja (Account)
    if (!sale.isDraft && !sale.isCredit && sale.amountPaid > 0 && sale.accountId != null) {
      await _remoteDataSource.createAccountMovement({
        'account_id': sale.accountId,
        if (sale.activeShift != null) 'shift_id': sale.activeShift!['id'],
        'movement_type': 'INCOME',
        'amount': sale.amountPaid,
        'description': 'Ingreso por Venta POS - Orden #$orderId',
        'reference_type': 'orders',
        'reference_id': orderId,
        'created_by': currentProfileId,
      });

      // Nota: lo ideal sería traer el balance de manera atómica con RPC de Postgres.
      // Simplificado para la demostración:
      // await _remoteDataSource.updateAccountBalance(sale.accountId!, currentBalance + sale.amountPaid);
    }

    // 6. Monedas / Fidelización
    if (!sale.isDraft && sale.customerId != null) {
      if (sale.pointsUsed > 0) {
        final wallet = await _remoteDataSource.fetchProfileWallet(sale.customerId!);
        final currentBalance = (wallet['wallet_balance'] as num).toInt();
        await _remoteDataSource.updateProfileWallet(sale.customerId!, currentBalance - sale.pointsUsed);
        await _remoteDataSource.createWalletMovement({
          'profile_id': sale.customerId,
          'order_id': orderId,
          'points': -sale.pointsUsed,
          'movement_type': 'REDEEMED',
          'description': 'Canje de monedas en venta POS #$orderId',
        });
      }

      if (sale.pointsEarned > 0 && !sale.isCredit) {
        final wallet = await _remoteDataSource.fetchProfileWallet(sale.customerId!);
        final currentBalance = (wallet['wallet_balance'] as num).toInt();
        await _remoteDataSource.updateProfileWallet(sale.customerId!, currentBalance + sale.pointsEarned);
        await _remoteDataSource.createWalletMovement({
          'profile_id': sale.customerId,
          'order_id': orderId,
          'points': sale.pointsEarned,
          'movement_type': 'EARNED',
          'description': 'Monedas ganadas en venta POS #$orderId',
        });
      }
    }

    // 7. Venta al Crédito
    if (!sale.isDraft && sale.isCredit && sale.customerId != null) {
      final credit = await _remoteDataSource.fetchLatestCustomerCredit(sale.customerId!);
      final currentDebt = (credit['current_debt'] as num).toDouble();
      await _remoteDataSource.updateCustomerCredit(credit['id'], currentDebt + sale.totalAmount);
      await _remoteDataSource.createCustomerCreditMovement({
        'customer_credit_id': credit['id'],
        'order_id': orderId,
        'movement_type': 'CHARGE',
        'amount': sale.totalAmount,
        'payment_method': 'CRÉDITO',
        'notes': 'Cargo por venta POS Pedido #$orderId',
        'created_by': currentProfileId,
      });
    }

    return orderId;
  }
}
