import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/supplier_credit_models.dart';
import 'package:inventory_store_app/screens/admin/widgets/supplier_credits/supplier_credit_account_modal.dart';
import 'package:inventory_store_app/screens/admin/widgets/supplier_credits/supplier_payment_modal.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierAccountOptionsSheet extends StatelessWidget {
  final SupplierCreditModel account;
  final VoidCallback onRefresh;
  final Function(SupplierCreditModel) onToggleStatus;

  const SupplierAccountOptionsSheet({
    super.key,
    required this.account,
    required this.onRefresh,
    required this.onToggleStatus,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      account.supplierName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade800,
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

            // Acciones Rápidas Extra (Copiado / Contactabilidad)
            if (account.supplierTaxId != null || account.supplierPhone != null)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
                child: Row(
                  children: [
                    if (account.supplierTaxId != null)
                      Expanded(
                        child: ActionChip(
                          avatar: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text(
                            'RUC',
                            style: TextStyle(fontSize: 12),
                          ),
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
                            color: Colors.green,
                          ),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed:
                              () => _launchWhatsApp(
                                context,
                                account.supplierPhone!,
                              ),
                        ),
                      ),
                  ],
                ),
              ),

            const Divider(height: 20),

            ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.blue),
              title: const Text('Ver historial de movimientos'),
              onTap: () {
                Navigator.pop(context);
                context
                    .push(
                      '/admin/supplier-credit-movements/${account.creditId}?name=${Uri.encodeComponent(account.supplierName)}&debt=${account.currentDebt}&limit=${account.creditLimit}',
                      extra: {
                        'supplierName': account.supplierName,
                        'currentDebt': account.currentDebt,
                        'creditLimit': account.creditLimit,
                      },
                    )
                    .then((_) => onRefresh());
              },
            ),

            if (account.isActive && account.currentDebt > 0)
              ListTile(
                leading: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.success,
                ),
                title: const Text('Pagar al proveedor (Amortizar)'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (_) => SupplierPaymentModal(
                          account: account,
                          onPaymentSaved: onRefresh,
                        ),
                  );
                },
              ),

            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.blue),
              title: const Text('Editar línea de crédito'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (_) => SupplierCreditAccountModal(
                        accountToEdit: account,
                        onSaved: onRefresh,
                      ),
                );
              },
            ),

            ListTile(
              leading: Icon(
                account.isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                color: account.isActive ? AppColors.danger : AppColors.success,
              ),
              title: Text(
                account.isActive ? 'Suspender crédito' : 'Reactivar crédito',
              ),
              onTap: () {
                Navigator.pop(context);
                onToggleStatus(account);
              },
            ),
          ],
        ),
      ),
    );
  }
}
