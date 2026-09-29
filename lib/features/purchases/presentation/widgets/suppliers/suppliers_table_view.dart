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
  String? _hoveredSupplierId;

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // --- Encabezado Fijo de Tabla ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
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
                    const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final supplier = widget.suppliers[index];
              final isHovered = _hoveredSupplierId == supplier.id;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredSupplierId = supplier.id),
                onExit: (_) => setState(() => _hoveredSupplierId = null),
                child: InkWell(
                  onTap: () => widget.onEdit(supplier),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    color: isHovered
                        ? const Color(0xFFF8FAFC)
                        : Colors.transparent,
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
                                        'Sin RUC registrado',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textMuted,
                                          fontStyle: FontStyle.italic,
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
                                  'Sin contacto asignado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
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
                                  'Sin canales registrados',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
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
                                : 'No especificada',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: (supplier.address != null &&
                                      supplier.address!.isNotEmpty)
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                              fontStyle: (supplier.address != null &&
                                      supplier.address!.isNotEmpty)
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Estado (Switch compacto)
                        SizedBox(
                          width: 100,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.scale(
                              scale: 0.8,
                              alignment: Alignment.centerLeft,
                              child: Switch(
                                value: supplier.isActive,
                                onChanged: (_) => widget.onToggleStatus(supplier),
                                activeThumbColor: AppColors.success,
                                activeTrackColor: AppColors.successLight,
                                inactiveThumbColor: Colors.grey.shade400,
                                inactiveTrackColor: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ),

                        // Acciones
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                tooltip: 'Editar proveedor',
                                onPressed: () => widget.onEdit(supplier),
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
