import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

class CustomersTableView extends StatefulWidget {
  final List<CustomerEntity> customers;
  final List<CustomerEntity> topVipList;
  final String? selectedCustomerId;
  final String? initialSortColumn;
  final bool initialSortAscending;
  final bool hasReachedMax;
  final ValueChanged<CustomerEntity>? onRowTap;
  final ValueChanged<CustomerEntity> onOpenDetail;
  final ValueChanged<CustomerEntity> onEditCustomer;
  final ValueChanged<String> onWhatsApp;
  final void Function(
    BuildContext context,
    Offset pos,
    CustomerEntity customer,
  )?
  onContextMenu;
  final VoidCallback? onLoadMore;

  const CustomersTableView({
    super.key,
    required this.customers,
    this.topVipList = const [],
    this.selectedCustomerId,
    this.initialSortColumn = 'name',
    this.initialSortAscending = true,
    this.hasReachedMax = true,
    this.onRowTap,
    required this.onOpenDetail,
    required this.onEditCustomer,
    required this.onWhatsApp,
    this.onContextMenu,
    this.onLoadMore,
  });

  @override
  State<CustomersTableView> createState() => _CustomersTableViewState();
}

class _CustomersTableViewState extends State<CustomersTableView> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _sortColumnId = widget.initialSortColumn;
    _isSortAscending = widget.initialSortAscending;
  }

  int? _getVipRank(String id) {
    final idx = widget.topVipList.indexWhere((c) => c.id == id);
    return idx != -1 ? idx + 1 : null;
  }

  List<CustomerEntity> _getSortedList() {
    if (_sortColumnId == null) return widget.customers;
    final list = List<CustomerEntity>.from(widget.customers);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'name':
          cmp = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          break;
        case 'document':
          cmp = (a.documentNumber ?? '').compareTo(b.documentNumber ?? '');
          break;
        case 'orders':
          cmp = a.orderCount.compareTo(b.orderCount);
          break;
        case 'debt':
          cmp = a.currentDebt.compareTo(b.currentDebt);
          break;
        case 'revenue':
          cmp = a.totalRevenue.compareTo(b.totalRevenue);
          break;
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
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
    final sortedCustomers = _getSortedList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminProTable<CustomerEntity>(
          items: sortedCustomers,
          itemId: (c) => c.id,
          selectedIds: _selectedIds,
          onSelectionChanged:
              (ids) => setState(
                () =>
                    _selectedIds
                      ..clear()
                      ..addAll(ids),
              ),
          sortColumnId: _sortColumnId,
          isSortAscending: _isSortAscending,
          onSort:
              (colId, asc) => setState(() {
                _sortColumnId = colId;
                _isSortAscending = asc;
              }),
          minTableWidth: 960,
          margin: EdgeInsets.zero,
          onRowTap: widget.onRowTap ?? widget.onOpenDetail,
          bulkActions: [
            AdminBulkAction<CustomerEntity>(
              label: 'Copiar Nombres',
              icon: Icons.copy_rounded,
              onPressed: (selected) {
                final names = selected.map((c) => c.fullName).join('\n');
                _copyToClipboard(context, names, '${selected.length} clientes');
              },
            ),
            AdminBulkAction<CustomerEntity>(
              label: 'Limpiar Selección',
              icon: Icons.close_rounded,
              onPressed: (_) => setState(() => _selectedIds.clear()),
            ),
          ],
          columns: [
            // 1. Cliente (Avatar + Nombre + Medalla VIP)
            AdminTableColumn<CustomerEntity>(
              id: 'name',
              label: 'CLIENTE',
              flex: 4,
              isSortable: true,
              cellBuilder: (context, c) {
                final vipRank = _getVipRank(c.id);
                return Row(
                  children: [
                    _buildAvatar(c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.fullName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (vipRank != null) ...[
                                const SizedBox(width: 6),
                                _buildVipBadge(vipRank),
                              ],
                            ],
                          ),
                          if (c.createdAt != null)
                            Text(
                              'Reg: ${DateFormat('dd/MM/yy', 'es').format(c.createdAt!)}',
                              style: const TextStyle(
                                fontSize: 10.5,
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

            // 2. Documento
            AdminTableColumn<CustomerEntity>(
              id: 'document',
              label: 'DOCUMENTO',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, c) {
                if (c.documentNumber != null && c.documentNumber!.isNotEmpty) {
                  return InkWell(
                    onTap:
                        () => _copyToClipboard(
                          context,
                          c.documentNumber!,
                          'Doc ${c.documentNumber}',
                        ),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${c.documentType ?? 'DOC'}: ${c.documentNumber}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  );
                }
                return const Text(
                  '—',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                );
              },
            ),

            // 3. Teléfono
            AdminTableColumn<CustomerEntity>(
              id: 'phone',
              label: 'TELÉFONO',
              flex: 2,
              cellBuilder: (context, c) {
                if (c.phone != null && c.phone!.isNotEmpty) {
                  return InkWell(
                    onTap: () => widget.onWhatsApp(c.phone!),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c.phone!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const Text(
                  '—',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                );
              },
            ),

            // 4. Estado
            AdminTableColumn<CustomerEntity>(
              id: 'status',
              label: 'ESTADO',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, c) => _buildStatusBadge(c),
            ),

            // 5. Compras
            AdminTableColumn<CustomerEntity>(
              id: 'orders',
              label: 'COMPRAS',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, c) {
                if (c.orderCount > 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 11,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${c.orderCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const Text(
                  '0',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                );
              },
            ),

            // 6. Deuda Actual
            AdminTableColumn<CustomerEntity>(
              id: 'debt',
              label: 'DEUDA',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, c) {
                if (c.currentDebt > 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'S/ ${c.currentDebt.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                }
                return const Text(
                  'Al día',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successDark,
                  ),
                );
              },
            ),

            // 7. Total Facturado
            AdminTableColumn<CustomerEntity>(
              id: 'revenue',
              label: 'FACTURADO',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, c) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S/ ${c.totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (c.lastOrderAt != null)
                      Text(
                        'Últ: ${DateFormat('dd/MM/yy', 'es').format(c.lastOrderAt!)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                );
              },
            ),

            // 8. Acciones
            AdminTableColumn<CustomerEntity>(
              id: 'actions',
              label: 'ACCIONES',
              fixedWidth: 105,
              cellBuilder:
                  (context, c) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.phone != null && c.phone!.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: Color(0xFF25D366),
                          ),
                          tooltip: 'WhatsApp',
                          splashRadius: 14,
                          onPressed: () => widget.onWhatsApp(c.phone!),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        tooltip: 'Editar',
                        splashRadius: 14,
                        color: AppColors.textSecondary,
                        onPressed: () => widget.onEditCustomer(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                        tooltip: 'Ver Ficha',
                        splashRadius: 14,
                        color: AppColors.primary,
                        onPressed: () => widget.onOpenDetail(c),
                      ),
                    ],
                  ),
            ),
          ],
          // Chameleon Mobile Touch Card (<640px)
          mobileCardBuilder: (context, c, isSelected, onSelect) {
            final vipRank = _getVipRank(c.id);
            return InkWell(
              onTap: () {
                if (widget.onRowTap != null) {
                  widget.onRowTap!(c);
                } else {
                  widget.onOpenDetail(c);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(c, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      c.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (vipRank != null) ...[
                                    const SizedBox(width: 6),
                                    _buildVipBadge(vipRank),
                                  ],
                                ],
                              ),
                              if (c.documentNumber != null &&
                                  c.documentNumber!.isNotEmpty)
                                Text(
                                  '${c.documentType ?? 'DOC'}: ${c.documentNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(c),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Facturado',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'S/ ${c.totalRevenue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        if (c.currentDebt > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deuda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.danger,
                                ),
                              ),
                              Text(
                                'S/ ${c.currentDebt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.phone != null && c.phone!.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: Color(0xFF25D366),
                                ),
                                onPressed: () => widget.onWhatsApp(c.phone!),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () => widget.onEditCustomer(c),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              color: AppColors.primary,
                              onPressed: () => widget.onOpenDetail(c),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (!widget.hasReachedMax && widget.onLoadMore != null)
          InkWell(
            onTap: widget.onLoadMore,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: AppColors.background,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Cargar más clientes...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(CustomerEntity c, {double size = 32}) {
    final initials =
        c.fullName.isNotEmpty
            ? c.fullName
                .trim()
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildVipBadge(int rank) {
    Color bg;
    Color fg;
    String label;

    switch (rank) {
      case 1:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF854D0E);
        label = '🥇 #1';
        break;
      case 2:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = '🥈 #2';
        break;
      case 3:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF9A3412);
        label = '🥉 #3';
        break;
      default:
        bg = AppColors.primary.withValues(alpha: 0.08);
        fg = AppColors.primary;
        label = '#$rank';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildStatusBadge(CustomerEntity c) {
    if (!c.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.slateLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Inactivo',
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (c.currentDebt > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Con deuda',
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.warningDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.successLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'Activo',
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.successDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
