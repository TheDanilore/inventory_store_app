import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

class VariantCardPricing extends StatelessWidget {
  final TextEditingController unitCostCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController wholesalePriceCtrl;
  final TextEditingController wholesaleMinQuantityCtrl;

  const VariantCardPricing({
    super.key,
    required this.unitCostCtrl,
    required this.priceCtrl,
    required this.wholesalePriceCtrl,
    required this.wholesaleMinQuantityCtrl,
  });

  Widget _buildMarginBadge() {
    final cost = double.tryParse(unitCostCtrl.text);
    final price = double.tryParse(priceCtrl.text);
    if (cost == null || price == null || price <= 0) {
      return const SizedBox.shrink();
    }

    final marginPercent = ((price - cost) / price) * 100;
    final isPositive = marginPercent > 0;
    final isHealthy = marginPercent >= 25;

    final color =
        isHealthy
            ? AppColors.success
            : isPositive
            ? Colors.orange.shade700
            : AppColors.error;

    final bgColor =
        isHealthy
            ? AppColors.success.withValues(alpha: 0.1)
            : isPositive
            ? Colors.orange.shade50
            : AppColors.error.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy
                ? Icons.trending_up_rounded
                : isPositive
                ? Icons.remove_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Margen: ${marginPercent >= 0 ? '+' : ''}${marginPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.attach_money_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              const Text(
                'Precios de la variante',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: Listenable.merge([unitCostCtrl, priceCtrl]),
                builder: (context, _) => _buildMarginBadge(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Costo unitario',
                  controller: unitCostCtrl,
                  icon: Icons.price_change_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hintText: '0.00',
                  prefixText: 'S/ ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final n = double.tryParse(val.trim());
                      if (n == null || n < 0) {
                        return 'No negativo';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Precio venta',
                  controller: priceCtrl,
                  icon: Icons.sell_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hintText: '0.00',
                  prefixText: 'S/ ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Requerido';
                    }
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'Debe ser > 0';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'P. mayorista',
                  controller: wholesalePriceCtrl,
                  icon: Icons.local_offer_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hintText: '0.00',
                  prefixText: 'S/ ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final n = double.tryParse(val.trim());
                      if (n == null || n <= 0) {
                        return 'Debe ser > 0';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Mín. para mayoreo',
                  controller: wholesaleMinQuantityCtrl,
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  hintText: 'Ej: 10',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) {
                    if (wholesalePriceCtrl.text.trim().isNotEmpty) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Requerido';
                      }
                      final n = int.tryParse(val.trim());
                      if (n == null || n <= 1) {
                        return 'Debe ser > 1';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
