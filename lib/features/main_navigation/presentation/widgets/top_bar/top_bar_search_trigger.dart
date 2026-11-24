import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';

/// Disparador adaptable de búsqueda global (Command Palette) sin animaciones costosas.
class TopBarSearchTrigger extends StatelessWidget {
  const TopBarSearchTrigger({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8);

    return Tooltip(
      message: 'Buscar en el ERP (Atajo: ⌘K / /)',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 320),
        child: Material(
          color:
              isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => AdminCommandPaletteDialog.show(context),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDark
                          ? AppColors.darkBorderSubtle
                          : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: mutedColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buscar en el ERP...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: mutedColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
