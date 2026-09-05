import 'package:flutter/material.dart';
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
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(-8, 0),
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
            maxHeight: MediaQuery.of(context).size.height * 0.88,
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

  @override
  void initState() {
    super.initState();
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

  int _calculateVariantStock(ProductVariantEntity variant) {
    if (_fullProduct == null) return widget.item.stock;
    final batches = _fullProduct!.warehouseStockBatches.where((b) {
      if (b.variantId != variant.id) return false;
      if (widget.selectedWarehouseId != null &&
          widget.selectedWarehouseId!.isNotEmpty) {
        return b.warehouseId == widget.selectedWarehouseId;
      }
      return true;
    });

    if (batches.isEmpty) {
      // Fallback si no hay lotes individuales registrados
      return variant.id == widget.item.variantId ? widget.item.stock : 0;
    }

    return batches
        .fold<double>(0, (sum, b) => sum + b.availableQuantity)
        .toInt();
  }

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

    final isLowStock = item.isLowStock;
    final totalStock =
        product != null
            ? product.productVariants.fold<int>(
              0,
              (sum, v) => sum + _calculateVariantStock(v),
            )
            : item.stock;

    return Column(
      children: [
        // Apple Drag Handle en móvil
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

        // ── Cabecera Superior ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ficha Rápida del Producto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
                      constraints: const BoxConstraints(maxWidth: 130),
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar (Esc)',
                onPressed: () => Navigator.pop(context),
              ),
            ],
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
                            'Mostrando datos de inventario. (No se pudieron cargar detalles remotos)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Hero de Producto
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
                                        _buildMonogram(item.productName, 72),
                              )
                              : _buildMonogram(item.productName, 72),
                    ),
                    const SizedBox(width: 14),

                    // Título, Categoría y Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.category.isNotEmpty
                                ? item.category
                                : 'Sin categoría',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildStockBadge(totalStock, isLowStock),
                              _buildTypeBadge(
                                product?.productType ?? item.productType,
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

                // ── Tarjeta de Métricas Financieras y Stock ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
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
                            const SizedBox(height: 4),
                            Text(
                              'S/ ${item.salePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Costo Ref
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
                            const SizedBox(height: 4),
                            Text(
                              'S/ ${item.unitCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Control de Lotes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lotes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.usesBatches ? 'Activo' : 'No usa',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    item.usesBatches
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sección Variantes ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.style_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLoadingProduct
                              ? 'Variantes...'
                              : 'Variantes (${variants.isNotEmpty ? variants.length : 1})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Total: $totalStock uds.',
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                else if (variants.isEmpty)
                  // Si no cargaron variantes adicionales, mostrar la variante actual del item
                  _VariantRowItem(
                    title:
                        item.attrsText.isNotEmpty
                            ? item.attrsText
                            : 'Variante Estándar',
                    sku: item.sku,
                    salePrice: item.salePrice,
                    unitCost: item.unitCost,
                    stock: item.stock,
                    isActive: true,
                    onOpenKardex: () {
                      Navigator.pop(context);
                      context.push(
                        '/admin/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
                      );
                    },
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
                      final vStock = _calculateVariantStock(v);
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
            ),
          ),
        ),

        // ── Footer con Acciones Clave ──
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
              // Botón Kárdex
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/admin/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
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

              // Botón Editar
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
                      '/admin/product/${item.productId}?variantId=${item.variantId}',
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

  Widget _buildStockBadge(int stock, bool isLowStock) {
    final isOut = stock <= 0;

    Color bgColor;
    Color textColor;
    IconData iconData;
    String text;

    if (isOut) {
      bgColor = AppColors.dangerLight.withValues(alpha: 0.6);
      textColor = AppColors.danger;
      iconData = Icons.error_outline_rounded;
      text = 'Agotado';
    } else if (isLowStock || stock <= 5) {
      bgColor = AppColors.warningLight.withValues(alpha: 0.6);
      textColor = AppColors.warningDark;
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo ($stock uds.)';
    } else {
      bgColor = AppColors.tealLight.withValues(alpha: 0.6);
      textColor = AppColors.tealDark;
      iconData = Icons.check_circle_outline_rounded;
      text = '$stock uds.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slateLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
          letterSpacing: 0.3,
        ),
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
  final VoidCallback onOpenKardex;

  const _VariantRowItem({
    required this.title,
    this.sku,
    required this.salePrice,
    required this.unitCost,
    required this.stock,
    required this.isActive,
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
      stockBg = AppColors.dangerLight.withValues(alpha: 0.6);
      stockColor = AppColors.danger;
      stockLabel = 'Agotado';
    } else if (isLow) {
      stockBg = AppColors.warningLight.withValues(alpha: 0.6);
      stockColor = AppColors.warningDark;
      stockLabel = '$stock uds.';
    } else {
      stockBg = AppColors.tealLight.withValues(alpha: 0.6);
      stockColor = AppColors.tealDark;
      stockLabel = '$stock uds.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Dot activo
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Label y SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
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
                fontWeight: FontWeight.w700,
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
                ),
              ),
              Text(
                'Costo: S/ ${unitCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
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
    );
  }
}
