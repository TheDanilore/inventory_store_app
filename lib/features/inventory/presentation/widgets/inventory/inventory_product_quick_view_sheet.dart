import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_uc.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

class InventoryProductQuickViewSheet {
  /// Abre la Ficha Rápida:
  /// - En Desktop (>= 900px): Slide-Over Panel lateral de 480px estilo Linear / Stripe.
  /// - En Móvil (< 900px): Modal Bottom Sheet estilo Apple HIG con drag handle.
  static Future<void> show(
    BuildContext context, {
    required InventoryStockItem item,
    String? selectedWarehouseId,
    String? selectedWarehouseName,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'QuickViewInventory',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 500,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 36,
                      offset: const Offset(-10, 0),
                    ),
                  ],
                ),
                child: _InventoryProductQuickViewContent(
                  item: item,
                  selectedWarehouseId: selectedWarehouseId,
                  selectedWarehouseName: selectedWarehouseName,
                  isSideSheet: true,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _InventoryProductQuickViewContent(
            item: item,
            selectedWarehouseId: selectedWarehouseId,
            selectedWarehouseName: selectedWarehouseName,
            isSideSheet: false,
          ),
        );
      },
    );
  }
}

class _InventoryProductQuickViewContent extends StatefulWidget {
  final InventoryStockItem item;
  final String? selectedWarehouseId;
  final String? selectedWarehouseName;
  final bool isSideSheet;

  const _InventoryProductQuickViewContent({
    required this.item,
    this.selectedWarehouseId,
    this.selectedWarehouseName,
    required this.isSideSheet,
  });

  @override
  State<_InventoryProductQuickViewContent> createState() =>
      _InventoryProductQuickViewContentState();
}

