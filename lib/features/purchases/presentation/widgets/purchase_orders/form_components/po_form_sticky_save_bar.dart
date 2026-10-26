import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class POFormStickySaveBar extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final bool isValid;
  final VoidCallback onSave;

  const POFormStickySaveBar({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.isValid,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = isValid && !isSaving;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canSubmit ? onSave : null,
                icon:
                    isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  isSaving
                      ? 'Guardando...'
                      : (isEditing ? 'Guardar Cambios' : 'Generar Orden'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
