import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_pagination_config.dart';

/// Pie de tabla integrado directamente en la parte inferior del contenedor de la tabla.
class AdminProTableIntegratedFooter extends StatelessWidget {
  final AdminTablePaginationConfig config;

  const AdminProTableIntegratedFooter({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: AdminPageBlocks(
        currentPage: config.currentPage - 1,
        totalPages: config.totalPages,
        totalItems: config.totalItems,
        itemsPerPage: config.pageSize,
        availableItemsPerPage: config.pageSizeOptions,
        onPageChanged: (zeroBasedPage) {
          config.onPageChanged(zeroBasedPage + 1);
        },
        onItemsPerPageChanged: (newSize) {
          config.onPageSizeChanged(newSize);
        },
      ),
    );
  }
}

/// Pie de tabla como tarjeta independiente debajo del contenedor principal.
class AdminProTableDetachedFooter extends StatelessWidget {
  final AdminTablePaginationConfig config;

  const AdminProTableDetachedFooter({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1.2,
        ),
        boxShadow:
            isDark
                ? AppColors.darkCardShadow(opacity: 0.15)
                : AppColors.cardShadow(opacity: 0.04),
      ),
      child: AdminPageBlocks(
        currentPage: config.currentPage - 1,
        totalPages: config.totalPages,
        totalItems: config.totalItems,
        itemsPerPage: config.pageSize,
        availableItemsPerPage: config.pageSizeOptions,
        onPageChanged: (zeroBasedPage) {
          config.onPageChanged(zeroBasedPage + 1);
        },
        onItemsPerPageChanged: (newSize) {
          config.onPageSizeChanged(newSize);
        },
      ),
    );
  }
}

/// Pie de tabla compacto optimizado para móviles y visualización de tarjetas.
class AdminProTableMobileFooter extends StatelessWidget {
  final AdminTablePaginationConfig config;
  final bool isCompact;

  const AdminProTableMobileFooter({
    super.key,
    required this.config,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: AdminPageBlocks(
        currentPage: config.currentPage - 1,
        totalPages: config.totalPages,
        totalItems: config.totalItems,
        itemsPerPage: config.pageSize,
        availableItemsPerPage: config.pageSizeOptions,
        isCompact: isCompact,
        onPageChanged: (zeroBasedPage) {
          config.onPageChanged(zeroBasedPage + 1);
        },
        onItemsPerPageChanged: (newSize) {
          config.onPageSizeChanged(newSize);
        },
      ),
    );
  }
}

