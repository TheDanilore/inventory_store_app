import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';

/// Hoja interactiva del carrito en vivo montada en la parte inferior o lateral en modo split.
class ScannerLiveCartPanel extends StatelessWidget {
  final CartCubit cartCubit;
  final VoidCallback onOpenSearchModal;
  final VoidCallback onManualSubmit;
  final VoidCallback onCheckout;
  final TextEditingController manualInputCtrl;
  final FocusNode manualFocusNode;

  const ScannerLiveCartPanel({
    super.key,
    required this.cartCubit,
    required this.onOpenSearchModal,
    required this.onManualSubmit,
    required this.onCheckout,
    required this.manualInputCtrl,
    required this.manualFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      bloc: cartCubit,
      builder: (context, cartState) {
        final items = cartState.sortedItems;
        final totalAmount = cartState.totalAmount;
        final itemCount = cartState.itemCount;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Cabecera del Carrito
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.teal,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Carrito ($itemCount)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onOpenSearchModal,
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Buscar por nombre'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Lista de productos o Estado Vacío
              Expanded(
                child:
                    items.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white38,
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Apunta la cámara al producto',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Se agregará automáticamente al carrito.\nTambién puedes buscarlo por su nombre o ingresar su SKU.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          itemCount: items.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ScannerCartItemTile(
                              item: item,
                              cartCubit: cartCubit,
                            );
                          },
                        ),
              ),

              // Barra de entrada manual compacta
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: manualInputCtrl,
                          focusNode: manualFocusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => onManualSubmit(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            hintText: 'Ingresar código de barras o SKU...',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.keyboard_alt_outlined,
                              size: 18,
                              color: AppColors.teal,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF334155),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF334155),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.teal,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: onManualSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Agregar'),
                      ),
                    ),
                  ],
                ),
              ),

              // Pie con Totales y Botón "Cobrar"
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total a Cobrar ($itemCount ${itemCount == 1 ? 'producto' : 'productos'}):',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'S/ ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: items.isEmpty ? null : onCheckout,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.point_of_sale_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cobrar S/ ${totalAmount.toStringAsFixed(2)}',
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
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
        );
      },
    );
  }
}

/// Fila de producto individual en la lista del carrito con stepper
class ScannerCartItemTile extends StatelessWidget {
  final CartItemEntity item;
  final CartCubit cartCubit;

  const ScannerCartItemTile({
    super.key,
    required this.item,
    required this.cartCubit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Imagen / Miniatura del producto
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                    )
                    : const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
          ),
          const SizedBox(width: 10),

          // Título y Precio unitario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'S/ ${item.unitPrice.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.variantLabel != null &&
                        item.variantLabel!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${item.variantLabel})',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Stepper de Cantidad [-] QTY [+]
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    AppFeedbackService.lightImpact();
                    cartCubit.updateQuantity(item.cartKey, item.quantity - 1);
                  },
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      Icons.remove_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    AppFeedbackService.lightImpact();
                    cartCubit.updateQuantity(item.cartKey, item.quantity + 1);
                  },
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.teal,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Subtotal del ítem
          SizedBox(
            width: 58,
            child: Text(
              'S/ ${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