class _InventoryProductQuickViewContentState
    extends State<_InventoryProductQuickViewContent> {
  ProductEntity? _fullProduct;
  bool _isLoadingProduct = true;
  String? _errorMessage;
  late String _activeVariantId;

  @override
  void initState() {
    super.initState();
    _activeVariantId = widget.item.variantId;
    _loadFullProduct();
  }

  Future<void> _loadFullProduct() async {
    try {
      final getProductUc = sl<GetProductByIdUC>();
      final result = await getProductUc(widget.item.productId);
      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _isLoadingProduct = false;
              _errorMessage = failure.message;
            });
          }
        },
        (product) {
          if (mounted) {
            setState(() {
              _fullProduct = product;
              _isLoadingProduct = false;
              if (product != null) {
                final exists = product.productVariants.any(
                  (v) => v.id == _activeVariantId,
                );
                if (!exists && product.productVariants.isNotEmpty) {
                  _activeVariantId = product.productVariants.first.id;
                }
              }
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
          _errorMessage = e.toString();
        });
      }
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
      if (v.sku?.isNotEmpty == true) return v.sku!;
    }
    return widget.item.attrsText.isNotEmpty
        ? widget.item.attrsText
        : 'Variante Estándar';
  }

  String? get _activeVariantSku {
    return _activeVariant?.sku ?? widget.item.sku;
  }

  double get _activeVariantSalePrice {
    return _activeVariant?.salePrice ?? widget.item.salePrice;
  }

  double get _activeVariantUnitCost {
    return _activeVariant?.unitCost ?? widget.item.unitCost;
  }

  double get _activeVariantProfit =>
      _activeVariantSalePrice - _activeVariantUnitCost;

  double get _activeVariantMargin =>
      _activeVariantUnitCost > 0
          ? (_activeVariantProfit / _activeVariantSalePrice) * 100
          : 0;

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

    final isSingleVariant = variants.length <= 1 && !_isLoadingProduct;

    return Column(
      children: [
        // ── Apple Drag Handle en móvil ──
        if (!widget.isSideSheet)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

        // ── Cabecera Superior: Ficha Rápida con Enfoque de Variante ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _activeVariantTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (variants.length > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
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
                        ],
                      ],
                    ),
                    Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar (Esc)',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ── Barra de Variantes Hermanas (Horizontal Chips - Linear/Superhuman Style) ──
        if (!_isLoadingProduct && variants.length > 1)
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              itemCount: variants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final v = variants[idx];
                final isSelected = v.id == _activeVariantId;
                final vStock = _calculateVariantStockFor(v.id);
                final vTitle =
                    v.attributeValues.isNotEmpty
                        ? v.label
                        : (v.sku?.isNotEmpty == true
                            ? v.sku!
                            : 'Var. #${idx + 1}');

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeVariantId = v.id);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : (vStock <= 0
                                        ? AppColors.danger.withValues(
                                          alpha: 0.1,
                                        )
                                        : AppColors.teal.withValues(
                                          alpha: 0.1,
                                        )),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$vStock',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : (vStock <= 0
                                          ? AppColors.danger
                                          : AppColors.tealDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // ── Cuerpo con Scroll ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                      ],
                    ),
                  ),

                // ── Hero de la Variante Activa ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Imagen
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          primaryImg != null && primaryImg.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: primaryImg,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder:
                                    (ctx, url) => Container(
                                      width: 72,
                                      height: 72,
                                      color: AppColors.background,
                                    ),
                                errorWidget:
                                    (ctx, url, err) =>
                                        _buildMonogram(_activeVariantTitle, 72),
                              )
                              : _buildMonogram(_activeVariantTitle, 72),
                    ),
                    const SizedBox(width: 14),

                    // Título de Variante, SKU y Disponibilidad
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeVariantTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Badge de Disponibilidad WCAG AAA
                              _buildSemanticAvailabilityBadge(
                                currentStock,
                                isLowStock,
                              ),

                              // SKU Chip interactivo
                              if (_activeVariantSku != null &&
                                  _activeVariantSku!.isNotEmpty)
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _activeVariantSku!),
                                    );
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'SKU copiado al portapapeles',
                                        ),
                                        duration: Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.copy_rounded,
                                          size: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _activeVariantSku!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'monospace',
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Categoría Pill
                              if (item.category.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.07,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (activeIngredient != null &&
                    activeIngredient.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Principio Activo: $activeIngredient',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── Matriz de Métricas de la Variante (Stock, Precios, Margen) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Stock Disponible en Almacén
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.selectedWarehouseId != null
                                          ? 'Stock Almacén'
                                          : 'Stock Total',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$currentStock uds.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        currentStock <= 0
                                            ? AppColors.danger
                                            : (isLowStock
                                                ? AppColors.warningDark
                                                : AppColors.tealDark),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: 14),

                          // Precio Venta
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Precio Venta',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'S/ ${_activeVariantSalePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: 14),

                          // Costo Unitario
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Costo Ref.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'S/ ${_activeVariantUnitCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 10),
                      // Fila inferior de métricas: Margen y Punto de Reorden
                      Row(
                        children: [
                          // Margen Comercial
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Margen: ${_activeVariantMargin.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      _activeVariantMargin >= 30
                                          ? AppColors.tealDark
                                          : (_activeVariantMargin >= 15
                                              ? AppColors.warningDark
                                              : AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Punto de Reorden
                          Row(
                            children: [
                              const Icon(
                                Icons.flag_outlined,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Pto. reorden: ${item.reorderPoint} uds.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Lotes de la Variante Activa (si usa lotes) ──
                if (item.usesBatches) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.batch_prediction_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Lotes de esta variante',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (_activeVariantId == item.variantId)
                        Text(
                          '${item.batches.length} lote${item.batches.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_activeVariantId == item.variantId &&
                      item.batches.isNotEmpty)
                    Column(
                      children:
                          item.batches.map((batch) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildBatchRow(batch),
                            );
                          }).toList(),
                    )
                  else if (_activeVariantStock <= 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sin lotes activos en el almacén seleccionado',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: AppColors.tealDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lotes registrados en sistema ($_activeVariantStock uds. disponibles)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],

                // ── Lista de Todas las Variantes del Producto (si hay más de 1) ──
                if (!isSingleVariant) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.list_alt_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isLoadingProduct
                                ? 'Variantes del producto...'
                                : 'Todas las variantes (${variants.length})',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total prod: $totalProductStock uds.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Lista de Variantes o Shimmer
                  if (_isLoadingProduct)
                    Column(
                      children: List.generate(
                        3,
                        (idx) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                AppShimmer(
                                  width: 8,
                                  height: 8,
                                  borderRadius: 4,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppShimmer(
                                        width: 120,
                                        height: 14,
                                        borderRadius: 4,
                                      ),
                                      SizedBox(height: 4),
                                      AppShimmer(
                                        width: 80,
                                        height: 10,
                                        borderRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                AppShimmer(
                                  width: 60,
                                  height: 16,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: variants.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = variants[index];
                        final isSelected = v.id == _activeVariantId;
                        final vStock = _calculateVariantStockFor(v.id);
                        final displayTitle =
                            v.attributeValues.isNotEmpty
                                ? v.label
                                : (v.sku?.isNotEmpty == true
                                    ? v.sku!
                                    : (variants.length == 1
                                        ? 'Variante Estándar'
                                        : 'Variante #${index + 1}'));

                        return _VariantRowItem(
                          title: displayTitle,
                          sku: v.sku,
                          salePrice: v.salePrice ?? item.salePrice,
                          unitCost: v.unitCost ?? item.unitCost,
                          stock: vStock,
                          isActive: v.isActive,
                          isSelected: isSelected,
                          onSelect: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeVariantId = v.id);
                          },
                          onOpenKardex: () {
                            Navigator.pop(context);
                            context.push(
                              '/admin/kardex?productId=${item.productId}&variantId=${v.id}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(displayTitle)}',
                            );
                          },
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),

        // ── Footer con Acciones Clave para la Variante Activa ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            children: [
              // Botón Kárdex de la variante activa
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/admin/kardex?productId=${item.productId}&variantId=$_activeVariantId&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(_activeVariantTitle)}',
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text(
                    'Kárdex',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Editar Producto
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/admin/products/product-form/${item.productId}',
                      extra: {'productToEdit': product},
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Editar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Ver Ficha Completa
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/admin/product/${item.productId}?variantId=$_activeVariantId',
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Ficha Completa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchRow(InventoryBatchItem batch) {
    Color badgeColor = AppColors.teal;
    String badgeText = 'Normal';
    if (batch.status == 'vencido') {
      badgeColor = AppColors.danger;
      badgeText = 'Vencido';
    } else if (batch.status == 'critico') {
      badgeColor = AppColors.warning;
      badgeText = 'Crítico (${batch.daysRemaining}d)';
    } else if (batch.status == 'proximo') {
      badgeColor = AppColors.accent;
      badgeText = 'Próximo (${batch.daysRemaining}d)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lote: ${batch.batchNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                ),
                if (batch.warehouseName != null)
                  Text(
                    batch.warehouseName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${batch.availableQuantity} uds.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonogram(String name, double size) {
    final clean = name.trim();
    String initials = 'PR';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials =
            clean.length >= 2
                ? clean.substring(0, 2).toUpperCase()
                : clean[0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSemanticAvailabilityBadge(int stock, bool isLowStock) {
    final isOut = stock <= 0;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData iconData;
    String text;

    if (isOut) {
      bgColor = AppColors.danger.withValues(alpha: 0.08);
      borderColor = AppColors.danger.withValues(alpha: 0.25);
      textColor = AppColors.danger;
      iconData = Icons.highlight_off_rounded;
      text = 'Agotado (0 uds.)';
    } else if (isLowStock) {
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      textColor = AppColors.warningDark;
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo Stock ($stock uds.)';
    } else {
      bgColor = AppColors.teal.withValues(alpha: 0.1);
      borderColor = AppColors.teal.withValues(alpha: 0.25);
      textColor = AppColors.tealDark;
      iconData = Icons.check_circle_outline_rounded;
      text = 'En Stock ($stock uds.)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12.5, color: textColor),
          const SizedBox(width: 4.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantRowItem extends StatelessWidget {
  final String title;
  final String? sku;
  final double salePrice;
  final double unitCost;
  final int stock;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpenKardex;

  const _VariantRowItem({
    required this.title,
    this.sku,
    required this.salePrice,
    required this.unitCost,
    required this.stock,
    required this.isActive,
    required this.isSelected,
    required this.onSelect,
    required this.onOpenKardex,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    Color stockBg;
    Color stockColor;
    String stockLabel;

    if (isOut) {
      stockBg = AppColors.danger.withValues(alpha: 0.08);
      stockColor = AppColors.danger;
      stockLabel = 'Agotado';
    } else if (isLow) {
      stockBg = AppColors.warning.withValues(alpha: 0.1);
      stockColor = AppColors.warningDark;
      stockLabel = '$stock uds.';
    } else {
      stockBg = AppColors.teal.withValues(alpha: 0.1);
      stockColor = AppColors.tealDark;
      stockLabel = '$stock uds.';
    }

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Dot activo / seleccionado
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isActive ? AppColors.success : AppColors.textMuted),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            // Label y SKU
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Activa',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sku != null && sku!.isNotEmpty && title != sku)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'SKU: $sku',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Stock Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: stockBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stockLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: stockColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Precios
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${salePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Costo: S/ ${unitCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 6),
            // Botón directo a Kárdex
            Tooltip(
              message: 'Ver movimientos de esta variante en Kárdex',
              child: IconButton(
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                color: AppColors.textSecondary,
                hoverColor: AppColors.primary.withValues(alpha: 0.08),
                onPressed: onOpenKardex,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
