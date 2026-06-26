import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

// ─── COMPACT BOTTOM BAR ──────────────────────────────────────────────────────

class ProductBottomBar extends StatelessWidget {
  final bool canBuy;
  final bool isActive;
  final int effectiveStock;
  final double effectivePrice;
  final int selectedQty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onQtyTap;
  final VoidCallback onAddToCart;

  const ProductBottomBar({
    super.key,
    required this.canBuy,
    required this.isActive,
    required this.effectiveStock,
    required this.effectivePrice,
    required this.selectedQty,
    required this.onDecrement,
    required this.onIncrement,
    required this.onQtyTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (canBuy) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _QtyBtn(
                        icon: Icons.remove_rounded,
                        enabled: canBuy && selectedQty > 1,
                        onTap: onDecrement,
                      ),
                      GestureDetector(
                        onTap: canBuy ? onQtyTap : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$selectedQty',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      _QtyBtn(
                        icon: Icons.add_rounded,
                        enabled: canBuy && selectedQty < effectiveStock,
                        onTap: onIncrement,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: canBuy ? onAddToCart : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient:
                          canBuy
                              ? const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color: canBuy ? null : AppColors.slateLight,
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      boxShadow:
                          canBuy
                              ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !isActive
                              ? Icons.do_not_disturb_alt_rounded
                              : canBuy
                              ? Icons.shopping_bag_rounded
                              : Icons.remove_shopping_cart_rounded,
                          color: canBuy ? Colors.white : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              !isActive
                                  ? 'No disponible'
                                  : canBuy
                                  ? 'Añadir al carrito'
                                  : 'Agotado',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color:
                                    canBuy ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                            if (canBuy)
                              Text(
                                'S/ ${(effectivePrice * selectedQty).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:
            enabled
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: enabled ? AppColors.primary : AppColors.textMuted,
      ),
    ),
  );
}
