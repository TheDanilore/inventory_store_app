import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: InventoryAlertSource)
class InventoryAlertSourceImpl implements InventoryAlertSource {
  final SupabaseClient _supabase;

  InventoryAlertSourceImpl(this._supabase);

  @override
  Future<List<StockVariantSnapshot>> fetchVariants() async {
    try {
      final response = await _supabase
          .from('product_variants')
          .select('''
        id, reorder_point, is_active, sku,
        products!inner(id, name, stock_control, is_active),
        variant_attribute_values(attribute_values(value)),
        warehouse_stock_batches(id, batch_number, expiry_date, available_quantity)
      ''')
          .eq('is_active', true)
          .eq('products.is_active', true);

      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(days: 180));
      final List<StockVariantSnapshot> snapshots = [];

      for (final raw in (response as List)) {
        final row = raw as Map<String, dynamic>;
        final prod = row['products'] as Map<String, dynamic>? ?? {};

        // Si el producto no controla inventario (servicios, intangibles), se ignora
        final stockControl = prod['stock_control'] as bool? ?? true;
        if (!stockControl) continue;

        final variantId = row['id'] as String;
        final productName = prod['name'] as String? ?? 'Producto';

        // Atributos de la variante (ej. Talla: M / Color: Azul)
        final attrValuesList = row['variant_attribute_values'] as List? ?? [];
        final attrs = <String>[];
        for (final av in attrValuesList) {
          final val = (av as Map)['attribute_values']?['value'] as String?;
          if (val != null && val.trim().isNotEmpty) {
            attrs.add(val.trim());
          }
        }
        final attrsText = attrs.join(' · ');
        final sku = row['sku'] as String?;
        final variantName = attrsText.isNotEmpty ? attrsText : sku;

        final batches = row['warehouse_stock_batches'] as List? ?? [];
        int totalStock = 0;
        int recentExpiredCount = 0;

        for (final b in batches) {
          final bMap = b as Map<String, dynamic>;
          final qty = (bMap['available_quantity'] as num?)?.toInt() ?? 0;
          totalStock += qty;

          final expStr = bMap['expiry_date'] as String?;
          if (expStr != null) {
            final exp = DateTime.tryParse(expStr);
            if (exp != null) {
              if (exp.isBefore(now) && exp.isAfter(windowStart)) {
                recentExpiredCount++;
              }
            }
          }
        }

        final reorderPoint = row['reorder_point'] as int?;

        snapshots.add(
          StockVariantSnapshot(
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            totalStock: totalStock,
            reorderPoint: reorderPoint,
            isActive: row['is_active'] as bool? ?? true,
            recentExpiredLotCount: recentExpiredCount,
          ),
        );
      }

      return snapshots;
    } catch (e, stack) {
      LoggerService.e(
        'Error fetching variants in InventoryAlertSourceImpl',
        error: e,
        stackTrace: stack,
        tag: 'InventoryAlertSource',
      );
      return [];
    }
  }

  @override
  Future<List<LotSnapshot>> fetchLots() async {
    try {
      final response = await _supabase
          .from('warehouse_stock_batches')
          .select('''
        id, batch_number, expiry_date, available_quantity, variant_id,
        products!inner(id, name, uses_batches, is_active),
        product_variants!inner(id, sku, is_active, variant_attribute_values(attribute_values(value)))
      ''')
          .gt('available_quantity', 0)
          .not('expiry_date', 'is', null)
          .eq('products.is_active', true)
          .eq('product_variants.is_active', true);

      final List<LotSnapshot> snapshots = [];

      for (final raw in (response as List)) {
        final row = raw as Map<String, dynamic>;
        final prod = row['products'] as Map<String, dynamic>? ?? {};
        final variant = row['product_variants'] as Map<String, dynamic>? ?? {};

        final lotId = row['id'] as String;
        final variantId = row['variant_id'] as String;
        final productName = prod['name'] as String? ?? 'Producto';

        final attrValuesList =
            variant['variant_attribute_values'] as List? ?? [];
        final attrs = <String>[];
        for (final av in attrValuesList) {
          final val = (av as Map)['attribute_values']?['value'] as String?;
          if (val != null && val.trim().isNotEmpty) {
            attrs.add(val.trim());
          }
        }
        final attrsText = attrs.join(' · ');
        final sku = variant['sku'] as String?;
        final variantName = attrsText.isNotEmpty ? attrsText : sku;

        final lotCode = row['batch_number'] as String? ?? 'S/L';
        final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
        final expStr = row['expiry_date'] as String?;
        final expiresAt = expStr != null ? DateTime.tryParse(expStr) : null;

        snapshots.add(
          LotSnapshot(
            lotId: lotId,
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            lotCode: lotCode,
            quantity: qty,
            expiresAt: expiresAt,
          ),
        );
      }

      return snapshots;
    } catch (e, stack) {
      LoggerService.e(
        'Error fetching lots in InventoryAlertSourceImpl',
        error: e,
        stackTrace: stack,
        tag: 'InventoryAlertSource',
      );
      return [];
    }
  }
}
