import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'dart:developer' as developer;
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

@LazySingleton(as: PosRepository)
class PosRepositoryImpl implements PosRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  PosRepositoryImpl();

  String? _cachedProfileId;
  String? _cachedRole;

  Future<void> _ensureProfileLoaded() async {
    if (_cachedProfileId != null && _cachedRole != null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('profiles')
        .select('id, role')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (profile != null) {
      _cachedProfileId = profile['id'] as String?;
      _cachedRole = profile['role'] as String?;
    }
  }

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

      final warehouses = (whRes as List);

      final accRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('type')
          .order('name');

      final accData = List<Map<String, dynamic>>.from(accRes);

      return right(
        PosInitData(
          warehouses:
              warehouses.map((e) => WarehouseModel.fromJson(e)).toList(),
          accounts: accData,
        ),
      );
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en loadInitialData',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en loadInitialData',
        error: e,
        stackTrace: stack,
      );
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
    } catch (e, stack) {
      developer.log('Error en searchClients', error: e, stackTrace: stack);
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
    } catch (e, stack) {
      developer.log('Error en fetchClientCredit', error: e, stackTrace: stack);
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
    } catch (e, stack) {
      developer.log(
        'Error en fetchBatchesForVariant',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, String>> processSale(SaleEntity sale) async {
    try {
      final saleJson = {
        'customerId': sale.customerId,
        'customerName': sale.customerName,
        'warehouseId': sale.warehouseId,
        'totalAmount': sale.totalAmount,
        'totalProfit': sale.totalProfit,
        'discountAmount': sale.discountAmount,
        'paymentMethod': sale.paymentMethod,
        'paymentStatus': sale.paymentStatus.toSupabaseString(),
        'amountPaid': sale.amountPaid,
        'isDraft': sale.isDraft,
        'isCredit': sale.isCredit,
        'pointsUsed': sale.pointsUsed,
        'pointsEarned': sale.pointsEarned,
        'accountId': sale.accountId,
        'activeShiftId':
            null, // The backend RPC must validate and fetch the active shift
        'createdBy': null,
        'items':
            sale.items
                .map(
                  (item) => {
                    'productId': item.productId,
                    'variantId': item.variantId,
                    'quantity': item.quantity,
                    'unitCost': item.unitCost,
                    'appliedPrice': item.appliedPrice,
                    'subtotal': item.subtotal,
                    'netProfit': item.netProfit,
                    'batchAssignments':
                        item.batchAssignments
                            ?.map(
                              (b) => {
                                'batchId': b.batchId,
                                'take': b.assigned,
                                'batchNumber': b.batchNumber,
                              },
                            )
                            .toList(),
                  },
                )
                .toList(),
      };

      final response = await _supabase.rpc(
        'process_pos_sale',
        params: {'payload': saleJson},
      );

      final orderId = response as String;
      return right(orderId);
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en processSale RPC',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: _mapSaleError(e)));
    } catch (e, stack) {
      developer.log(
        'Error general en processSale RPC',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  String _mapSaleError(PostgrestException e) {
    switch (e.code) {
      case 'P0010':
        return 'El cliente no tiene línea de crédito registrada.';
      case 'P0011':
        return 'La línea de crédito del cliente no está activa.';
      case 'P0012':
        return e.message.isNotEmpty
            ? e.message
            : 'Crédito insuficiente para completar la venta.';
    }
    if (e.message.isNotEmpty) {
      return e.message;
    }
    return 'Ocurrió un error al procesar la venta en la base de datos.';
  }

  @override
  Future<Either<Failure, ({OrderModel order, List<OrderItemModel> items})>>
  fetchOrderForReceipt(String orderId) async {
    try {
      final orderResp =
          await _supabase
              .from('orders')
              .select(
                'id, customer_name, customer_id, total_amount, total_profit, discount_amount, payment_method, payment_status, amount_paid, status, points_used, points_earned, created_at, warehouse_id, profiles!orders_customer_id_fkey(full_name, phone), warehouses(name)',
              )
              .eq('id', orderId)
              .single();

      final itemsResp = await _supabase
          .from('order_items')
          .select(
            // Se omite product_images intencionalmente: no se muestran en el PDF del ticket.
            'id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at, products(name), product_variants(sku, variant_attribute_values(attribute_values(value, attributes(name))))',
          )
          .eq('order_id', orderId);

      // Delegar la deserialización a un Isolate de forma segura
      final result = await IsolateUtils.run(() {
        final order = OrderModel.fromJson(orderResp);
        final items =
            List<Map<String, dynamic>>.from(
              itemsResp,
            ).map((x) => OrderItemModel.fromJson(x)).toList();
        return (order: order, items: items);
      });

      return right(result);
    } catch (e, stack) {
      developer.log(
        'Error en fetchOrderForReceipt',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, List<OrderModel>>> fetchRecentOrders({
    int limit = 10,
  }) async {
    try {
      await _ensureProfileLoaded();
      var query = _supabase
          .from('orders')
          .select('id, total_amount, created_at, customer_name, status');

      if (_cachedRole != 'admin' && _cachedProfileId != null) {
        query = query.eq('created_by', _cachedProfileId!);
      }

      final res = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final List<OrderModel> orders =
          (res as List)
              .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .toList();

      return Right(orders);
    } catch (e, st) {
      developer.log(
        'Error fetching recent POS orders',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al cargar ventas recientes: $e'),
      );
    }
  }
}
