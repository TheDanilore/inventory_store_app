import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_nav_tile.dart';

class SidebarExpandableGroup extends StatefulWidget {
  final AdminSidebarItem item;
  final bool isCollapsed;
  final String currentPath;

  const SidebarExpandableGroup({
    super.key,
    required this.item,
    required this.isCollapsed,
    required this.currentPath,
  });

  @override
  State<SidebarExpandableGroup> createState() => _SidebarExpandableGroupState();
}

class _SidebarExpandableGroupState extends State<SidebarExpandableGroup> {
  @override
  Widget build(BuildContext context) {
    if (widget.item.children.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveChild = widget.item.children.any(
      (sub) => SidebarNavTile.isItemActive(sub.routePath, widget.currentPath),
    );

    // Sincronizar persistencia: si tiene un hijo activo, se mantiene abierto
    if (hasActiveChild) {
      SidebarNavigationMemory.expandedGroups.add(widget.item.title);
    }
    final isOpen = SidebarNavigationMemory.expandedGroups.contains(
      widget.item.title,
    );

    // Modo Colapsado: Menú flotante Popup
    if (widget.isCollapsed) {
      return PopupMenuButton<String>(
        tooltip: widget.item.title,
        offset: const Offset(60, 0),
        onSelected: (route) => context.go(route),
        itemBuilder:
            (ctx) =>
                widget.item.children
                    .map(
                      (sub) => PopupMenuItem(
                        value: sub.routePath,
                        child: Row(
                          children: [
                            Icon(
                              sub.icon,
                              size: 18,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Text(sub.title),
                          ],
                        ),
                      ),
                    )
                    .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  hasActiveChild
                      ? (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF))
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  hasActiveChild
                      ? Border.all(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFDBEAFE),
                        width: 1,
                      )
                      : null,
            ),
            child: Icon(
              widget.item.icon,
              size: 20,
              color:
                  hasActiveChild
                      ? (isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB))
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    // Modo Expandido: Cabecera con Chevron + Lista de Sub-ítems
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (SidebarNavigationMemory.expandedGroups.contains(
                    widget.item.title,
                  )) {
                    SidebarNavigationMemory.expandedGroups.remove(
                      widget.item.title,
                    );
                  } else {
                    SidebarNavigationMemory.expandedGroups.add(
                      widget.item.title,
                    );
                  }
                });
              },
              hoverColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      size: 20,
                      color:
                          hasActiveChild
                              ? (isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB))
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: -0.2,
                          fontWeight:
                              hasActiveChild
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                          color:
                              hasActiveChild
                                  ? (isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF1E40AF))
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color:
                            isDark
                                ? AppColors.darkTextMuted
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Duration(milliseconds: isOpen ? 220 : 160),
          curve: isOpen ? Curves.easeOutCubic : Curves.easeInCubic,
          alignment: Alignment.topCenter,
          child:
              !isOpen
                  ? const SizedBox(width: double.infinity)
                  : Container(
                    margin: const EdgeInsets.only(
                      left: 20,
                      right: 8,
                      bottom: 4,
                    ),
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children:
                          widget.item.children
                              .map(
                                (sub) => SidebarNavTile(
                                  key: ValueKey(sub.routePath),
                                  item: sub,
                                  isCollapsed: false,
                                  isSubItem: true,
                                  currentPath: widget.currentPath,
                                ),
                              )
                              .toList(),
                    ),
                  ),
        ),
      ],
    );
  }
}
