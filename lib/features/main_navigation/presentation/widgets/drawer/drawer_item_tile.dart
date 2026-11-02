import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';

/// Ítem unitario de navegación en el Drawer móvil / tablet.
class DrawerItemTile extends StatelessWidget {
  final DrawerItem item;

  const DrawerItemTile({super.key, required this.item});

  static bool isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    if (routePath == '/' &&
        (currentPath == '/dashboard' || currentPath == '/')) {
      return true;
    }
    if (routePath == '/catalog' &&
        (currentPath == '/catalog' || currentPath.startsWith('/catalog/'))) {
      return true;
    }
    if (routePath != '/' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active = isItemActive(item.routePath, currentPath);
    final isDark = AppColors.isDark(context);

    final itemBg =
        active ? AppColors.sideActiveBg(context) : Colors.transparent;
    final itemBorder =
        active ? AppColors.sideActiveBorder(context) : Colors.transparent;
    final itemIndicator = AppColors.sideActiveIndicator(context);
    final iconColor =
        active
            ? (isDark ? const Color(0xFF60A5FA) : itemIndicator)
            : AppColors.sideText(context);
    final textColor =
        active
            ? AppColors.sideTextActive(context)
            : AppColors.txtPrimary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: item.onTap,
          splashColor: itemIndicator.withValues(alpha: 0.12),
          hoverColor: AppColors.sideHover(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: itemBorder, width: 1),
            ),
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 3.5,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: itemIndicator,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: itemIndicator.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                Icon(item.icon, color: iconColor, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.trailing != null) item.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
