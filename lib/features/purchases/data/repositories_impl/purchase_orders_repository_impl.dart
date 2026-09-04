import 'dart:developer' as developer;
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';

@LazySingleton(as: PurchaseOrdersRepository)
class PurchaseOrdersRepositoryImpl implements PurchaseOrdersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getPurchaseOrderById(
    String poId,
  ) async {
    try {
      final poResp =
          await _supabase
              .from('purchase_orders')
              .select(
                'id, supplier_id, warehouse_id, status, total_amount, payment_method, payment_status, amount_paid, due_date, document_type, document_number, notes, created_at, updated_at, suppliers(name)',
              )
              .eq('id', poId)
              .maybeSingle();
      return Right(poResp);
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getPurchaseOrderById PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getPurchaseOrderById error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> fetchOrders({
    required int page,
    required int pageSize,
    String searchText = '',
    String statusFilter = 'Todos',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = page * pageSize;
      final end = start + pageSize - 1;

      var query = _supabase.from('purchase_orders').select('''
            id, created_at, supplier_id, supplier_name, warehouse_id,
            status, total_amount, payment_method, payment_status,
            amount_paid, due_date, discount_amount, tax_amount,
            document_type, document_number, notes,
            suppliers!left(name),
            warehouses!left(name),
            purchase_order_items(count)
          ''');

      if (statusFilter != 'Todos') {
        query = query.eq('status', statusFilter);
      }

      if (startDate != null && endDate != null) {
        final startIso = startDate.toIso8601String();
        final endIso = endDate.add(const Duration(days: 1)).toIso8601String();
        query = query.gte('created_at', startIso).lt('created_at', endIso);
      }

      if (searchText.trim().isNotEmpty) {
        final txt = '%${searchText.trim()}%';
        query = query.or(
          'supplier_name.ilike.$txt,document_number.ilike.$txt,notes.ilike.$txt',
        );
      }

      final finalQuery = query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      final response = await finalQuery;
      final List<PurchaseOrderEntity> dataList =
          (response.data as List)
              .map(
                (e) => PurchaseOrderModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();

      return Right({'data': dataList, 'count': response.count});
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] fetchOrders PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] fetchOrders error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PurchaseOrderItemEntity>>> fetchOrderItems(
    String poId,
  ) async {
    try {
      // ── 1. Fetch data through single RPC (Zero N+1 Data Egress) ────────
      final response = await _supabase.rpc(
        'get_purchase_order_items_details',
        params: {'p_order_id': poId},
      );

      final rows = response as List;
      if (rows.isEmpty) return const Right([]);

      // ── 2. Build result ────────────────────────────────────────────────
      final list =
          rows.map((r) {
            return PurchaseOrderItemModel(
              productId: r['product_id'] as String? ?? '',
              variantId: r['variant_id'] as String? ?? '',
              productName: r['product_name'] as String? ?? 'Producto',
              variantAttrs: r['variant_attrs'] as String? ?? 'Única',
              sku: r['sku'] as String?,
              quantityOrdered:
                  (r['quantity_ordered'] as num?)?.toDouble() ?? 0.0,
              quantityReceived:
                  (r['quantity_received'] as num?)?.toDouble() ?? 0.0,
              unitCost: (r['unit_cost'] as num?)?.toDouble() ?? 0.0,
              batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
              expiryDate:
                  r['expiry_date'] != null
                      ? DateTime.tryParse(r['expiry_date'] as String)
                      : null,
              usesBatches: r['uses_batches'] as bool? ?? false,
              imageUrl: r['image_url'] as String?,
            );
          }).toList();

      return Right(list);
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] fetchOrderItems fatal error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderStatus(
    String poId,
    String status,
  ) async {
    try {
      if (status == 'CANCELLED') {
        final currentUser = _supabase.auth.currentUser;
        String? profileId;
        if (currentUser != null) {
          final profile =
              await _supabase
                  .from('profiles')
                  .select('id')
                  .eq('auth_user_id', currentUser.id)
                  .maybeSingle();
          profileId = profile?['id'] as String?;
        }

        final res = await _supabase.rpc(
          'cancel_purchase_order_rpc',
          params: {'p_purchase_order_id': poId, 'p_profile_id': profileId},
        );

        if (res is Map && res['success'] == false) {
          return Left(
            ServerFailure(
              message:
                  res['error']?.toString() ??
                  'Error al anular la orden de compra.',
            ),
          );
        }
        return const Right(null);
      }

      await _supabase
          .from('purchase_orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', poId);
      return const Right(null);
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] updateOrderStatus error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createPurchaseOrder({
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required List<dynamic> items,
    required double totalAmount,
    required String paymentMode,
    required String paymentStatus,
    required String? accountId,
    required String? activeShiftId,
    required DateTime? dueDate,
    required DateTime? documentDate,
    required String documentType,
    required String? documentNumber,
    required String? notes,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      String? profileId;
      if (currentUser != null) {
        // La obtención del profileId se podría hacer con auth.uid() dentro del RPC,
        // pero por mantener la firma de la llamada original si el RPC actual lo exige,
        // lo mantenemos o lo pasamos como null si queremos que el RPC lo maneje internamente.
        // Asumiremos que el RPC lo buscará si p_profile_id es nulo (como escribí en el script).
      }

      // 3. Ejecución atómica mediante RPC en Supabase
      final itemsJson =
          items.map((item) {
            final rawVariantId = item.variantId?.toString().trim();
            final safeVariantId =
                (rawVariantId != null && rawVariantId.isNotEmpty)
                    ? rawVariantId
                    : null;
            return {
              'product_id': item.productId,
              'variant_id': safeVariantId,
              'quantity': item.quantity,
              'unit_cost': item.unitCost,
              'batch_number': item.batchNumber,
              'expiry_date': item.expiryDate?.toIso8601String(),
            };
          }).toList();

      final rpcRes = await _supabase.rpc(
        'create_purchase_order_rpc',
        params: {
          'p_supplier_id': supplierId,
          'p_supplier_name': supplierName,
          'p_warehouse_id': warehouseId,
          'p_total_amount': totalAmount,
          'p_payment_method': paymentMode,
          'p_payment_status': paymentStatus,
          'p_account_id': accountId,
          'p_active_shift_id': activeShiftId,
          'p_due_date': dueDate?.toIso8601String().split('T').first,
          'p_document_date': documentDate?.toIso8601String().split('T').first,
          'p_document_type': documentType,
          'p_document_number': documentNumber,
          'p_notes': notes,
          'p_profile_id': profileId,
          'p_items': itemsJson,
        },
      );

      if (rpcRes != null && rpcRes is Map) {
        final isSuccess = rpcRes['success'] as bool? ?? false;
        if (isSuccess) {
          return const Right(null);
        } else if (rpcRes['error'] != null) {
          return Left(ServerFailure(message: rpcRes['error'].toString()));
        }
      }
      return Left(
        ServerFailure(
          message:
              'El servidor rechazó la creación de la orden (respuesta no confirmada).',
        ),
      );
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'createPurchaseOrder PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'createPurchaseOrder unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> receiveOrderItems({
    required String poId,
    required List<Map<String, dynamic>> receivedItems,
    required String warehouseId,
  }) async {
    try {
      final itemsPayload =
          receivedItems.map((pItem) {
            return {
              'receiveQty': (pItem['receiveQty'] as num).toDouble(),
              'fullyReceived': pItem['fullyReceived'] as bool? ?? false,
              'product_id': pItem['product_id'],
              'variant_id': pItem['variant_id'],
              'uses_batches': pItem['uses_batches'] as bool? ?? false,
              'batch_number': pItem['batch_number'],
              'expiry_date': pItem['expiry_date'],
            };
          }).toList();

      final response = await _supabase.rpc(
        'rpc_receive_purchase_order_items',
        params: {
          'p_order_id': poId,
          'p_warehouse_id': warehouseId,
          'p_items': itemsPayload,
        },
      );

      if (response is Map && response['success'] == false) {
        return Left(
          ServerFailure(
            message:
                response['error']?.toString() ??
                'Error al procesar inventario.',
          ),
        );
      }

      return const Right(null);
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] receiveOrderItems error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> registerOrderPayment({
    required String orderId,
    required String supplierId,
    required double amount,
    required String accountId,
    required String? shiftId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'register_supplier_credit_payment_rpc',
        params: {
          'p_supplier_id': supplierId,
          'p_credit_id': null,
          'p_amount': amount,
          'p_account_id': accountId,
          'p_order_id': orderId,
          'p_notes':
              'Pago de Orden de Compra #${orderId.substring(0, 8).toUpperCase()}',
          'p_shift_id': shiftId,
          'p_profile_id': _supabase.auth.currentUser?.id,
        },
      );

      final result = response as Map<String, dynamic>?;
      final didSucceed = result?['success'] == true;
      if (!didSucceed) {
        final errMsg =
            result?['error'] as String? ??
            result?['detail'] as String? ??
            'Error desconocido en el servidor.';
        return Left(ServerFailure(message: errMsg));
      }
      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] registerOrderPayment PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] registerOrderPayment unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error inesperado al registrar el pago: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderPaymentMethod({
    required String orderId,
    required String supplierId,
    required String newMethod,
    required String oldMethod,
    required double orderAmount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_po_payment_method_rpc',
        params: {
          'p_order_id': orderId,
          'p_supplier_id': supplierId,
          'p_new_method': newMethod,
          'p_old_method': oldMethod,
          'p_order_amount': orderAmount,
          'p_profile_id': _supabase.auth.currentUser?.id,
        },
      );

      final result = response as Map<String, dynamic>?;
      final didSucceed = result?['success'] == true;
      if (!didSucceed) {
        final errMsg =
            result?['error'] as String? ??
            result?['detail'] as String? ??
            'Error desconocido en el servidor.';
        return Left(ServerFailure(message: errMsg));
      }
      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] updateOrderPaymentMethod PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] updateOrderPaymentMethod unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(
          message: 'Error inesperado al cambiar método de pago: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getFormCatalogs() async {
    try {
      final pRes = await _supabase
          .from('suppliers')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      final wRes = await _supabase
          .from('warehouses')
          .select('id, name, is_active, address')
          .eq('is_active', true)
          .order('name');
      final aRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');
      final shiftsRes = await _supabase
          .from('cash_shifts')
          .select('id, account_id')
          .eq('status', 'OPEN');

      final suppliers = List<Map<String, dynamic>>.from(pRes as List);
      final warehouses =
          (wRes as List).map((e) => WarehouseModel.fromJson(e)).toList();
      final accounts =
          (aRes as List).map((e) => FinancialAccountModel.fromJson(e)).toList();

      final Map<String, String> activeShiftsByAccount = {};
      for (final s in (shiftsRes as List)) {
        if (s['account_id'] != null && s['id'] != null) {
          activeShiftsByAccount[s['account_id'] as String] = s['id'] as String;
        }
      }

      return Right({
        'suppliers': suppliers,
        'warehouses': warehouses,
        'accounts': accounts,
        'activeShiftsByAccount': activeShiftsByAccount,
      });
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getFormCatalogs PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error al cargar catálogos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getFormCatalogs unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error inesperado al cargar catálogos: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getSupplierCredit(
    String supplierId,
  ) async {
    try {
      final creditRes =
          await _supabase
              .from('supplier_credits')
              .select('id, supplier_id, current_debt, credit_limit, is_active')
              .eq('supplier_id', supplierId)
              .maybeSingle();
      return Right(
        creditRes != null ? Map<String, dynamic>.from(creditRes) : null,
      );
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getSupplierCredit PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error al consultar crédito: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getSupplierCredit unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error inesperado al consultar crédito: $e'),
      );
    }
  }
}
