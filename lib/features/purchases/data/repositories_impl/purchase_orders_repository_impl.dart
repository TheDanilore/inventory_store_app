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
              .select('''
                id, created_at, supplier_id, supplier_name, warehouse_id,
                status, total_amount, payment_method, payment_status,
                amount_paid, due_date, discount_amount, tax_amount,
                document_date, document_type, document_number, notes, updated_at,
                suppliers!left(name),
                warehouses!left(name),
                purchase_order_items(count)
              ''')
              .eq('id', poId)
              .maybeSingle();
      return Right(poResp);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        '[PurchaseOrdersRepositoryImpl] getPurchaseOrderById PostgrestException: ${e.message}',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        '[PurchaseOrdersRepositoryImpl] getPurchaseOrderById error: $e',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'fetchOrders PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'fetchOrders unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'fetchOrderItems fatal error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'updateOrderStatus error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
  Future<Either<Failure, void>> updatePurchaseOrder({
    required String orderId,
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required List<dynamic> items,
    required double totalAmount,
    required String paymentMode,
    required String paymentStatus,
    required DateTime? dueDate,
    required DateTime? documentDate,
    required String documentType,
    required String? documentNumber,
    required String? notes,
  }) async {
    try {
      // 1. Validar que la orden exista y esté en estado PENDIENTE sin pagos
      final currentPo = await _supabase
          .from('purchase_orders')
          .select(
            'id, status, amount_paid, payment_method, supplier_id, total_amount',
          )
          .eq('id', orderId)
          .maybeSingle();

      if (currentPo == null) {
        return Left(ServerFailure(message: 'La orden de compra no existe.'));
      }

      final status = currentPo['status']?.toString().toUpperCase();
      final amountPaid = (currentPo['amount_paid'] as num?)?.toDouble() ?? 0.0;
      if (status != 'PENDING' || amountPaid > 0) {
        return Left(
          ServerFailure(
            message:
                'Solo se pueden editar órdenes en estado PENDIENTE y sin pagos registrados.',
          ),
        );
      }

      // Validar que no tenga recepciones
      final itemsCheck = await _supabase
          .from('purchase_order_items')
          .select('quantity_received')
          .eq('purchase_order_id', orderId);

      final hasReceived = (itemsCheck as List).any((it) {
        final qr = (it['quantity_received'] as num?)?.toDouble() ?? 0.0;
        return qr > 0;
      });

      if (hasReceived) {
        return Left(
          ServerFailure(
            message:
                'No se puede editar una orden que ya tiene mercadería recibida.',
          ),
        );
      }

      // 2. Ajustes de crédito si aplica
      final oldMethod = currentPo['payment_method']?.toString().toUpperCase();
      final oldSupplierId = currentPo['supplier_id']?.toString();
      final oldTotal = (currentPo['total_amount'] as num?)?.toDouble() ?? 0.0;

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

      if (oldMethod == 'CRÉDITO') {
        if (paymentMode == 'CRÉDITO') {
          if (oldSupplierId == supplierId) {
            final diff = totalAmount - oldTotal;
            if (diff != 0) {
              final creditRes = await _supabase
                  .from('supplier_credits')
                  .select('id, current_debt, credit_limit, is_active')
                  .eq('supplier_id', supplierId)
                  .maybeSingle();
              if (creditRes != null) {
                final currentDebt =
                    (creditRes['current_debt'] as num?)?.toDouble() ?? 0.0;
                final creditLimit =
                    (creditRes['credit_limit'] as num?)?.toDouble() ?? 0.0;
                if (diff > 0 &&
                    creditLimit > 0 &&
                    (currentDebt + diff) > creditLimit) {
                  return Left(
                    ServerFailure(
                      message:
                          'Límite de crédito excedido con este proveedor para el nuevo total.',
                    ),
                  );
                }
                await _supabase
                    .from('supplier_credits')
                    .update({
                      'current_debt': currentDebt + diff,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', creditRes['id']);

                await _supabase.from('supplier_credit_movements').insert({
                  'supplier_credit_id': creditRes['id'],
                  'movement_type': diff > 0 ? 'CHARGE' : 'ADJUSTMENT',
                  'amount': diff.abs(),
                  'purchase_order_id': orderId,
                  'notes':
                      'Ajuste por edición de OC #${orderId.substring(0, 8)}',
                  'created_by': profileId,
                });
              }
            }
          } else {
            if (oldSupplierId != null) {
              final oldCredit = await _supabase
                  .from('supplier_credits')
                  .select('id, current_debt')
                  .eq('supplier_id', oldSupplierId)
                  .maybeSingle();
              if (oldCredit != null) {
                final curDebt =
                    (oldCredit['current_debt'] as num?)?.toDouble() ?? 0.0;
                await _supabase
                    .from('supplier_credits')
                    .update({
                      'current_debt': (curDebt - oldTotal).clamp(
                        0.0,
                        double.infinity,
                      ),
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', oldCredit['id']);
              }
            }
            final newCredit = await _supabase
                .from('supplier_credits')
                .select('id, current_debt, credit_limit, is_active')
                .eq('supplier_id', supplierId)
                .maybeSingle();
            if (newCredit != null) {
              final currentDebt =
                  (newCredit['current_debt'] as num?)?.toDouble() ?? 0.0;
              final creditLimit =
                  (newCredit['credit_limit'] as num?)?.toDouble() ?? 0.0;
              if (creditLimit > 0 &&
                  (currentDebt + totalAmount) > creditLimit) {
                return Left(
                  ServerFailure(
                    message:
                        'Límite de crédito excedido con el nuevo proveedor.',
                  ),
                );
              }
              await _supabase
                  .from('supplier_credits')
                  .update({
                    'current_debt': currentDebt + totalAmount,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', newCredit['id']);
            }
          }
        } else {
          if (oldSupplierId != null) {
            final oldCredit = await _supabase
                .from('supplier_credits')
                .select('id, current_debt')
                .eq('supplier_id', oldSupplierId)
                .maybeSingle();
            if (oldCredit != null) {
              final curDebt =
                  (oldCredit['current_debt'] as num?)?.toDouble() ?? 0.0;
              await _supabase
                  .from('supplier_credits')
                  .update({
                    'current_debt': (curDebt - oldTotal).clamp(
                      0.0,
                      double.infinity,
                    ),
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', oldCredit['id']);
            }
          }
        }
      } else if (paymentMode == 'CRÉDITO') {
        final newCredit = await _supabase
            .from('supplier_credits')
            .select('id, current_debt, credit_limit, is_active')
            .eq('supplier_id', supplierId)
            .maybeSingle();
        if (newCredit != null) {
          final currentDebt =
              (newCredit['current_debt'] as num?)?.toDouble() ?? 0.0;
          final creditLimit =
              (newCredit['credit_limit'] as num?)?.toDouble() ?? 0.0;
          if (creditLimit > 0 && (currentDebt + totalAmount) > creditLimit) {
            return Left(
              ServerFailure(
                message: 'Límite de crédito excedido con este proveedor.',
              ),
            );
          }
          await _supabase
              .from('supplier_credits')
              .update({
                'current_debt': currentDebt + totalAmount,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', newCredit['id']);
        }
      }

      // 3. Actualizar purchase_orders
      await _supabase
          .from('purchase_orders')
          .update({
            'supplier_id': supplierId,
            'supplier_name': supplierName,
            'warehouse_id': warehouseId,
            'total_amount': totalAmount,
            'payment_method': paymentMode,
            'payment_status': paymentStatus,
            'due_date': dueDate?.toIso8601String().split('T').first,
            'document_date': documentDate?.toIso8601String().split('T').first,
            'document_type': documentType,
            'document_number': documentNumber,
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // 4. Eliminar ítems anteriores y re-insertar
      await _supabase
          .from('purchase_order_items')
          .delete()
          .eq('purchase_order_id', orderId);

      final itemsToInsert =
          items.map((item) {
            final rawVariantId = item.variantId?.toString().trim();
            final safeVariantId =
                (rawVariantId != null && rawVariantId.isNotEmpty)
                    ? rawVariantId
                    : null;
            final subtotal =
                (item.quantity as num).toDouble() *
                (item.unitCost as num).toDouble();
            final expDate = item.expiryDate;
            final expDateStr =
                (expDate is DateTime)
                    ? expDate.toIso8601String().split('T').first
                    : null;

            return {
              'purchase_order_id': orderId,
              'product_id': item.productId,
              'variant_id': safeVariantId,
              'quantity_ordered': item.quantity,
              'quantity_received': 0.0,
              'unit_cost': item.unitCost,
              'net_cost': item.unitCost,
              'subtotal': subtotal,
              'batch_number': item.batchNumber ?? 'DEFAULT',
              'expiry_date': expDateStr,
            };
          }).toList();

      await _supabase.from('purchase_order_items').insert(itemsToInsert);

      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'updatePurchaseOrder PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'updatePurchaseOrder unexpected error: $e',
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
      LoggerService.e(
        'receiveOrderItems error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'registerOrderPayment PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'registerOrderPayment unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'updateOrderPaymentMethod PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'updateOrderPaymentMethod unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'getFormCatalogs PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al cargar catálogos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'getFormCatalogs unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
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
      LoggerService.e(
        'getSupplierCredit PostgrestException: ${e.message}',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al consultar crédito: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'getSupplierCredit unexpected error: $e',
        tag: 'PURCHASE_ORDERS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error inesperado al consultar crédito: $e'),
      );
    }
  }
}
