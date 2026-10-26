import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_qr_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/quick_view/quick_view_components.dart';

export 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/quick_view/quick_view_components.dart';

class InventoryProductQuickViewSheet {
  /// Abre la Ficha Rápida:
  /// - En Desktop (>= 900px): Slide-Over Panel lateral estilo Linear / Stripe.
  /// - En Móvil (< 900px): Modal Bottom Sheet estilo Apple HIG con drag handle.
  static Future<void> show(
    BuildContext context, {
    required InventoryStockItem item,
    String? selectedWarehouseId,
    String? selectedWarehouseName,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 520.0,
      breakpoint: 900.0,
      barrierLabel: 'Cerrar detalle de producto',
      builder: (dialogContext) {
        return _InventoryProductQuickViewContent(
          item: item,
          selectedWarehouseId: selectedWarehouseId,
          selectedWarehouseName: selectedWarehouseName,
        );
      },
    );
  }
}

class _InventoryProductQuickViewContent extends StatefulWidget {
  final InventoryStockItem item;
  final String? selectedWarehouseId;
  final String? selectedWarehouseName;

  const _InventoryProductQuickViewContent({
    required this.item,
    this.selectedWarehouseId,
    this.selectedWarehouseName,
  });

  @override
  State<_InventoryProductQuickViewContent> createState() =>
      _InventoryProductQuickViewContentState();
}

