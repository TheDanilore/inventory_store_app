import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_menu_builder.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_collapsible_label.dart';
import 'package:url_launcher/link.dart';

/// Baldosa unificada de navegación para ítems de primer nivel y sub-ítems.
/// Sin [AnimationController]s ni tickers por ítem para fluidez en equipos antiguos.
class SidebarNavTile extends StatelessWidget {
  final AdminSidebarItem item;
  final bool isCollapsed;
  final bool isSubItem;
  final String currentPath;

  const SidebarNavTile({
    super.key,
    required this.item,
    required this.isCollapsed,
    required this.currentPath,
    this.isSubItem = false,
  });

  static bool isItemActive(String routePath, String currentPath) =>
      AdminMenuBuilder.isRouteActive(routePath, currentPath);

  @override
  Widget build(BuildContext context) {
    final isActive = isItemActive(item.routePath, currentPath);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileHeight = isSubItem ? 38.0 : 40.0;
    final iconSize = isSubItem ? 19.0 : 20.0;

    Widget tileContent(FollowLink? followLink) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color:
              isActive
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (followLink != null) {
                followLink();
              } else if (item.routePath.isNotEmpty) {
                context.go(item.routePath);
              }
            },
            hoverColor:
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Container(
              height: tileHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border:
                    isActive
                        ? Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFDBEAFE),
                          width: 1,
                        )
                        : null,
              ),
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10),
              child: Row(
                mainAxisAlignment:
                    isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  if (!isCollapsed && isActive)
                    Container(
                      width: 3.5,
                      height: isSubItem ? 16 : 18,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Icon(
                    item.icon,
                    size: iconSize,
                    color:
                        isActive
                            ? (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB))
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B)),
                  ),
                  if (!isCollapsed)
                    Expanded(
                      child: CollapsibleLabel(
                        collapsed: isCollapsed,
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: -0.2,
                                  fontWeight:
                                      isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color:
                                      isActive
                                          ? (isDark
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFF1E40AF))
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                            if (item.trailing != null) ...[
                              const SizedBox(width: 6),
                              item.trailing!,
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Widget tile;
    if (item.routePath.isNotEmpty && GoRouter.maybeOf(context) != null) {
      tile = Link(
        uri: Uri.parse(item.routePath),
        target: LinkTarget.self,
        builder: (context, followLink) => tileContent(followLink),
      );
    } else {
      tile = tileContent(null);
    }

    if (isCollapsed) {
      return Tooltip(
        message: item.title,
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: tile,
      );
    }

    return tile;
  }
}
