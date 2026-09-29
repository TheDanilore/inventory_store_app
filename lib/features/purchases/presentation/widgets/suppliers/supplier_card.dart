import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierCard extends StatefulWidget {
  final SupplierEntity supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const SupplierCard({
    super.key,
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<SupplierCard> createState() => _SupplierCardState();
}

class _SupplierCardState extends State<SupplierCard> {
  bool _isHovered = false;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone() {
    final phone = widget.supplier.phone;
    if (phone != null && phone.isNotEmpty) {
      _launchUrl('tel:$phone');
    }
  }

  void _openWhatsApp() {
    final phone = widget.supplier.phone;
    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      _launchUrl('https://wa.me/$cleanPhone');
    }
  }

  void _sendEmail() {
    final email = widget.supplier.email;
    if (email != null && email.isNotEmpty) {
      _launchUrl('mailto:$email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplier = widget.supplier;
    final hasRuc = supplier.taxId != null && supplier.taxId!.isNotEmpty;
    final hasContact = supplier.contactName != null && supplier.contactName!.isNotEmpty;
    final hasPhone = supplier.phone != null && supplier.phone!.isNotEmpty;
    final hasEmail = supplier.email != null && supplier.email!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.teal.withValues(alpha: 0.35)
                : AppColors.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.025),
              blurRadius: _isHovered ? 14 : 8,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- Encabezado: Avatar + Nombre + RUC + Switch ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: supplier.isActive
                              ? AppColors.tealLight
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          supplier.name.isNotEmpty
                              ? supplier.name.substring(0, 1).toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: supplier.isActive
                                ? AppColors.tealDark
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nombre y RUC (o placeholder de RUC)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: supplier.isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                decoration: supplier.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (hasRuc)
                              Text(
                                'RUC / ID: ${supplier.taxId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              const Text(
                                'Sin RUC registrado',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Switch Estado con Tooltip
                      Tooltip(
                        message: supplier.isActive
                            ? 'Desactivar proveedor'
                            : 'Activar proveedor',
                        child: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: supplier.isActive,
                            onChanged: (_) => widget.onToggleStatus(),
                            activeThumbColor: AppColors.success,
                            activeTrackColor: AppColors.successLight,
                            inactiveThumbColor: Colors.grey.shade400,
                            inactiveTrackColor: Colors.grey.shade200,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- Pie de Tarjeta: Contacto y Canales Directos ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Nombre de Contacto
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hasContact
                                      ? supplier.contactName!
                                      : 'Sin contacto asignado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasContact
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                    fontWeight: hasContact
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontStyle: hasContact
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botones de Acción Rápida (con colores de AppColors)
                        if (hasPhone) ...[
                          _QuickActionButton(
                            icon: Icons.message_rounded,
                            color: AppColors.success,
                            bgColor: AppColors.successLight,
                            tooltip: 'WhatsApp: ${supplier.phone}',
                            onTap: _openWhatsApp,
                          ),
                          const SizedBox(width: 6),
                          _QuickActionButton(
                            icon: Icons.phone_rounded,
                            color: AppColors.info,
                            bgColor: AppColors.infoLight,
                            tooltip: 'Llamar a ${supplier.phone}',
                            onTap: _callPhone,
                          ),
                        ],
                        if (hasEmail) ...[
                          if (hasPhone) const SizedBox(width: 6),
                          _QuickActionButton(
                            icon: Icons.email_rounded,
                            color: AppColors.primary,
                            bgColor: AppColors.primaryLight,
                            tooltip: 'Correo: ${supplier.email}',
                            onTap: _sendEmail,
                          ),
                        ],
                        if (!hasPhone && !hasEmail)
                          TextButton.icon(
                            onPressed: widget.onEdit,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 13,
                              color: AppColors.teal,
                            ),
                            label: const Text(
                              'Completar datos',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
  final Color bgColor;
  final VoidCallback onTap;
  final String tooltip;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }
}
