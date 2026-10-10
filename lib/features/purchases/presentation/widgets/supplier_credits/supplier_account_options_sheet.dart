import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

enum SupplierAccountAction { viewHistory, pay, edit, toggleStatus }

class SupplierAccountOptionsSheet extends StatelessWidget {
  final SupplierCreditEntity account;
  final bool isDialog;

  const SupplierAccountOptionsSheet({
    super.key,
    required this.account,
    required this.isDialog,
  });

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo abrir WhatsApp',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. COMPONENTE COMPARTIDO: Lista de opciones ──
    final contentList = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.tealLight,
                child: Text(
                  account.supplierName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.supplierName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Deuda: S/ ${account.currentDebt.toStringAsFixed(2)} · Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (account.supplierTaxId != null || account.supplierPhone != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
            child: Row(
              children: [
                if (account.supplierTaxId != null)
                  Expanded(
                    child: ActionChip(
                      avatar: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('RUC', style: TextStyle(fontSize: 12)),
                      onPressed:
                          () => _copyToClipboard(
                            context,
                            account.supplierTaxId!,
                            'RUC',
                          ),
                    ),
                  ),
                if (account.supplierTaxId != null &&
                    account.supplierPhone != null)
                  const SizedBox(width: 8),
                if (account.supplierPhone != null)
                  Expanded(
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.message_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed:
                          () =>
                              _launchWhatsApp(context, account.supplierPhone!),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 20),
        ListTile(
          leading: const Icon(Icons.history_rounded, color: AppColors.primary),
          title: const Text('Ver historial de movimientos'),
          onTap: () {
            Navigator.pop(context, SupplierAccountAction.viewHistory);
          },
        ),

        if (account.isActive && account.currentDebt > 0)
          ListTile(
            leading: const Icon(Icons.payments_rounded, color: AppColors.teal),
            title: const Text('Pagar al proveedor (Amortizar)'),
            onTap: () {
              Navigator.pop(context, SupplierAccountAction.pay);
            },
          ),
        ListTile(
          leading: const Icon(
            Icons.edit_rounded,
            color: AppColors.textSecondary,
          ),
          title: const Text('Editar línea de crédito'),
          onTap: () {
            Navigator.pop(context, SupplierAccountAction.edit);
          },
        ),
        ListTile(
          leading: Icon(
            account.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
            color: account.isActive ? AppColors.danger : AppColors.success,
          ),
          title: Text(
            account.isActive ? 'Suspender crédito' : 'Reactivar crédito',
          ),
          onTap: () {
            Navigator.pop(context, SupplierAccountAction.toggleStatus);
          },
        ),
      ],
    );

    if (isDialog) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [contentList]),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              contentList,
            ],
          ),
        ),
      ),
    );
  }
}
