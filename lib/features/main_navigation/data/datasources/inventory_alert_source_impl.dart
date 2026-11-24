import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fuente remota de alertas de inventario optimizada para minimizar Egress en Supabase.
///
/// Aplica filtros SQL sobre `stock_control` y ventana temporal de vencimiento
/// (`[-60d, +30d]`), límites explícitos de filas, timeout y mapeo de errores
/// tipados sin ocultar excepciones.
@LazySingleton(as: InventoryAlertSource)
class InventoryAlertSourceImpl implements InventoryAlertSource {
  static const String _tag = 'InventoryAlertSource';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _variantsLimit = 500;
  static const int _lotsLimit = 200;

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
            warehouse_stock_batches(id, expiry_date, available_quantity)
          ''')
          .eq('is_active', true)
          .eq('products.is_active', true)
          .eq('products.stock_control', true)
          .limit(_variantsLimit)
          .timeout(_requestTimeout);

      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(days: 180));
      final snapshots = <StockVariantSnapshot>[];

      for (final raw in (response as List)) {
        final row = raw as Map<String, dynamic>;
        final prod = row['products'] as Map<String, dynamic>? ?? const {};

        final variantId = row['id'] as String? ?? '';
        if (variantId.isEmpty) continue;
        final productName = prod['name'] as String? ?? 'Producto';

        final attrValuesList =
            row['variant_attribute_values'] as List? ?? const [];
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

        final batches = row['warehouse_stock_batches'] as List? ?? const [];
        var totalStock = 0;
        var recentExpiredCount = 0;

        for (final b in batches) {
          final bMap = b as Map<String, dynamic>;
          final qty = (bMap['available_quantity'] as num?)?.toInt() ?? 0;
          totalStock += qty;

          final expStr = bMap['expiry_date'] as String?;
          if (qty > 0 && expStr != null) {
            final exp = DateTime.tryParse(expStr);
            if (exp != null && exp.isBefore(now) && exp.isAfter(windowStart)) {
              recentExpiredCount++;
            }
          }
        }

        snapshots.add(
          StockVariantSnapshot(
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            totalStock: totalStock,
            reorderPoint: row['reorder_point'] as int?,
            isActive: row['is_active'] as bool? ?? true,
            recentExpiredLotCount: recentExpiredCount,
          ),
        );
      }

      return snapshots;
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest en fetchVariants: ${e.message}',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw ServerException(message: e.message, originalError: e);
    } on TimeoutException catch (e, st) {
      LoggerService.w(
        'Timeout en fetchVariants',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } on SocketException catch (e, st) {
      LoggerService.w(
        'Error de socket en fetchVariants',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } on http.ClientException catch (e, st) {
      LoggerService.w(
        'Error HTTP en fetchVariants',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en fetchVariants',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  @override
  Future<List<LotSnapshot>> fetchLots() async {
    try {
      final now = DateTime.now();
      final minDateIso = _toIsoDate(now.subtract(const Duration(days: 60)));
      final maxDateIso = _toIsoDate(now.add(const Duration(days: 30)));

      final response = await _supabase
          .from('warehouse_stock_batches')
          .select('''
            id, batch_number, expiry_date, available_quantity, variant_id,
            products!inner(id, name, uses_batches, is_active),
            product_variants!inner(id, sku, is_active, variant_attribute_values(attribute_values(value)))
          ''')
          .gt('available_quantity', 0)
          .not('expiry_date', 'is', null)
          .gte('expiry_date', minDateIso)
          .lte('expiry_date', maxDateIso)
          .eq('products.is_active', true)
          .eq('product_variants.is_active', true)
          .order('expiry_date', ascending: true)
          .limit(_lotsLimit)
          .timeout(_requestTimeout);

      final snapshots = <LotSnapshot>[];

      for (final raw in (response as List)) {
        final row = raw as Map<String, dynamic>;
        final prod = row['products'] as Map<String, dynamic>? ?? const {};
        final variant =
            row['product_variants'] as Map<String, dynamic>? ?? const {};

        final lotId = row['id'] as String? ?? '';
        final variantId = row['variant_id'] as String? ?? '';
        if (lotId.isEmpty || variantId.isEmpty) continue;

        final productName = prod['name'] as String? ?? 'Producto';
        final attrValuesList =
            variant['variant_attribute_values'] as List? ?? const [];
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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest en fetchLots: ${e.message}',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw ServerException(message: e.message, originalError: e);
    } on TimeoutException catch (e, st) {
      LoggerService.w(
        'Timeout en fetchLots',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } on SocketException catch (e, st) {
      LoggerService.w(
        'Error de socket en fetchLots',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } on http.ClientException catch (e, st) {
      LoggerService.w(
        'Error HTTP en fetchLots',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw NetworkException(originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en fetchLots',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  static String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
