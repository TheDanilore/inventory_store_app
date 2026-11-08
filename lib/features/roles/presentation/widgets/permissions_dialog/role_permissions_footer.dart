import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class RolePermissionsFooter extends StatelessWidget {
  final bool isDesktop;
  final bool isSaving;
  final bool isAdminRole;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const RolePermissionsFooter({
    super.key,
    required this.isDesktop,
    required this.isSaving,
    required this.isAdminRole,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (isSaving || isAdminRole) ? null : onSave,
              icon:
                  isSaving
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        isAdminRole
                            ? Icons.shield_rounded
                            : Icons.check_rounded,
                        size: 16,
                      ),
              label: Text(
                isSaving
                    ? 'Guardando...'
                    : (isAdminRole ? 'Acceso Total Fijo' : 'Guardar Permisos'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isSaving ? null : onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: (isSaving || isAdminRole) ? null : onSave,
          icon:
              isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(
                    isAdminRole ? Icons.shield_rounded : Icons.check_rounded,
                    size: 18,
                  ),
          label: Text(
            isSaving
                ? 'Guardando...'
                : (isAdminRole ? 'Acceso Total Fijo' : 'Guardar Permisos'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
