import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/customers/data/models/profile_address_entry.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class CustomerAddressCard extends StatelessWidget {
  final ProfileAddressEntry address;
  final bool isProcessing;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomerAddressCard({
    super.key,
    required this.address,
    required this.isProcessing,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _copyToClipboard(BuildContext context) async {
    final textToCopy =
        '${address.department}, ${address.province}, ${address.district}'
        '${address.reference != null && address.reference!.isNotEmpty ? ' - Ref: ${address.reference}' : ''}';

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'Dirección copiada al portapapeles',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMain = address.isDefault;

    return Dismissible(
      key: ValueKey(address.id),
      direction:
          isProcessing ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (isProcessing) return false;
        // La confirmación real la hará la pantalla principal o el provider,
        // pero podemos lanzar onDelete que es asíncrona. Como Dismissible requiere
        // confirmación síncrona/future, lo manejaremos devolviendo false y llamando onDelete.
        onDelete();
        return false; // Retornamos false para que no se elimine del widget tree de inmediato, el provider redibujará
      },
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color:
              isMain ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isMain
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
            width: isMain ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono + textos + badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              isMain
                                  ? AppColors.primary.withValues(alpha: 0.10)
                                  : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isMain
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                          color:
                              isMain
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    address.district,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isMain)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Principal',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${address.department}, ${address.province}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (address.reference != null &&
                                address.reference!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address.reference!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),

                  // Acciones
                  Row(
                    children: [
                      if (!isMain)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: isProcessing ? null : onSetDefault,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isProcessing)
                                      const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Fijar como principal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      _iconAction(
                        icon: Icons.copy_rounded,
                        color: AppColors.success,
                        onTap:
                            isProcessing
                                ? null
                                : () => _copyToClipboard(context),
                      ),
                      const SizedBox(width: 8),
                      _iconAction(
                        icon: Icons.edit_outlined,
                        color: AppColors.info,
                        onTap: isProcessing ? null : onEdit,
                      ),
                      const SizedBox(width: 8),
                      _iconAction(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onTap: isProcessing ? null : onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
