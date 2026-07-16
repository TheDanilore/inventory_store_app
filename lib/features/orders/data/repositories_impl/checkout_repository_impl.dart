import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/checkout_repository.dart';

import 'package:injectable/injectable.dart';

@LazySingleton(as: CheckoutRepository)
class CheckoutRepositoryImpl implements CheckoutRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, Map<String, dynamic>?>> fetchDefaultAddress(String profileId) async {
    try {
      final res = await _supabase
          .from('customer_locations')
          .select('*')
          .eq('profile_id', profileId)
          .eq('is_default', true)
          .maybeSingle();
      return Right(res);
    } catch (e) {
      return Left(ServerFailure(message: 'Error fetching address: $e'));
    }
  }

  Future<Either<Failure, String?>> getActiveWarehouseId() async {
    try {
      final warehouseResp = await _supabase
          .from('warehouses')
          .select('id')
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      return Right(warehouseResp?['id']);
    } catch (e) {
      return Left(ServerFailure(message: 'Error fetching warehouse: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> fetchStockForVariants(
    List<String> variantIds,
  ) async {
    if (variantIds.isEmpty) return const Right({});

    try {
      final stockResp = await _supabase
          .from('product_stock_summary')
          .select('variant_id, total_stock')
          .inFilter('variant_id', variantIds);

      final Map<String, int> stockMap = {};
      for (final row in stockResp) {
        final vId = row['variant_id'] as String?;
        final qty = (row['total_stock'] as num?)?.toInt() ?? 0;
        if (vId != null) {
          stockMap[vId] = (stockMap[vId] ?? 0) + qty;
        }
      }

      return Right(stockMap);
    } catch (e) {
      return Left(ServerFailure(message: 'Error fetching stock: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> processOrder({
    required String? customerId,
    required double totalAmount,
    required int pointsUsed,
    required int pointsEarned,
    required double totalProfit,
    required String? warehouseId,
    required List<CartItemEntity> itemsToBuy,
  }) async {
    try {
      // 1. Crear Orden
      final orderResp = await _supabase
          .from('orders')
          .insert({
            'customer_id': customerId,
            'created_by': customerId,
            'total_amount': totalAmount,
            'points_used': pointsUsed,
            'points_earned': pointsEarned,
            'total_profit': totalProfit,
            'payment_method': 'POR ACORDAR',
            'status': 'PENDING',
            'payment_status': 'PENDING',
            'warehouse_id': warehouseId,
          })
          .select('id')
          .single();

      final orderId = orderResp['id'];

      // 2. Insertar items
      final itemsToInsert = itemsToBuy.map((item) {
        return {
          'order_id': orderId,
          'product_id': item.productId,
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_cost': item.unitCost,
          'applied_price': item.unitPrice,
          'net_profit': (item.unitPrice - item.unitCost) * item.quantity,
        };
      }).toList();

      await _supabase.from('order_items').insert(itemsToInsert);

      return Right(orderId);
    } catch (e) {
      return Left(ServerFailure(message: 'Error processing order: $e'));
    }
  }
}
