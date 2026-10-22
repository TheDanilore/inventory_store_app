import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo de resultado de escaneo con el producto y la variante resuelta (si aplica)
class PosScanResult {
  final ProductEntity product;
  final ProductVariantEntity? variant;
  final String rawCode;

  const PosScanResult({
    required this.product,
    this.variant,
    required this.rawCode,
  });
}

/// Servicio integral para resolver códigos de barra, QR y SKU en el Punto de Venta.
class PosBarcodeScannerService {
  /// Analiza y busca en la base de datos el producto y variante correspondiente al código escaneado.
  ///
  /// Admite:
  /// 1. Formato QR App: `https://inventory-store-app-six.vercel.app/product/:id?variantId=:vId`
  /// 2. Búsqueda por `barcode` en `product_variants`
  /// 3. Búsqueda por `sku` en `product_variants`
  /// 4. Búsqueda por `id` de variante o `id` de producto (UUID)
  static Future<PosScanResult?> resolveCode(
    String rawCode, {
    String? warehouseId,
  }) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return null;

    final repo = sl<ProductsRepository>();
    final supabase = Supabase.instance.client;

    try {
      // 1. Caso QR con URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          // Extraer productId de path: /product/:id o /inventory/:id
          final segments = uri.pathSegments;
          String? productId;
          final prodIndex = segments.indexOf('product');
          if (prodIndex != -1 && prodIndex + 1 < segments.length) {
            productId = segments[prodIndex + 1];
          }

          final variantId = uri.queryParameters['variantId'];

          if (productId != null && productId.isNotEmpty) {
            final prodRes = await repo.getProductById(productId);
            final product = prodRes.fold((l) => null, (r) => r);
            if (product != null) {
              ProductVariantEntity? targetVariant;
              if (variantId != null && variantId.isNotEmpty) {
                targetVariant = product.productVariants
                    .cast<ProductVariantEntity?>()
                    .firstWhere((v) => v?.id == variantId, orElse: () => null);
              }
              return PosScanResult(
                product: product,
                variant: targetVariant ?? product.defaultVariant,
                rawCode: trimmed,
              );
            }
          }
        }
      }

      // 2. Buscar en Supabase por barcode exacto en product_variants
      final variantByBarcodeRes =
          await supabase
              .from('product_variants')
              .select('id, product_id, sku, barcode, is_active')
              .eq('barcode', trimmed)
              .maybeSingle();

      if (variantByBarcodeRes != null) {
        final prodId = variantByBarcodeRes['product_id'] as String;
        final vId = variantByBarcodeRes['id'] as String;
        final prodRes = await repo.getProductById(prodId);
        final product = prodRes.fold((l) => null, (r) => r);
        if (product != null) {
          final variant = product.productVariants
              .cast<ProductVariantEntity?>()
              .firstWhere((v) => v?.id == vId, orElse: () => null);
          return PosScanResult(
            product: product,
            variant: variant ?? product.defaultVariant,
            rawCode: trimmed,
          );
        }
      }

      // 3. Buscar en Supabase por SKU (insensible a mayúsculas/minúsculas) en product_variants
      final variantBySkuRes =
          await supabase
              .from('product_variants')
              .select('id, product_id, sku, barcode, is_active')
              .ilike('sku', trimmed)
              .maybeSingle();

      if (variantBySkuRes != null) {
        final prodId = variantBySkuRes['product_id'] as String;
        final vId = variantBySkuRes['id'] as String;
        final prodRes = await repo.getProductById(prodId);
        final product = prodRes.fold((l) => null, (r) => r);
        if (product != null) {
          final variant = product.productVariants
              .cast<ProductVariantEntity?>()
              .firstWhere((v) => v?.id == vId, orElse: () => null);
          return PosScanResult(
            product: product,
            variant: variant ?? product.defaultVariant,
            rawCode: trimmed,
          );
        }
      }

      // 4. Si el código parece UUID, intentar buscar directamente por variant ID o product ID
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (uuidRegex.hasMatch(trimmed)) {
        // Intentar producto
        final prodRes = await repo.getProductById(trimmed);
        final product = prodRes.fold((l) => null, (r) => r);
        if (product != null) {
          return PosScanResult(
            product: product,
            variant: product.defaultVariant,
            rawCode: trimmed,
          );
        }

        // Intentar variante
        final variantRow =
            await supabase
                .from('product_variants')
                .select('product_id')
                .eq('id', trimmed)
                .maybeSingle();
        if (variantRow != null) {
          final parentId = variantRow['product_id'] as String;
          final pRes = await repo.getProductById(parentId);
          final p = pRes.fold((l) => null, (r) => r);
          if (p != null) {
            final v = p.productVariants
                .cast<ProductVariantEntity?>()
                .firstWhere((item) => item?.id == trimmed, orElse: () => null);
            return PosScanResult(
              product: p,
              variant: v ?? p.defaultVariant,
              rawCode: trimmed,
            );
          }
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Error resolviendo código de barras/QR: $rawCode',
        tag: 'PosBarcodeScannerService',
        error: e,
        stackTrace: st,
      );
    }

    return null;
  }

  /// Añade el resultado al carrito del POS de forma inteligente:
  /// - Si la variante está resuelta o el producto tiene 1 sola variante -> se agrega directamente al carrito.
  /// - Si el producto tiene múltiples variantes y no se pudo determinar cuál es -> abre [PosAddToCartSheet].
  ///
  /// Retorna `true` si el producto se agregó exitosamente (o abrió selector), o `false` si falló (ej: agotado).
  static Future<bool> addScanResultToCart({
    required BuildContext context,
    required PosScanResult scanResult,
    required CartCubit cartCubit,
    String? warehouseId,
  }) async {
    final product = scanResult.product;
    final variant = scanResult.variant;

    // Caso 1: Variante resuelta explícitamente (o producto con 1 sola variante)
    if (variant != null || product.productVariants.length <= 1) {
      final targetVariant = variant ?? product.defaultVariant;

      // Calcular stock disponible real para la variante y/o almacén seleccionado
      int availableStock = product.totalStock;
      if (product.warehouseStockBatches.isNotEmpty) {
        if (targetVariant != null) {
          final batches = product.warehouseStockBatches.where((b) {
            final matchVariant = b.variantId == targetVariant.id;
            final matchWh =
                warehouseId == null ||
                warehouseId.isEmpty ||
                b.warehouseId == warehouseId;
            return matchVariant && matchWh;
          });
          availableStock = batches.fold<int>(
            0,
            (sum, b) => sum + b.availableQuantity.toInt(),
          );
        } else if (warehouseId != null && warehouseId.isNotEmpty) {
          final batches = product.warehouseStockBatches.where(
            (b) => b.warehouseId == warehouseId,
          );
          availableStock = batches.fold<int>(
            0,
            (sum, b) => sum + b.availableQuantity.toInt(),
          );
        }
      }

      // Verificar control de stock si aplica
      if (product.stockControl && availableStock <= 0) {
        final variantText =
            targetVariant != null && targetVariant.shortLabel.isNotEmpty
                ? ' (${targetVariant.shortLabel})'
                : '';
        AppSnackbar.show(
          context,
          message: '${product.name}$variantText está agotado.',
          type: SnackbarType.warning,
        );
        return false;
      }

      final unitPrice =
          targetVariant?.salePrice ?? product.displaySalePrice ?? 0.0;
      if (unitPrice <= 0) {
        AppSnackbar.show(
          context,
          message: '${product.name} no tiene precio de venta asignado.',
          type: SnackbarType.warning,
        );
        return false;
      }

      final cartKey = targetVariant?.id ?? product.id;
      final cartItem = CartItemEntity(
        productId: product.id,
        productName: product.name,
        cartKey: cartKey,
        variantId: targetVariant?.id,
        variantLabel: targetVariant?.label,
        quantity: 1,
        unitPrice: unitPrice,
        unitCost:
            targetVariant?.unitCost ?? product.defaultVariant?.unitCost ?? 0.0,
        availableStock:
            product.stockControl
                ? availableStock
                : CartItemEntity.unlimitedStock,
        usesBatches: product.usesBatches,
        wholesalePrice: targetVariant?.wholesalePrice,
        sku: targetVariant?.sku ?? product.defaultVariant?.sku,
        imageUrl:
            targetVariant?.images.isNotEmpty == true
                ? targetVariant!.images.first.imageUrl
                : product.primaryImageUrl,
        isSelected: true,
      );

      cartCubit.addItem(cartItem);
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);

      AppSnackbar.show(
        context,
        message: 'Agregado: ${product.name} ${targetVariant?.shortLabel ?? ''}',
        type: SnackbarType.success,
      );
      return true;
    }

    // Caso 2: Múltiples variantes sin variante resuelta -> abrir selector modal
    await PosAddToCartSheet.show(
      context,
      product,
      warehouseId: warehouseId,
      initialVariantId: variant?.id,
    );
    return true;
  }

  /// Despliega la cámara de escaneo y procesa automáticamente el resultado en el carrito en modo continuo.
  static Future<void> openCameraScanner({
    required BuildContext context,
    required CartCubit cartCubit,
    String? warehouseId,
  }) async {
    await PosCameraScannerDialog.show(
      context,
      warehouseId: warehouseId,
      title: 'POS: Escaneo Rápido de Productos',
      continuousMode: true,
      onContinuousScan: (scanResult) async {
        if (!context.mounted) return false;
        return await addScanResultToCart(
          context: context,
          scanResult: scanResult,
          cartCubit: cartCubit,
          warehouseId: warehouseId,
        );
      },
    );
  }
}
