import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Pie de página sticky para el detalle de la orden de compra con soporte
/// horizontal en Desktop y adaptabilidad táctil en Mobile.
class PODetailStickyFooter extends StatelessWidget {
  final String status;
  final bool isProcessing;
  final bool isDialog;
  final VoidCallback onReceive;
  final VoidCallback onMarkSent;
  final VoidCallback onSendWhatsApp;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;

  const PODetailStickyFooter({
    super.key,
    required this.status,
    required this.isProcessing,
    this.isDialog = false,
    required this.onReceive,
    required this.onMarkSent,
    required this.onSendWhatsApp,
    required this.onCancel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Sin acciones disponibles: no renderizar footer
    final showCancel = status != 'CANCELLED' && status != 'RECEIVED';
    final showReceive = status == 'SENT' || status == 'PARTIAL';
    final showMarkSent = status == 'PENDING';

    if (!showCancel && !showReceive && !showMarkSent) {
      return const SizedBox.shrink();
    }

    // ── Desktop / Split View (Barra Horizontal Compacta de 60dp) ────────────
    if (isDialog) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (showCancel)
              TextButton.icon(
                onPressed: isProcessing ? null : onCancel,
                icon: const Icon(
                  Icons.cancel_outlined,
                  size: 16,
                  color: AppColors.danger,
                ),
                label: Text(
                  'Anular Orden',
                  style: TextStyle(
                    color:
                        isProcessing ? AppColors.textMuted : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            const Spacer(),
            if (onEdit != null) ...[
              OutlinedButton.icon(
                onPressed: isProcessing ? null : onEdit,
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Editar Orden',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (showMarkSent) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isProcessing ? null : onMarkSent,
                child: const Text(
                  'Marcar como ENVIADA',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: const Text(
                  'WhatsApp',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isProcessing ? null : onSendWhatsApp,
              ),
            ] else if (showReceive) ...[
              FilledButton.icon(
                icon: const Icon(Icons.inventory_rounded, size: 18),
                label: const Text(
                  'Recepcionar Mercadería',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isProcessing ? null : onReceive,
              ),
            ],
          ],
        ),
      );
    }

    // ── Mobile Bottom Sheet (Columna Táctil) ──────────────────────────────────
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child: _buildPrimaryButton(context),
          ),
          if (showCancel) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: isProcessing ? null : onCancel,
                icon: const Icon(
                  Icons.cancel_outlined,
                  size: 16,
                  color: AppColors.danger,
                ),
                label: Text(
                  'Anular Orden',
                  style: TextStyle(
                    color:
                        isProcessing ? AppColors.textMuted : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    if (status == 'SENT' || status == 'PARTIAL') {
      return SizedBox(
        key: const ValueKey('receive'),
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.inventory_rounded, size: 20),
          label: const Text(
            'Recepcionar Mercadería',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isProcessing ? null : onReceive,
        ),
      );
    }

    if (status == 'PENDING') {
      return Column(
        key: const ValueKey('pendingActions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Enviar a Proveedor (WhatsApp)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isProcessing ? null : onSendWhatsApp,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isProcessing ? null : onMarkSent,
              child: const Text(
                'Marcar como ENVIADA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text(
                  'Editar Orden de Compra',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing ? null : onEdit,
              ),
            ),
          ],
        ],
      );
    }

    // RECEIVED o CANCELLED: sin acción primaria
    return const SizedBox.shrink(key: ValueKey('none'));
  }
}
