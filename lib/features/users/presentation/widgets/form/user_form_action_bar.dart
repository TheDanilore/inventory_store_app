import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class UserFormActionBar extends StatelessWidget {
  final bool isLoading;
  final bool isEditing;
  final bool wide;
  final double maxWidth;
  final double hPad;
  final ValueListenable<bool> isDirtyListenable;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const UserFormActionBar({
    super.key,
    required this.isLoading,
    required this.isEditing,
    required this.wide,
    required this.maxWidth,
    required this.hPad,
    required this.isDirtyListenable,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final saveColor = isEditing ? Colors.indigo.shade700 : AppColors.primary;

    final cancelButton = OutlinedButton(
      onPressed: isLoading ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Cancelar',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );

    final saveButton = FilledButton(
      onPressed: isLoading ? null : onSave,
      style: FilledButton.styleFrom(
        backgroundColor: saveColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child:
          isLoading
              ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditing ? Icons.save_rounded : Icons.person_add_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Guardar cambios' : 'Crear colaborador',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ValueListenableBuilder<bool>(
              valueListenable: isDirtyListenable,
              builder: (context, dirty, _) {
                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          dirty
                              ? 'Tienes cambios sin guardar.'
                              : 'Los campos con * son obligatorios.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color:
                                dirty
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      cancelButton,
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 200),
                        child: saveButton,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 1, child: cancelButton),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: saveButton),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
