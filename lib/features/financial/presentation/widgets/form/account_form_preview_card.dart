import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';

class AccountFormPreviewCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController balanceCtrl;
  final String type;
  final String brandKey;
  final String currencyCode;
  final bool isActive;
  final bool isEditing;
  final double fallbackBalance;

  const AccountFormPreviewCard({
    super.key,
    required this.nameCtrl,
    required this.balanceCtrl,
    required this.type,
    required this.brandKey,
    required this.currencyCode,
    required this.isActive,
    required this.isEditing,
    this.fallbackBalance = 0.0,
  });

  String _typeLabel(String type) {
    const types = [
      ('CAJA', 'Caja'),
      ('BANCO', 'Banco'),
      ('DIGITAL', 'Billetera'),
      ('OTRO', 'Otro'),
    ];
    for (final t in types) {
      if (t.$1 == type) return t.$2;
    }
    return type;
  }

  Widget _miniChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final surface = AppColors.surf(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final soft = dark ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;
    final tealText = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;
    final symbol = currencyCode == 'USD' ? '\$ ' : 'S/ ';

    return ListenableBuilder(
      listenable: Listenable.merge([nameCtrl, balanceCtrl]),
      builder: (context, _) {
        final name =
            nameCtrl.text.trim().isEmpty
                ? 'Nombre de cuenta'
                : nameCtrl.text.trim();
        final brand = FinancialBrandHelper.getBrand(
          name: name,
          type: type,
          brandKey: brandKey,
        );
        final accent = brand.primaryColor;
        final balanceVal =
            double.tryParse(balanceCtrl.text.trim().replaceAll(',', '.')) ??
            (isEditing ? fallbackBalance : 0.0);
        final balanceText =
            '$symbol${NumberFormat('#,##0.00', 'en_US').format(balanceVal)}';
        final isUsd = currencyCode == 'USD';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow:
                dark
                    ? null
                    : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 13, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'VISTA PREVIA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  if (!isActive) _miniChip('Inactiva', muted, soft),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FinancialBrandHelper.buildBrandBadge(
                    name: name,
                    type: type,
                    brandKey: brandKey,
                    size: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: title,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _miniChip(_typeLabel(type), muted, soft),
                            _miniChip(
                              currencyCode,
                              isUsd ? const Color(0xFFB45309) : tealText,
                              isUsd
                                  ? const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.15)
                                  : AppColors.teal.withValues(alpha: 0.12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    balanceText,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: title,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