class _InventoryProductQuickViewContentState
    extends State<_InventoryProductQuickViewContent> {
  ProductEntity? _fullProduct;
  bool _isLoadingProduct = false;
  String? _errorMessage;
  late String _activeVariantId;

  @override
  void initState() {
    super.initState();
    _activeVariantId = widget.item.variantId;
    _initProductData();
  }

  void _initProductData() {
    // ── POLÍTICA ZERO-SHIMMER: Comprobar caché de sesión en Frame 0 ──────────
    final cached = QuickViewProductCache.instance.get(widget.item.productId);
    if (cached != null) {
      _fullProduct = cached;
      _isLoadingProduct = false;
      _validateActiveVariant(cached);
      // Revalidación silenciosa en background (Stale-While-Revalidate)
      _fetchInBackground(forceRefresh: true);
    } else {
      _isLoadingProduct = true;
      _fetchInBackground(forceRefresh: false);
    }
  }

  void _validateActiveVariant(ProductEntity product) {
    final exists = product.productVariants.any((v) => v.id == _activeVariantId);
    if (!exists && product.productVariants.isNotEmpty) {
      _activeVariantId = product.productVariants.first.id;
    }
  }

  Future<void> _fetchInBackground({required bool forceRefresh}) async {
    final product = await QuickViewProductCache.instance.loadProduct(
      widget.item.productId,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (product != null) {
      setState(() {
        _fullProduct = product;
        _isLoadingProduct = false;
        _errorMessage = null;
        _validateActiveVariant(product);
      });
    } else if (_fullProduct == null) {
      setState(() {
        _isLoadingProduct = false;
        _errorMessage = 'No se pudo conectar con el catálogo central.';
      });
    }
  }

  ProductVariantEntity? get _activeVariant {
    if (_fullProduct == null) return null;
    try {
      return _fullProduct!.productVariants.firstWhere(
        (v) => v.id == _activeVariantId,
      );
    } catch (_) {
      return _fullProduct!.productVariants.isNotEmpty
          ? _fullProduct!.productVariants.first
          : null;
    }
  }

  String get _activeVariantTitle {
    final v = _activeVariant;
    if (v != null) {
      if (v.attributeValues.isNotEmpty) return v.label;
      if (v.sku?.isNotEmpty == true && v.sku != 'N/A') return v.sku!;
    }
    final raw = widget.item.attrsText.trim();
    if (raw.isNotEmpty &&
        raw != 'Única' &&
        raw.toLowerCase() != 'variante estándar' &&
        raw.toLowerCase() != 'estándar') {
      return raw;
    }
    return '';
  }

  String? get _activeVariantSku => _activeVariant?.sku ?? widget.item.sku;
  String? get _activeVariantBarcode =>
      _activeVariant?.barcode ?? widget.item.barcode;
  double get _activeVariantSalePrice =>
      _activeVariant?.salePrice ?? widget.item.salePrice;
  double get _activeVariantUnitCost =>
      _activeVariant?.unitCost ?? widget.item.unitCost;

  int _calculateVariantStockFor(String variantId) {
    if (_fullProduct == null) {
      return variantId == widget.item.variantId ? widget.item.stock : 0;
    }
    final batches = _fullProduct!.warehouseStockBatches.where((b) {
      if (b.variantId != variantId) return false;
      if (widget.selectedWarehouseId != null &&
          widget.selectedWarehouseId!.isNotEmpty) {
        return b.warehouseId == widget.selectedWarehouseId;
      }
      return true;
    });

    if (batches.isEmpty) {
      return variantId == widget.item.variantId ? widget.item.stock : 0;
    }

    return batches
        .fold<double>(0, (sum, b) => sum + b.availableQuantity)
        .toInt();
  }

  int get _activeVariantStock => _calculateVariantStockFor(_activeVariantId);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final product = _fullProduct;
    final variants = product?.productVariants ?? [];
    final warehouseLabel =
        widget.selectedWarehouseName?.isNotEmpty == true
            ? widget.selectedWarehouseName!
            : 'Todos los almacenes';

    final primaryImg = item.imageUrl ?? product?.primaryImageUrl;
    final activeIngredient =
        (product?.details['active_ingredient'] ??
                product?.details['active_ingredients'] ??
                product?.details['principio_activo'] ??
                product?.details['formula'])
            ?.toString();

    final currentStock = _activeVariantStock;
    final isLowStock = currentStock <= item.reorderPoint;
    final totalProductStock =
        product != null
            ? product.productVariants.fold<int>(
              0,
              (sum, v) => sum + _calculateVariantStockFor(v.id),
            )
            : item.stock;

    return DetailSheetFrame(
      title: item.productName,
      fillMobileHeight: true,
      bodyPadding: const EdgeInsets.all(20),
      bodyBackgroundColor: AppColors.surface,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          Icons.style_outlined,
          size: 18,
          color: AppColors.primary,
        ),
      ),
      subtitle: Row(
        children: [
          if (variants.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${variants.length} var.',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              _activeVariantTitle.isNotEmpty &&
                      _activeVariantTitle != item.productName
                  ? (item.category.isNotEmpty
                      ? '$_activeVariantTitle · ${item.category}'
                      : _activeVariantTitle)
                  : item.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      headerActions: [
        // Código QR de la variante activa
        IconButton(
          icon: const Icon(Icons.qr_code_2_rounded, size: 20),
          tooltip: 'Código QR de la variante',
          visualDensity: VisualDensity.compact,
          onPressed:
              () => InventoryQrSheet.show(
                context,
                productId: item.productId,
                variantId: _activeVariantId,
                productName: item.productName,
                variantName: _activeVariantTitle,
                sku: _activeVariantSku,
                barcode: _activeVariantBarcode,
              ),
        ),
        // Badge de Almacén Activo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warehouse_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  warehouseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      headerBottom: QuickViewVariantChipsBar(
        variants: variants,
        activeVariantId: _activeVariantId,
        stockCalculator: _calculateVariantStockFor,
        onVariantSelected: (id) => setState(() => _activeVariantId = id),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrando datos locales de inventario. ($_errorMessage)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    tooltip: 'Reintentar',
                    onPressed: () => _fetchInBackground(forceRefresh: true),
                  ),
                ],
              ),
            ),

          // ── Hero de la Variante Activa ──
          QuickViewHeroHeader(
            productName: item.productName,
            activeVariantTitle: _activeVariantTitle,
            imageUrl: primaryImg,
            sku: _activeVariantSku,
            barcode: _activeVariantBarcode,
            category: item.category,
            activeIngredient: activeIngredient,
            currentStock: currentStock,
            isLowStock: isLowStock,
          ),

          const SizedBox(height: 18),

          // ── Matriz de Métricas (Stock, Precios, Margen) ──
          QuickViewMetricsMatrix(
            currentStock: currentStock,
            isLowStock: isLowStock,
            isWarehouseFiltered: widget.selectedWarehouseId != null,
            salePrice: _activeVariantSalePrice,
            unitCost: _activeVariantUnitCost,
            reorderPoint: item.reorderPoint,
          ),

          const SizedBox(height: 12),

          // ── Acciones Operativas de Stock (Ingreso / Salida) ──
          QuickViewStockActionButtons(
            onStockEntry: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push(
                '/inventory-entries/form',
                extra: {
                  'prefillWarehouseId': widget.selectedWarehouseId,
                  'prefillItems': [
                    InventoryEntryItemEntity(
                      productId: item.productId,
                      productName: item.productName,
                      variantId: _activeVariantId,
                      variantLabel: _activeVariantTitle,
                      imageUrl: primaryImg,
                      usesBatches: item.usesBatches,
                      quantity: 1,
                      unitCost: _activeVariantUnitCost,
                      batchNumber: item.usesBatches ? '' : 'DEFAULT',
                    ),
                  ],
                },
              );
            },
            onStockExit: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push(
                '/inventory-exits/form',
                extra: {
                  'warehouseId': widget.selectedWarehouseId,
                  'prefillVariantId': _activeVariantId,
                  'prefillProductId': item.productId,
                  'prefillProductName': item.productName,
                  'prefillVariantName': _activeVariantTitle,
                  'reason': 'AJUSTE',
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Lotes de la Variante Activa ──
          QuickViewBatchesSection(
            usesBatches: item.usesBatches,
            isDefaultVariantSelected: _activeVariantId == item.variantId,
            batches: item.batches,
            activeVariantStock: _activeVariantStock,
          ),

          // ── Tabla Vertical de Todas las Variantes del Producto ──
          QuickViewVariantsTable(
            variants: variants,
            activeVariantId: _activeVariantId,
            isLoading: _isLoadingProduct,
            totalProductStock: totalProductStock,
            defaultProductName: item.productName,
            defaultSalePrice: item.salePrice,
            defaultUnitCost: item.unitCost,
            stockCalculator: _calculateVariantStockFor,
            onVariantSelected: (id) => setState(() => _activeVariantId = id),
            onOpenKardex: (variant, displayTitle) {
              Navigator.pop(context);
              context.push(
                '/kardex?productId=${item.productId}&variantId=${variant.id}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(displayTitle)}',
              );
            },
          ),
        ],
      ),
      footer: QuickViewFooterActions(
        onOpenKardex: () {
          Navigator.pop(context);
          context.push(
            '/kardex?productId=${item.productId}&variantId=$_activeVariantId&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(_activeVariantTitle)}',
          );
        },
        onEditProduct: () {
          Navigator.pop(context);
          context.push(
            '/products/product-form/${item.productId}',
            extra: {'productToEdit': product},
          );
        },
        onOpenFullView: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          router.go('/product/${item.productId}?variantId=$_activeVariantId');
        },
      ),
    );
  }
}
