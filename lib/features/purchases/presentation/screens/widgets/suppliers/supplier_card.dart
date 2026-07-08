import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          supplier.isActive
                              ? AppColors.tealLight
                              : Colors.grey.shade100,
                      child: Text(
                        supplier.name.isNotEmpty
                            ? supplier.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          color:
                              supplier.isActive
                                  ? AppColors.tealDark
                                  : Colors.grey.shade400,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nombres y RUC
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
                          if (supplier.taxId != null &&
                              supplier.taxId!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'RUC / ID: ${supplier.taxId}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Switch Estado
                    Tooltip(
                      message: supplier.isActive ? 'Desactivar' : 'Activar',
                      child: Switch(
                        value: supplier.isActive,
                        onChanged: (_) => onToggleStatus(),
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.successLight,
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),

                // Contacto (Quick Actions)
                if (supplier.contactName != null ||
                    supplier.phone != null ||
                    supplier.email != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Nombre de Contacto
                      if (supplier.contactName != null &&
                          supplier.contactName!.isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  supplier.contactName!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),

                      // Quick Action Buttons
                      if (supplier.phone != null &&
                          supplier.phone!.isNotEmpty) ...[
                        _QuickActionButton(
                          icon: Icons.phone_rounded,
                          color: Colors.blue,
                          tooltip: 'Llamar a ${supplier.phone}',
                          onTap: _callPhone,
                        ),
                        const SizedBox(width: 8),
                        _QuickActionButton(
                          icon: Icons.message_rounded,
                          color: Colors.green,
                          tooltip: 'WhatsApp',
                          onTap: _openWhatsApp,
                        ),
                      ],
                      if (supplier.email != null &&
                          supplier.email!.isNotEmpty) ...[
                        if (supplier.phone != null &&
                            supplier.phone!.isNotEmpty)
                          const SizedBox(width: 8),
                        _QuickActionButton(
                          icon: Icons.email_rounded,
                          color: Colors.orange,
                          tooltip: 'Enviar correo a ${supplier.email}',
                          onTap: _sendEmail,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44, // Excelente touch target
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
