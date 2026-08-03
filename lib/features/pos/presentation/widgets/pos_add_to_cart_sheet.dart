import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/add_to_cart/pos_add_to_cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/add_to_cart/pos_add_to_cart_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';

/// Bottom sheet para agregar un producto al carrito del POS.
/// Carga variantes con el join relacional correcto (sin JSONB obsoleto).
class PosAddToCartSheet extends StatefulWidget {
  final ProductEntity productEntity;
  final bool isDialogMode;
  final String? warehouseId;

  const PosAddToCartSheet({
    super.key,
    required this.productEntity,
    this.isDialogMode = false,
    this.warehouseId,
  });

  static Future<void> show(BuildContext context, ProductEntity product) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final cartCubit = context.read<CartCubit>();
    final warehouseId = context.read<PosCubit>().state.selectedWarehouseId;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cartCubit),
                BlocProvider(
                  create:
                      (_) =>
                          PosAddToCartCubit(sl<ProductsRepository>())
                            ..loadData(product, warehouseId: warehouseId),
                ),
              ],
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: PosAddToCartSheet(
                    productEntity: product,
                    isDialogMode: true,
                    warehouseId: warehouseId,
                  ),
                ),
              ),
            ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cartCubit),
                BlocProvider(
                  create:
                      (_) =>
                          PosAddToCartCubit(sl<ProductsRepository>())
                            ..loadData(product, warehouseId: warehouseId),
                ),
              ],
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: PosAddToCartSheet(
                  productEntity: product,
                  warehouseId: warehouseId,
                ),
              ),
            ),
      );
    }
  }

  @override
  State<PosAddToCartSheet> createState() => _PosAddToCartSheetState();
}

class _PosAddToCartSheetState extends State<PosAddToCartSheet> {
  Future<void> _showQuantityDialog(
    BuildContext context,
    int current,
    int maxStock,
  ) async {
    final cubit = context.read<PosAddToCartCubit>();
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => _QuantityDialog(
            currentQuantity: current,
            maxStock: maxStock,
            stockControl: widget.productEntity.stockControl,
            onSave: (newQty) => cubit.updateQuantity(newQty),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosAddToCartCubit, PosAddToCartState>(
      builder: (context, state) {
        if (state is PosAddToCartInitial || state is PosAddToCartLoading) {
          return const _LoadingSheet();
        }

        if (state is PosAddToCartError) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  widget.isDialogMode
                      ? BorderRadius.circular(20)
                      : const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: AppEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Error de red',
              message: state.message,
              action: ElevatedButton.icon(
                onPressed:
                    () => context.read<PosAddToCartCubit>().loadData(
                      widget.productEntity,
                      warehouseId: widget.warehouseId,
                    ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ),
          );
        }

        final loadedState = state as PosAddToCartLoaded;
        final stock = loadedState.currentStock;
        final String? imageUrl =
            loadedState.selectedVariant?.images.isNotEmpty == true
                ? loadedState.selectedVariant!.images.first.imageUrl
                : widget.productEntity.primaryImageUrl;

        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.isDialogMode ? 20 : 8,
            24,
            widget.isDialogMode
                ? 24
                : (MediaQuery.of(context).viewInsets.bottom + 28),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                widget.isDialogMode
                    ? BorderRadius.circular(20)
                    : const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isDialogMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Agregar al Carrito',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const Divider(height: 20),
              ] else ...[
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
              ],

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
                          'S/ ${loadedState.currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StockBadge(
                          hasStockControl: loadedState.hasStockControl,
                          stock: stock,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Variantes
              if (loadedState.variants.isNotEmpty) ...[
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
                      value: loadedState.selectedVariant,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                      items:
                          loadedState.variants.map((v) {
                            final vStock =
                                loadedState.stockByVariant[v.id] ?? 0;
                            final stockLabel =
                                loadedState.hasStockControl
                                    ? '($vStock en stock)'
                                    : '(Stock Libre)';
                            return DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.label} · S/ ${(v.salePrice)?.toStringAsFixed(2)} $stockLabel',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          context.read<PosAddToCartCubit>().selectVariant(val);
                        }
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
                      enabled: loadedState.quantity > 1,
                      onTap:
                          () => context
                              .read<PosAddToCartCubit>()
                              .updateQuantity(loadedState.quantity - 1),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              () => _showQuantityDialog(
                                context,
                                loadedState.quantity,
                                stock,
                              ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${loadedState.quantity}',
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
                      enabled:
                          !loadedState.hasStockControl ||
                          loadedState.quantity < stock,
                      onTap:
                          () => context
                              .read<PosAddToCartCubit>()
                              .updateQuantity(loadedState.quantity + 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón agregar al POS
              GestureDetector(
                onTap:
                    loadedState.canSell
                        ? () {
                          // Solo vibrar si no es web para evitar MissingPluginException
                          if (!kIsWeb) {
                            Vibration.vibrate(duration: 50, amplitude: 128);
                          }

                          final selVar = loadedState.selectedVariant;
                          if (selVar == null && loadedState.variants.isNotEmpty) {
                            return;
                          }

                          try {
                            final cartItem = CartItemEntity.fromPosSelection(
                              productEntity: widget.productEntity,
                              selectedVariant: selVar,
                              quantity: loadedState.quantity,
                              stock: stock,
                              hasStockControl: loadedState.hasStockControl,
                              imageUrl: imageUrl,
                            );

                            context.read<CartCubit>().addItem(cartItem);
                            Navigator.pop(context);
                            AppSnackbar.show(
                              context,
                              message: 'Producto agregado a la caja',
                              type: SnackbarType.success,
                            );
                          } catch (e) {
                            AppSnackbar.show(
                              context,
                              message: e.toString().replaceAll(
                                'Exception: ',
                                '',
                              ),
                              type: SnackbarType.error,
                            );
                          }
                        }
                        : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient:
                        loadedState.canSell
                            ? const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : null,
                    color:
                        !loadedState.canSell ? const Color(0xFFE2E8F0) : null,
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    boxShadow:
                        loadedState.canSell
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
                        color:
                            loadedState.canSell
                                ? Colors.white
                                : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        loadedState.canSell
                            ? 'Agregar · S/ ${(loadedState.currentPrice * loadedState.quantity).toStringAsFixed(2)}'
                            : (loadedState.selectedVariant == null &&
                                    loadedState.variants.isNotEmpty
                                ? 'Sin variante activa'
                                : 'Sin stock disponible'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              loadedState.canSell
                                  ? Colors.white
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class _QuantityDialog extends StatefulWidget {
  final int currentQuantity;
  final int maxStock;
  final bool stockControl;
  final void Function(int) onSave;

  const _QuantityDialog({
    required this.currentQuantity,
    required this.maxStock,
    required this.stockControl,
    required this.onSave,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _qtyCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.currentQuantity.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final newQty = int.tryParse(_qtyCtrl.text.trim());
      if (newQty != null && newQty > 0) {
        widget.onSave(newQty);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cantidad exacta',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 5,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            helperText:
                widget.stockControl
                    ? 'Stock máximo disponible: ${widget.maxStock}'
                    : 'Stock libre (Sin límite)',
            helperStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese una cantidad';
            }
            final val = int.tryParse(value.trim());
            if (val == null || val <= 0) {
              return 'Mayor a 0';
            }
            if (widget.stockControl && val > widget.maxStock) {
              return 'Supera el stock (${widget.maxStock})';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submit,
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
