import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet para agregar un producto al carrito del POS.
/// Carga variantes con el join relacional correcto (sin JSONB obsoleto).
class PosAddToCartSheet extends StatefulWidget {
  final ProductEntity productEntity;
  const PosAddToCartSheet({super.key, required this.productEntity});

  @override
  State<PosAddToCartSheet> createState() => _PosAddToCartSheetState();
}

class _PosAddToCartSheetState extends State<PosAddToCartSheet> {
  final _repo = sl<ProductsRepository>();
  bool _isLoading = true;
  List<ProductVariantEntity> _variants = [];
  final Map<String, int> _stockByVariant = {};
  ProductVariantEntity? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _fetchProductData();
  }

  Future<void> _fetchProductData() async {
    try {
      // Usa fetchVariantsByProductIds del repositorio que ya tiene el join
      // correcto: variant_attribute_values → attribute_values → attributes
      final variantMapRes = await _repo.fetchVariantsByProductIds([
        widget.productEntity.id,
      ]);
      final variantMap = variantMapRes.fold(
        (l) => <String, List<ProductVariantEntity>>{},
        (r) => r,
      );
      _variants = variantMap[widget.productEntity.id] ?? [];

      if (_variants.isNotEmpty) {
        final variantIds = _variants.map((v) => v.id).toList();
        final stockMapRes = await _repo.fetchVariantStockByVariantIds(
          variantIds,
        );
        final stockMap = stockMapRes.fold((l) => <String, int>{}, (r) => r);
        _stockByVariant.addAll(stockMap);
      }

      if (_variants.isNotEmpty) {
        _selectedVariant = _variants.firstWhere(
          (v) => (_stockByVariant[v.id] ?? 0) > 0,
          orElse: () => _variants.first,
        );
      }
    } catch (e) {
      debugPrint('PosAddToCartSheet: Error cargando variantes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasStockControl => widget.productEntity.stockControl;

  int get _currentStock {
    if (_variants.isEmpty) return widget.productEntity.totalStock;
    if (_selectedVariant == null) return 0;
    return _stockByVariant[_selectedVariant!.id] ?? 0;
  }

  double get _currentPrice {
    if (_variants.isEmpty) return widget.productEntity.salePrice;
    return _selectedVariant?.salePrice ?? widget.productEntity.salePrice;
  }

  bool get _canSell =>
      _selectedVariant != null && (!_hasStockControl || _currentStock > 0);

  Future<void> _showQuantityDialog(
    BuildContext context,
    int current,
    int maxStock,
  ) async {
    final qtyCtrl = TextEditingController(text: current.toString());
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText:
                    _hasStockControl
                        ? 'Stock máximo disponible: $maxStock'
                        : 'Stock libre (Sin límite)',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      _quantity =
                          _hasStockControl && newQty > maxStock
                              ? maxStock
                              : newQty;
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LoadingSheet();
    }

    final stock = _currentStock;
    final String? imageUrl =
        _selectedVariant?.images.isNotEmpty == true
            ? _selectedVariant!.images.first.imageUrl
            : widget.productEntity.primaryImageUrl;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header producto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child:
                    imageUrl != null
                        ? Image.network(
                          imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => const _ImgPlaceholder(size: 72),
                        )
                        : const _ImgPlaceholder(size: 72),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productEntity.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'S/ ${_currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StockBadge(
                      hasStockControl: _hasStockControl,
                      stock: stock,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Variantes
          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Variante',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProductVariantEntity>(
                  value: _selectedVariant,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  items:
                      _variants.map((v) {
                        final vStock = _stockByVariant[v.id] ?? 0;
                        final stockLabel =
                            _hasStockControl
                                ? '($vStock en stock)'
                                : '(Stock Libre)';
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            '${v.label} · S/ ${(v.salePrice ?? widget.productEntity.salePrice).toStringAsFixed(2)} $stockLabel',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedVariant = val;
                      _quantity = 1;
                    });
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Cantidad',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  enabled: _quantity > 1,
                  onTap: () => setState(() => _quantity--),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap:
                          () => _showQuantityDialog(context, _quantity, stock),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  enabled: !_hasStockControl || _quantity < stock,
                  onTap: () => setState(() => _quantity++),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón agregar al POS
          GestureDetector(
            onTap:
                _canSell
                    ? () {
                      // Solo vibrar si no es web para evitar MissingPluginException
                      if (!kIsWeb) {
                        Vibration.vibrate(duration: 50, amplitude: 128);
                      }

                      final cartKey = _selectedVariant!.id;
                      context.read<CartCubit>().addItem(
                        CartItemEntity(
                          productId: widget.productEntity.id,
                          productName: widget.productEntity.name,
                          cartKey: cartKey,
                          quantity: _quantity,
                          unitPrice:
                              _selectedVariant!.salePrice ??
                              widget.productEntity.salePrice,
                          unitCost:
                              _selectedVariant!.unitCost ??
                              widget.productEntity.unitCost,
                          availableStock: _hasStockControl ? stock : 999999,
                          usesBatches: widget.productEntity.usesBatches,
                          variantId: _selectedVariant!.id,
                          variantLabel: _selectedVariant!.label,
                          wholesalePrice:
                              _selectedVariant!.wholesalePrice ??
                              widget.productEntity.wholesalePrice,
                          imageUrl: imageUrl,
                          sku: _selectedVariant?.sku,
                          isSelected: true,
                        ),
                      );
                      Navigator.pop(context);
                      AppSnackbar.show(
                        context,
                        message: 'Producto agregado a la caja',
                        type: SnackbarType.success,
                      );
                    }
                    : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient:
                    _canSell
                        ? const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color: !_canSell ? const Color(0xFFE2E8F0) : null,
                borderRadius: BorderRadius.circular(AppColors.radius),
                boxShadow:
                    _canSell
                        ? [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: _canSell ? Colors.white : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _canSell
                        ? 'Agregar · S/ ${(_currentPrice * _quantity).toStringAsFixed(2)}'
                        : (_selectedVariant == null
                            ? 'Sin variante activa'
                            : 'Sin stock disponible'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _canSell ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────────

class _LoadingSheet extends StatelessWidget {
  const _LoadingSheet();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.teal),
          ),
        ),
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final double size;
  const _ImgPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.image_rounded, color: AppColors.textMuted),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final bool hasStockControl;
  final int stock;
  const _StockBadge({required this.hasStockControl, required this.stock});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (!hasStockControl) {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
      label = 'Stock Libre';
    } else if (stock > 0) {
      bg = AppColors.successLight;
      fg = AppColors.success;
      label = '$stock disponibles';
    } else {
      bg = AppColors.dangerLight;
      fg = AppColors.danger;
      label = 'Agotado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppColors.tealLight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.teal : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
