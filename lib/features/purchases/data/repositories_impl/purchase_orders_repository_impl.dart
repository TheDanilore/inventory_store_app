import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_attribute_value_model.dart';

@LazySingleton(as: PurchaseOrdersRepository)
class PurchaseOrdersRepositoryImpl implements PurchaseOrdersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

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
            id, created_at, supplier_id, supplier_name,
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
        final endIso =
            endDate.add(const Duration(days: 1)).toIso8601String();
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
      String poId) async {
    try {
      final response = await _supabase
          .from('purchase_order_items')
          .select('''
            product_id, variant_id,
            quantity_ordered, quantity_received, unit_cost,
            batch_number, expiry_date,
            products!inner(
              name, uses_batches,
              product_images(image_url, is_main, display_order, variant_id)
            ),
            product_variants!inner(
              sku,
              variant_attribute_values(attribute_values(id, value, attributes(id, name))),
              product_images(image_url, is_main, display_order)
            )
          ''')
          .eq('purchase_order_id', poId);

      final list = (response as List).map((r) {
        final prod = r['products'] as Map<String, dynamic>?;
        final variant = r['product_variants'] as Map<String, dynamic>?;
        final variantId = r['variant_id'] as String;

        final List<VariantAttributeValueModel> parsedAttrs = [];
        if (variant != null && variant['variant_attribute_values'] is List) {
          for (final vav in variant['variant_attribute_values'] as List) {
            try {
              parsedAttrs.add(
                VariantAttributeValueModel.fromJson(
                  Map<String, dynamic>.from(vav as Map),
                ),
              );
            } catch (_) {}
          }
        }
        final attrsText =
            parsedAttrs.isNotEmpty
                ? parsedAttrs
                    .map(
                      (a) =>
                          a.attributeName.isNotEmpty
                              ? '${a.attributeName}: ${a.value}'
                              : a.value,
                    )
                    .join(' · ')
                : 'Única';

        String? imageUrl;
        final variantImages = variant?['product_images'] as List?;
        if (variantImages != null && variantImages.isNotEmpty) {
          final main = variantImages.firstWhere(
            (img) => img['is_main'] == true,
            orElse: () => variantImages.first,
          );
          imageUrl = main['image_url'] as String?;
        }

        if (imageUrl == null) {
          final productImages = prod?['product_images'] as List?;
          if (productImages != null && productImages.isNotEmpty) {
            final forVariant =
                productImages
                    .where((img) => img['variant_id'] == variantId)
                    .toList();
            if (forVariant.isNotEmpty) {
              final main = forVariant.firstWhere(
                (img) => img['is_main'] == true,
                orElse: () => forVariant.first,
              );
              imageUrl = main['image_url'] as String?;
            } else {
              final generic =
                  productImages
                      .where((img) => img['variant_id'] == null)
                      .toList();
              final pool = generic.isNotEmpty ? generic : productImages;
              final main = pool.firstWhere(
                (img) => img['is_main'] == true,
                orElse: () => pool.first,
              );
              imageUrl = main['image_url'] as String?;
            }
          }
        }

        return PurchaseOrderItemModel(
          productId: r['product_id'] as String,
          variantId: variantId,
          productName: prod?['name'] as String?,
          variantAttrs: attrsText,
          sku: variant?['sku'] as String?,
          quantityOrdered: (r['quantity_ordered'] as num).toDouble(),
          quantityReceived: (r['quantity_received'] as num?)?.toDouble() ?? 0,
          unitCost: (r['unit_cost'] as num).toDouble(),
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
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderStatus(
      String poId, String status) async {
    try {
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
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', currentUser.id)
                .maybeSingle();
        profileId = profile?['id'] as String?;
      }

      final poResp =
          await _supabase
              .from('purchase_orders')
              .insert({
                'supplier_id': supplierId,
                'supplier_name': supplierName,
                'warehouse_id': warehouseId,
                'status': 'SENT',
                'total_amount': totalAmount,
                'payment_method': paymentMode,
                'payment_status': paymentStatus,
                'amount_paid': paymentStatus == 'PAID' ? totalAmount : 0,
                'due_date': dueDate?.toIso8601String().split('T').first,
                'document_type': documentType,
                'document_number': documentNumber,
                'document_date': documentDate?.toIso8601String().split('T').first,
                'notes': notes,
                'created_by': profileId,
              })
              .select('id')
              .single();

      final poId = poResp['id'] as String;

      for (final item in items) {
        await _supabase.from('purchase_order_items').insert({
          'purchase_order_id': poId,
          'product_id': item.productId,
          'variant_id': item.variantId,
          'quantity_ordered': item.quantity,
          'quantity_received': 0,
          'unit_cost': item.unitCost,
          'batch_number': item.batchNumber,
          'expiry_date': item.expiryDate?.toIso8601String(),
        });
      }

      if (paymentMode == 'CREDITO') {
        final creditData =
            await _supabase
                .from('supplier_credits')
                .select('id, current_debt')
                .eq('supplier_id', supplierId)
                .maybeSingle();

        String? creditId;
        if (creditData != null) {
          creditId = creditData['id'] as String;
          final newDebt = (creditData['current_debt'] as num).toDouble() + totalAmount;
          await _supabase
              .from('supplier_credits')
              .update({'current_debt': newDebt})
              .eq('id', creditId);
        } else {
          final insertCredit =
              await _supabase
                  .from('supplier_credits')
                  .insert({
                    'supplier_id': supplierId,
                    'credit_limit': 0.0,
                    'current_debt': totalAmount,
                    'is_active': true,
                  })
                  .select('id')
                  .single();
          creditId = insertCredit['id'] as String;
        }

        await _supabase.from('supplier_credit_movements').insert({
          'supplier_credit_id': creditId,
          'order_id': poId,
          'movement_type': 'CHARGE',
          'amount': totalAmount,
          'notes': 'Nueva orden de compra generada',
          'created_by': profileId,
        });
      } else if (paymentStatus == 'PAID' && accountId != null) {
        await _supabase.from('account_movements').insert({
          'account_id': accountId,
          if (activeShiftId != null) 'shift_id': activeShiftId,
          'movement_type': 'EXPENSE',
          'amount': totalAmount,
          'description': 'Pago contado de Orden de Compra $documentNumber',
          'reference_type': 'purchase_orders',
          'reference_id': poId,
          'created_by': profileId,
        });

        final accountData =
            await _supabase
                .from('financial_accounts')
                .select('balance')
                .eq('id', accountId)
                .single();
        final currentBalance = (accountData['balance'] as num).toDouble();
        await _supabase
            .from('financial_accounts')
            .update({'balance': currentBalance - totalAmount})
            .eq('id', accountId);
      }
      return const Right(null);
    } catch (e) {
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
                'quantity': (invStock['quantity'] as num).toDouble() + toReceive,
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
}



