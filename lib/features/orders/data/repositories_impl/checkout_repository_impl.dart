import 'dart:developer' as developer;
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/checkout_repository.dart';

import 'package:injectable/injectable.dart';

@LazySingleton(as: CheckoutRepository)
class CheckoutRepositoryImpl implements CheckoutRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, Map<String, dynamic>?>> fetchDefaultAddress(
    String profileId,
  ) async {
    try {
      final res =
          await _supabase
              .from('customer_locations')
              .select('id, profile_id, address_line, reference, is_default')
              .eq('profile_id', profileId)
              .eq('is_default', true)
              .maybeSingle();
      return Right(res);
    } catch (e, st) {
      developer.log('Error en fetchDefaultAddress', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error fetching address: $e'));
    }
  }

  Future<Either<Failure, String?>> getActiveWarehouseId() async {
    try {
      final warehouseResp =
          await _supabase
              .from('warehouses')
              .select('id')
              .eq('is_active', true)
              .limit(1)
              .maybeSingle();
      return Right(warehouseResp?['id']);
    } catch (e, st) {
      developer.log('Error fetching warehouse', error: e, stackTrace: st);
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
    } catch (e, st) {
      developer.log('Error en fetchStockForVariants', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error fetching stock: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> processOrder({
    required String? customerId,
    required double totalAmount,
    required int pointsUsed,
    required int pointsEarned,
    required double totalProfit,
    required String? warehouseId,
    required List<CartItemEntity> itemsToBuy,
  }) async {
    try {
      final itemsJson = itemsToBuy.map((item) => {
        'product_id': item.productId,
        'variant_id': item.variantId,
        'quantity': item.quantity,
      }).toList();

      final orderResp = await _supabase.rpc(
        'process_customer_checkout',
        params: {
          'p_customer_id': customerId,
          'p_warehouse_id': warehouseId,
          'p_items': itemsJson,
          'p_use_points': pointsUsed > 0,
        },
      );

      final payload = orderResp as Map<String, dynamic>;
      return Right(payload);
    } catch (e, st) {
      developer.log('Error en processOrder RPC', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error processing order: $e'));
    }
  }
}
