import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:url_launcher/url_launcher.dart';

class SuppliersTableView extends StatefulWidget {
  final List<SupplierEntity> suppliers;
  final Function(SupplierEntity) onEdit;
  final Function(SupplierEntity) onToggleStatus;

  const SuppliersTableView({
    super.key,
    required this.suppliers,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  State<SuppliersTableView> createState() => _SuppliersTableViewState();
}

class _SuppliersTableViewState extends State<SuppliersTableView> {
  String? _hoveredId;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone(String phone) {
    if (phone.isNotEmpty) {
      _launchUrl('tel:$phone');
    }
  }

  void _openWhatsApp(String phone) {
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      _launchUrl('https://wa.me/$cleanPhone');
    }
  }

  void _sendEmail(String email) {
    if (email.isNotEmpty) {
      _launchUrl('mailto:$email');
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 840.0;
        final needsScroll = constraints.maxWidth < minTableWidth;

        final tableContent = SizedBox(
          width: needsScroll ? minTableWidth : constraints.maxWidth,
          child: Column(
            children: [
              // --- Encabezado Fijo de Tabla ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'PROVEEDOR / RAZÓN SOCIAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'CONTACTO COMERCIAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'CANALES DIRECTOS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'DIRECCIÓN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'ESTADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'ACCIONES',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Filas de Datos ---
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.suppliers.length,
                separatorBuilder:
                    (_, _) =>
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final supplier = widget.suppliers[index];

                  final isHovered = _hoveredId == supplier.id;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredId = supplier.id),
                    onExit: (_) => setState(() => _hoveredId = null),
                    child: InkWell(
                      onTap: () => widget.onEdit(supplier),
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeInOut,
                        color: isHovered ? const Color(0xFFF8FAFC) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            // Proveedor (Avatar + Nombre + RUC)
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: supplier.isActive
                                          ? AppColors.tealLight
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      supplier.name.isNotEmpty
                                          ? supplier.name.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: TextStyle(
                                        color: supplier.isActive
                                            ? AppColors.tealDark
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
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
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
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
                                        if (supplier.taxId != null &&
                                            supplier.taxId!.isNotEmpty)
                                          InkWell(
                                            onTap: () => _copyToClipboard(
                                              context,
                                              supplier.taxId!,
                                              'RUC',
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Text(
                                              'RUC ${supplier.taxId}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          )
                                        else
                                          const Text(
                                            '—',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Contacto Comercial
                            Expanded(
                              flex: 4,
                              child: (supplier.contactName != null &&
                                      supplier.contactName!.isNotEmpty)
                                  ? Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 15,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            supplier.contactName!,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                            ),

                            // Canales Directos (WhatsApp, Teléfono, Email)
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  if (supplier.phone != null &&
                                      supplier.phone!.isNotEmpty) ...[
                                    _ActionIcon(
                                      icon: Icons.message_rounded,
                                      color: AppColors.success,
                                      bgColor: AppColors.successLight,
                                      tooltip: 'WhatsApp: ${supplier.phone}',
                                      onTap: () => _openWhatsApp(supplier.phone!),
                                    ),
                                    const SizedBox(width: 6),
                                    _ActionIcon(
                                      icon: Icons.phone_rounded,
                                      color: AppColors.info,
                                      bgColor: AppColors.infoLight,
                                      tooltip: 'Llamar: ${supplier.phone}',
                                      onTap: () => _callPhone(supplier.phone!),
                                    ),
                                  ],
                                  if (supplier.email != null &&
                                      supplier.email!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    _ActionIcon(
                                      icon: Icons.email_rounded,
                                      color: AppColors.primary,
                                      bgColor: AppColors.primaryLight,
                                      tooltip: supplier.email!,
                                      onTap: () => _sendEmail(supplier.email!),
                                    ),
                                  ],
                                  if ((supplier.phone == null ||
                                          supplier.phone!.isEmpty) &&
                                      (supplier.email == null ||
                                          supplier.email!.isEmpty))
                                    const Text(
                                      '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Dirección
                            Expanded(
                              flex: 4,
                              child: Text(
                                (supplier.address != null &&
                                        supplier.address!.isNotEmpty)
                                    ? supplier.address!
                                    : '—',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: (supplier.address != null &&
                                          supplier.address!.isNotEmpty)
                                      ? AppColors.textSecondary
                                      : AppColors.textMuted,
                                  fontWeight: (supplier.address != null &&
                                          supplier.address!.isNotEmpty)
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Estado (Status Pill interactivo)
                            SizedBox(
                              width: 100,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => widget.onToggleStatus(supplier),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: supplier.isActive
                                          ? AppColors.successLight
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: supplier.isActive
                                            ? AppColors.success.withValues(alpha: 0.3)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: supplier.isActive
                                                ? AppColors.success
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          supplier.isActive ? 'Activo' : 'Inactivo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: supplier.isActive
                                                ? AppColors.successDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Acciones (Botón Editar Estilizado)
                            SizedBox(
                              width: 100,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Tooltip(
                                    message: 'Editar proveedor',
                                    child: OutlinedButton.icon(
                                      onPressed: () => widget.onEdit(supplier),
                                      icon: const Icon(Icons.edit_outlined, size: 13),
                                      label: const Text(
                                        'Editar',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary,
                                        side: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
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
                  );
                },
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: needsScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tableContent,
                )
              : tableContent,
        );
      },
    );
  }
}


class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
