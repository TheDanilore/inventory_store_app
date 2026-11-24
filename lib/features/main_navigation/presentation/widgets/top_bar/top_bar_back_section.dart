import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';

/// Sección izquierda contextual del TopBar con botón volver y título truncable.
class TopBarBackSection extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const TopBarBackSection({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final borderColor =
        isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Volver atrás',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              hoverColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              onTap:
                  () =>
                      AppBackHandler.handleBack(context, onCustomBack: onBack),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 19,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (title.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 20, color: borderColor),
          const SizedBox(width: 14),
        ],
      ],
    );
  }
}
