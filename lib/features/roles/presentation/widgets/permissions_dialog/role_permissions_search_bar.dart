import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permission_gateway_banner.dart';

class RolePermissionsSearchBar extends StatelessWidget {
  final bool isDesktop;
  final int totalCount;
  final Set<String> selectedPermissions;
  final bool isAdminRole;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const RolePermissionsSearchBar({
    super.key,
    required this.isDesktop,
    required this.totalCount,
    required this.selectedPermissions,
    required this.isAdminRole,
    required this.onSearchChanged,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar permiso por nombre o código...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: isAdminRole ? null : onSelectAll,
            icon: const Icon(Icons.select_all_rounded, size: 16),
            label: const Text('Marcar Todos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: isAdminRole ? null : onDeselectAll,
            icon: const Icon(Icons.deselect_rounded, size: 16),
            label: const Text('Desmarcar Todos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar permiso...',
              hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${selectedPermissions.length} de $totalCount seleccionados',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: isAdminRole ? null : onSelectAll,
                  icon: const Icon(Icons.select_all_rounded, size: 14),
                  label: const Text('Todos'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: isAdminRole ? null : onDeselectAll,
                  icon: const Icon(Icons.deselect_rounded, size: 14),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        RoleEnvironmentStatusBanner(
          selectedPermissions: selectedPermissions,
          isAdminRole: isAdminRole,
        ),
      ],
    );
  }
}
