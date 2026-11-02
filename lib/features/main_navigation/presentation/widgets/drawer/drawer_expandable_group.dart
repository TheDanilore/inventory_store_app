import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_item_tile.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';

/// Grupo desplegable de opciones en el Drawer.
class DrawerExpandableGroup extends StatefulWidget {
  final DrawerItem item;

  const DrawerExpandableGroup({super.key, required this.item});

  @override
  State<DrawerExpandableGroup> createState() => _DrawerExpandableGroupState();
}

class _DrawerExpandableGroupState extends State<DrawerExpandableGroup> {
  void _toggle() {
    setState(() {
      if (DrawerNavigationMemory.expandedGroups.contains(widget.item.title)) {
        DrawerNavigationMemory.expandedGroups.remove(widget.item.title);
      } else {
        DrawerNavigationMemory.expandedGroups.add(widget.item.title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.children.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentPath = GoRouterState.of(context).uri.path;
    final hasActiveChild = widget.item.children.any(
      (sub) => DrawerItemTile.isItemActive(sub.routePath, currentPath),
    );

    // Permite que el grupo permanezca abierto si un hijo está activo o si el usuario lo abrió
    final isOpen =
        hasActiveChild ||
        DrawerNavigationMemory.expandedGroups.contains(widget.item.title);

    final isDark = AppColors.isDark(context);
    final headerTextColor =
        hasActiveChild
            ? AppColors.sideTextActive(context)
            : AppColors.txtPrimary(context);
    final iconColor =
        hasActiveChild
            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
            : AppColors.sideText(context);
    final chevronColor =
        isOpen
            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
            : AppColors.sideText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggle,
              splashColor: AppColors.sideActiveIndicator(
                context,
              ).withValues(alpha: 0.1),
              hoverColor: AppColors.sideHover(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(widget.item.icon, color: iconColor, size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: TextStyle(
                          color: headerTextColor,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          fontWeight:
                              hasActiveChild
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: chevronColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _SubItemsPanel(items: widget.item.children),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _SubItemsPanel extends StatelessWidget {
  final List<DrawerSubItem> items;

  const _SubItemsPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final lineBorderColor =
        isDark
            ? const Color(0xFF3B82F6).withValues(alpha: 0.45)
            : const Color(0xFF2563EB).withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 12, bottom: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: lineBorderColor, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((sub) => _SubItemTile(item: sub)).toList(),
      ),
    );
  }
}

class _SubItemTile extends StatelessWidget {
  final DrawerSubItem item;

  const _SubItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active = DrawerItemTile.isItemActive(item.routePath, currentPath);
    final isDark = AppColors.isDark(context);

    final tileBg =
        active ? AppColors.sideActiveBg(context) : Colors.transparent;
    final tileBorder =
        active ? AppColors.sideActiveBorder(context) : Colors.transparent;
    final indicatorColor = AppColors.sideActiveIndicator(context);
    final iconColor =
        active
            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
            : (isDark ? AppColors.darkSidebarText : const Color(0xFF64748B));
    final textColor =
        active
            ? AppColors.sideTextActive(context)
            : AppColors.txtPrimary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: tileBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: item.onTap,
          splashColor: indicatorColor.withValues(alpha: 0.12),
          hoverColor: AppColors.sideHover(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tileBorder, width: 1),
            ),
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(item.icon, color: iconColor, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
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
