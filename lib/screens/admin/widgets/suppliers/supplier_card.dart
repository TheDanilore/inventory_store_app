import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/supplier_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const SupplierCard({
    super.key,
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
  });

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone() {
    if (supplier.phone != null && supplier.phone!.isNotEmpty) {
      _launchUrl('tel:${supplier.phone}');
    }
  }

  void _openWhatsApp() {
    if (supplier.phone != null && supplier.phone!.isNotEmpty) {
      // Remover caracteres no numéricos
      final cleanPhone = supplier.phone!.replaceAll(RegExp(r'[^\d+]'), '');
      _launchUrl('https://wa.me/$cleanPhone');
    }
  }

  void _sendEmail() {
    if (supplier.email != null && supplier.email!.isNotEmpty) {
      _launchUrl('mailto:${supplier.email}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      supplier.isActive
                          ? AppColors.tealLight
                          : Colors.grey.shade200,
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      color:
                          supplier.isActive ? AppColors.tealDark : Colors.grey,
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
                        supplier.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              supplier.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                          decoration:
                              supplier.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                        ),
                      ),
                      if (supplier.taxId != null && supplier.taxId!.isNotEmpty)
                        Text(
                          'RUC / ID: ${supplier.taxId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        supplier.isActive
                            ? AppColors.successLight
                            : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    supplier.isActive ? 'ACTIVO' : 'INACTIVO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          supplier.isActive
                              ? AppColors.success
                              : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),

            // Detalles de contacto y acciones rápidas
            if (supplier.contactName != null ||
                supplier.phone != null ||
                supplier.email != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (supplier.contactName != null &&
                        supplier.contactName!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.person_rounded,
                        text: supplier.contactName!,
                      ),

                    const SizedBox(height: 8),

                    // Fila de acciones rápidas para contacto
                    Row(
                      children: [
                        if (supplier.phone != null &&
                            supplier.phone!.isNotEmpty) ...[
                          Expanded(
                            child: _ContactActionChip(
                              icon: Icons.phone_rounded,
                              label: supplier.phone!,
                              onTap: _callPhone,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ContactActionChip(
                            icon:
                                Icons
                                    .message_rounded, // Usaremos este icono como genérico para WA
                            label: 'WA',
                            onTap: _openWhatsApp,
                            color: Colors.green,
                          ),
                        ],
                        if (supplier.phone != null &&
                            supplier.email != null &&
                            supplier.phone!.isNotEmpty &&
                            supplier.email!.isNotEmpty)
                          const SizedBox(width: 8),
                        if (supplier.email != null &&
                            supplier.email!.isNotEmpty)
                          Expanded(
                            child: _ContactActionChip(
                              icon: Icons.email_rounded,
                              label: supplier.email!,
                              onTap: _sendEmail,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(
                    supplier.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color:
                        supplier.isActive
                            ? AppColors.danger
                            : AppColors.success,
                  ),
                  label: Text(
                    supplier.isActive ? 'Desactivar' : 'Activar',
                    style: TextStyle(
                      color:
                          supplier.isActive
                              ? AppColors.danger
                              : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealLight,
                    foregroundColor: AppColors.tealDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ContactActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ContactActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
