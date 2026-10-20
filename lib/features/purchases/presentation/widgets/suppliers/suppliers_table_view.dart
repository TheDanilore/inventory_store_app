import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:url_launcher/url_launcher.dart';

class SuppliersTableView extends StatefulWidget {
  final List<SupplierEntity> suppliers;
  final SupplierEntity? selectedSupplier;
  final Function(SupplierEntity) onEdit;
  final Function(SupplierEntity) onToggleStatus;
  final AdminTablePaginationConfig? paginationConfig;

  const SuppliersTableView({
    super.key,
    required this.suppliers,
    this.selectedSupplier,
    required this.onEdit,
    required this.onToggleStatus,
    this.paginationConfig,
  });

  @override
  State<SuppliersTableView> createState() => _SuppliersTableViewState();
}

class _SuppliersTableViewState extends State<SuppliersTableView> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

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

  List<SupplierEntity> _getSortedSuppliers() {
    if (_sortColumnId == null) return widget.suppliers;
    final list = List<SupplierEntity>.from(widget.suppliers);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'contact':
          cmp = (a.contactName ?? '').toLowerCase().compareTo(
            (b.contactName ?? '').toLowerCase(),
          );
          break;
        case 'address':
          cmp = (a.address ?? '').toLowerCase().compareTo(
            (b.address ?? '').toLowerCase(),
          );
          break;
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = _getSortedSuppliers();

    return AdminProTable<SupplierEntity>(
      items: sortedList,
      itemId: (s) => s.id,
      selectedIds: _selectedIds,
      onSelectionChanged: (newSet) {
        setState(() {
          _selectedIds.clear();
          _selectedIds.addAll(newSet);
        });
      },
      sortColumnId: _sortColumnId,
      isSortAscending: _isSortAscending,
      onSort: (colId, isAsc) {
        setState(() {
          _sortColumnId = colId;
          _isSortAscending = isAsc;
        });
      },
      paginationConfig: widget.paginationConfig,
      onRowTap: widget.onEdit,
      minTableWidth: 920.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<SupplierEntity>(
          label: 'Copiar Datos',
          icon: Icons.copy_all_rounded,
          onPressed: (selectedItems) {
            final text = selectedItems
                .map((s) => '${s.name} (RUC: ${s.taxId ?? "—"})')
                .join('\n');
            _copyToClipboard(
              context,
              text,
              '${selectedItems.length} proveedores',
            );
          },
        ),
        AdminBulkAction<SupplierEntity>(
          label: 'Alternar Estado',
          icon: Icons.swap_horiz_rounded,
          onPressed: (selectedItems) {
            for (final s in selectedItems) {
              widget.onToggleStatus(s);
            }
            AppSnackbar.show(
              context,
              message:
                  'Se actualizó el estado de ${selectedItems.length} proveedores',
              type: SnackbarType.info,
            );
          },
        ),
      ],
      columns: [
        // 1. PROVEEDOR / RAZÓN SOCIAL
        AdminTableColumn<SupplierEntity>(
          id: 'name',
          label: 'Proveedor / Razón Social',
          flex: 5,
          isSortable: true,
          cellBuilder: (context, supplier) {
            return Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        supplier.isActive
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
                      color:
                          supplier.isActive
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        supplier.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              supplier.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                          decoration:
                              supplier.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (supplier.taxId != null && supplier.taxId!.isNotEmpty)
                        InkWell(
                          onTap:
                              () => _copyToClipboard(
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
            );
          },
        ),

        // 2. CONTACTO COMERCIAL
        AdminTableColumn<SupplierEntity>(
          id: 'contact',
          label: 'Contacto Comercial',
          flex: 3,
          isSortable: true,
          cellBuilder: (context, supplier) {
            if (supplier.contactName != null &&
                supplier.contactName!.isNotEmpty) {
              return Row(
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
              );
            }
            return const Text(
              '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            );
          },
        ),

        // 3. CANALES DIRECTOS
        AdminTableColumn<SupplierEntity>(
          id: 'channels',
          label: 'Canales Directos',
          fixedWidth: 135,
          isSortable: false,
          cellBuilder: (context, supplier) {
            return Row(
              children: [
                if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
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
                if (supplier.email != null && supplier.email!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _ActionIcon(
                    icon: Icons.email_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                    tooltip: supplier.email!,
                    onTap: () => _sendEmail(supplier.email!),
                  ),
                ],
                if ((supplier.phone == null || supplier.phone!.isEmpty) &&
                    (supplier.email == null || supplier.email!.isEmpty))
                  const Text(
                    '—',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            );
          },
        ),

        // 4. DIRECCIÓN
        AdminTableColumn<SupplierEntity>(
          id: 'address',
          label: 'Dirección',
          flex: 4,
          isSortable: true,
          cellBuilder: (context, supplier) {
            final hasAddress =
                supplier.address != null && supplier.address!.isNotEmpty;
            return Text(
              hasAddress ? supplier.address! : '—',
              style: TextStyle(
                fontSize: 11.5,
                color:
                    hasAddress ? AppColors.textSecondary : AppColors.textMuted,
                fontWeight: hasAddress ? FontWeight.normal : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),

        // 5. ESTADO
        AdminTableColumn<SupplierEntity>(
          id: 'status',
          label: 'Estado',
          fixedWidth: 110,
          isSortable: true,
          cellBuilder: (context, supplier) {
            return Align(
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
                    color:
                        supplier.isActive
                            ? AppColors.successLight
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color:
                          supplier.isActive
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
                          color:
                              supplier.isActive
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
                          color:
                              supplier.isActive
                                  ? AppColors.successDark
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 6. ACCIONES
        AdminTableColumn<SupplierEntity>(
          id: 'actions',
          label: 'Acciones',
          fixedWidth: 100,
          isSortable: false,
          alignment: Alignment.centerRight,
          cellBuilder: (context, supplier) {
            return Tooltip(
              message: 'Editar proveedor',
              child: OutlinedButton.icon(
                onPressed: () => widget.onEdit(supplier),
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: const Text(
                  'Editar',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
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
            );
          },
        ),
      ],
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
