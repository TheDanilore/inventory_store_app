import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_collapsible_label.dart';
import 'package:url_launcher/link.dart';

/// Baldosa unificada de navegación para ítems de primer nivel y sub-ítems.
/// Elimina más de 250 líneas de código duplicado y reemplaza listeners
/// pesados de puntero por interacciones nativas y optimizadas de [InkWell].
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
    final isActive = isItemActive(item.routePath, currentPath);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileHeight = isSubItem ? 38.0 : 40.0;
    final iconSize = isSubItem ? 19.0 : 20.0;

    Widget tileContent(FollowLink? followLink) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: Colors.transparent,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: tileHeight,
              decoration: BoxDecoration(
                color:
                    isActive
                        ? (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF))
                        : Colors.transparent,
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
                        : Border.all(color: Colors.transparent, width: 1),
              ),
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10),
              child: ClipRect(
                child: Row(
                  mainAxisAlignment:
                      isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                  children: [
                    // Indicador vertical de ítem activo (Stripe / Linear)
                    if (!isCollapsed && isActive)
                      Container(
                            width: 3.5,
                            height: isSubItem ? 16 : 18,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .scaleY(
                            begin: 0,
                            end: 1,
                            duration: 180.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .fadeIn(duration: 140.ms),

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

                    Flexible(
                      child: CollapsibleLabel(
                        collapsed: isCollapsed,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
        ),
      );
    }

    Widget tile;
    if (item.routePath.isNotEmpty) {
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
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
