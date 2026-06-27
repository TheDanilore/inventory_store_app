import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';

class CartCheckoutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchDefaultAddress(String profileId) async {
    return await _supabase
        .from('user_addresses')
        .select('*')
        .eq('profile_id', profileId)
        .eq('is_default', true)
        .maybeSingle();
  }

  Future<String?> getActiveWarehouseId() async {
    final warehouseResp =
        await _supabase
            .from('warehouses')
            .select('id')
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
    return warehouseResp?['id'];
  }

  Future<Map<String, int>> fetchStockForVariants(
    List<String> variantIds,
  ) async {
    if (variantIds.isEmpty) return {};

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

    return stockMap;
  }

  Future<String> processOrder({
    required String? customerId,
    required double totalAmount,
    required int pointsUsed,
    required int pointsEarned,
    required double totalProfit,
    required String warehouseId,
    required List<CartItemModel> itemsToBuy,
  }) async {
    // 1. Crear Orden
    final orderResp =
        await _supabase
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
    final itemsToInsert =
        itemsToBuy.map((item) {
          return {
            'order_id': orderId,
            'product_id': item.product.id,
            'variant_id': item.variantId,
            'quantity': item.quantity,
            'unit_cost': item.unitCost,
            'applied_price': item.unitPrice,
            'net_profit': (item.unitPrice - item.unitCost) * item.quantity,
          };
        }).toList();

    await _supabase.from('order_items').insert(itemsToInsert);

    return orderId;
  }
}
