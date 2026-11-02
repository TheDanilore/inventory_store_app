import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tier 1: Fila compacta de cabecera de Caja, contador dinámico de ítems y botón de vaciado rápido.
class PosCajaTier1Header extends StatelessWidget {
  final String title;
  final int cartItemCount;
  final VoidCallback? onClearCart;
  final bool isCartEmpty;

  const PosCajaTier1Header({
    super.key,
    required this.title,
    required this.cartItemCount,
    this.onClearCart,
    required this.isCartEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4.5),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 15,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textPrimary,
            ),
          ),
          if (cartItemCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$cartItemCount ${cartItemCount == 1 ? 'ítem' : 'ítems'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClearCart != null)
            Tooltip(
              message: 'Vaciar caja',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: isCartEmpty ? null : onClearCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color:
                              isCartEmpty
                                  ? Colors.grey.shade300
                                  : AppColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Vaciar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isCartEmpty
                                    ? Colors.grey.shade300
                                    : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
