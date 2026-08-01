import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/features/inventory/data/repositories_impl/inventory_entries_repository_impl.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';

@LazySingleton(as: PurchaseOrdersRepository)
class PurchaseOrdersRepositoryImpl implements PurchaseOrdersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getPurchaseOrderById(
      String poId) async {
    try {
      final poResp = await _supabase
          .from('purchase_orders')
          .select('*, suppliers(name)')
          .eq('id', poId)
          .maybeSingle();
      return Right(poResp);
    } catch (e, st) {
      debugPrint('[PurchaseOrdersRepositoryImpl] getPurchaseOrderById error: $e\n$st');
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
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PurchaseOrderItemEntity>>> fetchOrderItems(
    String poId,
  ) async {
    try {
      try {
        await InventoryEntriesRepositoryImpl.syncPurchaseOrderItemsAndStatus(
          _supabase,
          poId,
        );
      } catch (_) {}

      // ── 1. Fetch raw items (no joins) ──────────────────────────────────
      final rawItems = await _supabase
          .from('purchase_order_items')
          .select(
            'product_id, variant_id, quantity_ordered, quantity_received, '
            'unit_cost, batch_number, expiry_date',
          )
          .eq('purchase_order_id', poId);

      final rows = rawItems as List;
      if (rows.isEmpty) return const Right([]);

      // ── 2. Collect unique IDs ──────────────────────────────────────────
      final productIds =
          rows
              .map((r) => r['product_id'] as String?)
              .whereType<String>()
              .toSet()
              .toList();

      final variantIds =
          rows
              .map((r) => r['variant_id'] as String?)
              .whereType<String>()
              .toSet()
              .toList();

      // ── 3. Fetch products ──────────────────────────────────────────────
      final Map<String, Map<String, dynamic>> productMap = {};
      if (productIds.isNotEmpty) {
        try {
          final pResp = await _supabase
              .from('products')
              .select('id, name, uses_batches')
              .inFilter('id', productIds);
          for (final p in pResp as List) {
            final id = p['id'] as String?;
            if (id != null) productMap[id] = Map<String, dynamic>.from(p);
          }
        } catch (e) {
          debugPrint('[fetchOrderItems] products fetch error: $e');
        }
      }

      // ── 4. Fetch variants ──────────────────────────────────────────────
      final Map<String, Map<String, dynamic>> variantMap = {};
      if (variantIds.isNotEmpty) {
        try {
          final vResp = await _supabase
              .from('product_variants')
              .select('id, sku')
              .inFilter('id', variantIds);
          for (final v in vResp as List) {
            final id = v['id'] as String?;
            if (id != null) variantMap[id] = Map<String, dynamic>.from(v);
          }
        } catch (e) {
          debugPrint('[fetchOrderItems] variants fetch error: $e');
        }
      }

      // ── 5. Fetch attributes ────────────────────────────────────────────
      // variant_attribute_values → attribute_values → attributes (3-level)
      final Map<String, String> variantAttrsText = {};
      if (variantIds.isNotEmpty) {
        try {
          final vavResp = await _supabase
              .from('variant_attribute_values')
              .select('variant_id, attribute_value_id')
              .inFilter('variant_id', variantIds);

          final avIds =
              (vavResp as List)
                  .map((v) => v['attribute_value_id'] as String?)
                  .whereType<String>()
                  .toSet()
                  .toList();

          if (avIds.isNotEmpty) {
            final avResp = await _supabase
                .from('attribute_values')
                .select('id, value, attribute_id')
                .inFilter('id', avIds);

            final attrIds =
                (avResp as List)
                    .map((a) => a['attribute_id'] as String?)
                    .whereType<String>()
                    .toSet()
                    .toList();

            final Map<String, String> attrNames = {};
            if (attrIds.isNotEmpty) {
              final attrResp = await _supabase
                  .from('attributes')
                  .select('id, name')
                  .inFilter('id', attrIds);
              for (final a in attrResp as List) {
                attrNames[a['id'] as String] = a['name'] as String? ?? '';
              }
            }

            // Build avId -> "attrName: value"
            final Map<String, String> avLabels = {};
            for (final av in avResp) {
              final avId = av['id'] as String?;
              final attrId = av['attribute_id'] as String?;
              final val = av['value'] as String? ?? '';
              final attrName = attrId != null ? (attrNames[attrId] ?? '') : '';
              if (avId != null) {
                avLabels[avId] = attrName.isNotEmpty ? '$attrName: $val' : val;
              }
            }

            // variantId -> "Color: Rojo · Talla: M"
            for (final vav in vavResp) {
              final vId = vav['variant_id'] as String?;
              final avId = vav['attribute_value_id'] as String?;
              if (vId != null && avId != null && avLabels.containsKey(avId)) {
                final existing = variantAttrsText[vId];
                variantAttrsText[vId] =
                    existing == null
                        ? avLabels[avId]!
                        : '$existing · ${avLabels[avId]}';
              }
            }
          }
        } catch (e) {
          debugPrint('[fetchOrderItems] attributes fetch error: $e');
        }
      }

      // ── 6. Fetch images ────────────────────────────────────────────────
      final Map<String, String> imageMap = {};
      if (productIds.isNotEmpty) {
        try {
          final imgResp = await _supabase
              .from('product_images')
              .select('product_id, variant_id, image_url, is_main')
              .inFilter('product_id', productIds);
          for (final img in imgResp as List) {
            final pId = img['product_id'] as String?;
            final vId = img['variant_id'] as String?;
            final url = img['image_url'] as String?;
            final isMain = img['is_main'] as bool? ?? false;
            if (pId != null && url != null) {
              if (vId != null && vId.isNotEmpty) {
                if (!imageMap.containsKey('$pId:$vId') || isMain) {
                  imageMap['$pId:$vId'] = url;
                }
              }
              if (!imageMap.containsKey(pId) || isMain) {
                imageMap[pId] = url;
              }
            }
          }
        } catch (e) {
          debugPrint('[fetchOrderItems] images fetch error: $e');
        }
      }

      // ── 7. Build result ────────────────────────────────────────────────
      final list =
          rows.map((r) {
            final productId = r['product_id'] as String? ?? '';
            final variantId = r['variant_id'] as String? ?? '';
            final prod = productMap[productId];
            final variant = variantMap[variantId];

            final attrsText =
                variantAttrsText[variantId]?.isNotEmpty == true
                    ? variantAttrsText[variantId]!
                    : 'Única';

            final imageUrl =
                imageMap['$productId:$variantId'] ?? imageMap[productId];

            return PurchaseOrderItemModel(
              productId: productId,
              variantId: variantId,
              productName: prod?['name'] as String? ?? 'Producto',
              variantAttrs: attrsText,
              sku: variant?['sku'] as String?,
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
              usesBatches: prod?['uses_batches'] as bool? ?? false,
              imageUrl: imageUrl,
            );
          }).toList();
      return Right(list);
    } catch (e, st) {
      debugPrint('[fetchOrderItems] fatal error: $e\n$st');
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

        try {
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
        } catch (rpcError) {
          debugPrint('cancel_purchase_order_rpc error/missing: $rpcError');
          // Fallback directo si la RPC aún no se ejecutó en el SQL Editor de Supabase
          await _supabase
              .from('purchase_orders')
              .update({
                'status': 'CANCELLED',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', poId);
          return const Right(null);
        }
      }

      await _supabase
          .from('purchase_orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', poId);
      return const Right(null);
    } catch (e) {
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
            return {
              'product_id': item.productId,
              'variant_id': item.variantId,
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
      return Left(ServerFailure(message: 'El servidor rechazó la creación de la orden (respuesta no confirmada).'));
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] createPurchaseOrder PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] createPurchaseOrder unexpected error: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
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
      bool allFullyReceived = true;
      for (final pItem in receivedItems) {
        final toReceive = (pItem['receiveQty'] as num).toDouble();
        if (toReceive <= 0) {
          if (!pItem['fullyReceived']) allFullyReceived = false;
          continue;
        }

        final prevReceived = (pItem['quantity_received'] as num).toDouble();
        final ordered = (pItem['quantity_ordered'] as num).toDouble();
        final newReceived = prevReceived + toReceive;

        if (newReceived < ordered) {
          allFullyReceived = false;
        }

        await _supabase
            .from('purchase_order_items')
            .update({'quantity_received': newReceived})
            .eq('purchase_order_id', poId)
            .eq('product_id', pItem['product_id'])
            .eq('variant_id', pItem['variant_id']);

        if (pItem['uses_batches'] == true) {
          final existingBatch =
              await _supabase
                  .from('inventory_batches')
                  .select('id, quantity')
                  .eq('product_id', pItem['product_id'])
                  .eq('variant_id', pItem['variant_id'])
                  .eq('warehouse_id', warehouseId)
                  .eq('batch_number', pItem['batch_number'])
                  .maybeSingle();

          if (existingBatch != null) {
            await _supabase
                .from('inventory_batches')
                .update({
                  'quantity':
                      (existingBatch['quantity'] as num).toDouble() + toReceive,
                })
                .eq('id', existingBatch['id']);
          } else {
            await _supabase.from('inventory_batches').insert({
              'product_id': pItem['product_id'],
              'variant_id': pItem['variant_id'],
              'warehouse_id': warehouseId,
              'batch_number': pItem['batch_number'],
              'quantity': toReceive,
              if (pItem['expiry_date'] != null)
                'expiry_date': pItem['expiry_date'],
            });
          }
        }

        final invStock =
            await _supabase
                .from('inventory_stock')
                .select('id, quantity')
                .eq('product_id', pItem['product_id'])
                .eq('variant_id', pItem['variant_id'])
                .eq('warehouse_id', warehouseId)
                .maybeSingle();

        if (invStock != null) {
          await _supabase
              .from('inventory_stock')
              .update({
                'quantity':
                    (invStock['quantity'] as num).toDouble() + toReceive,
              })
              .eq('id', invStock['id']);
        } else {
          await _supabase.from('inventory_stock').insert({
            'product_id': pItem['product_id'],
            'variant_id': pItem['variant_id'],
            'warehouse_id': warehouseId,
            'quantity': toReceive,
          });
        }
      }

      await _supabase
          .from('purchase_orders')
          .update({
            'status': allFullyReceived ? 'RECEIVED' : 'PARTIAL',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', poId);

      return const Right(null);
    } catch (e) {
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
          'p_notes': 'Pago de Orden de Compra #${orderId.substring(0, 8).toUpperCase()}',
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
      debugPrint('[PurchaseOrdersRepositoryImpl] registerOrderPayment error: $e\n$st');
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      debugPrint('[PurchaseOrdersRepositoryImpl] registerOrderPayment unexpected: $e\n$st');
      return Left(ServerFailure(message: 'Error inesperado al registrar el pago: $e'));
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
      debugPrint('[PurchaseOrdersRepositoryImpl] updateOrderPaymentMethod error: $e\n$st');
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      debugPrint('[PurchaseOrdersRepositoryImpl] updateOrderPaymentMethod unexpected: $e\n$st');
      return Left(ServerFailure(message: 'Error inesperado al cambiar método de pago: $e'));
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
      return Left(ServerFailure(message: 'Error al cargar catálogos: ${e.message}'));
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getFormCatalogs unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error inesperado al cargar catálogos: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getSupplierCredit(
    String supplierId,
  ) async {
    try {
      final creditRes = await _supabase
          .from('supplier_credits')
          .select('id, supplier_id, current_debt, credit_limit, is_active')
          .eq('supplier_id', supplierId)
          .maybeSingle();
      return Right(creditRes != null ? Map<String, dynamic>.from(creditRes) : null);
    } on PostgrestException catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getSupplierCredit PostgrestException: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error al consultar crédito: ${e.message}'));
    } catch (e, st) {
      developer.log(
        '[PurchaseOrdersRepositoryImpl] getSupplierCredit unexpected: $e',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrdersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error inesperado al consultar crédito: $e'));
    }
  }
}

