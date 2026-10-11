import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditsTable extends StatefulWidget {
  final List<CustomerCreditEntity> accounts;
  final ValueChanged<CustomerCreditEntity> onPayTap;
  final ValueChanged<CustomerCreditEntity> onHistoryTap;
  final ValueChanged<CustomerCreditEntity> onEditTap;
  final ValueChanged<CustomerCreditEntity> onToggleStatusTap;
  final void Function(String text, String label) onCopy;
  final AdminTablePaginationConfig? paginationConfig;

  const CustomerCreditsTable({
    super.key,
    required this.accounts,
    required this.onPayTap,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onToggleStatusTap,
    required this.onCopy,
    this.paginationConfig,
  });

  @override
  State<CustomerCreditsTable> createState() => _CustomerCreditsTableState();
}

class _CustomerCreditsTableState extends State<CustomerCreditsTable> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'CL';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  List<CustomerCreditEntity> _getSortedAccounts() {
    if (_sortColumnId == null) return widget.accounts;
    final list = List<CustomerCreditEntity>.from(widget.accounts);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'customer':
          cmp = (a.customerName ?? '').toLowerCase().compareTo((b.customerName ?? '').toLowerCase());
          break;
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          break;
        case 'debt':
          cmp = a.currentDebt.compareTo(b.currentDebt);
          break;
        case 'limit':
          cmp = a.creditLimit.compareTo(b.creditLimit);
          break;
        case 'available':
          cmp = a.availableCredit.compareTo(b.availableCredit);
          break;
        case 'usage':
          final usageA = a.creditLimit > 0 ? (a.currentDebt / a.creditLimit) : 0.0;
          final usageB = b.creditLimit > 0 ? (b.currentDebt / b.creditLimit) : 0.0;
          cmp = usageA.compareTo(usageB);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  Widget _buildStatusChip(CustomerCreditEntity account, bool isMaxedOut, bool isRisk) {
    if (!account.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 12, color: Color(0xFFE11D48)),
            SizedBox(width: 4),
            Text(
              'Suspendida',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE11D48)),
            ),
          ],
        ),
      );
    }
    if (isMaxedOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFBE123C)),
            SizedBox(width: 4),
            Text(
              'Al Límite',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFBE123C)),
            ),
          ],
        ),
      );
    }
    if (isRisk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEA580C)),
            SizedBox(width: 4),
            Text(
              'Riesgo Alto',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
            ),
          ],
        ),
      );
    }
    if (account.currentDebt > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              'Con Saldo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF047857)),
          SizedBox(width: 4),
          Text(
            'Al Día',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedAccounts = _getSortedAccounts();

    return AdminProTable<CustomerCreditEntity>(
      items: sortedAccounts,
      itemId: (a) => a.id,
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
      onRowTap: widget.onHistoryTap,
      minTableWidth: 960.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<CustomerCreditEntity>(
          label: 'Copiar Resumen Deudas',
          icon: Icons.summarize_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            final double totalDebt = selectedList.fold(0.0, (sum, a) => sum + a.currentDebt);
            final summary = selectedList
                .map((a) => '- ${a.customerName ?? "Cliente"}: S/ ${a.currentDebt.toStringAsFixed(2)} de deuda [${a.isActive ? "Activo" : "Suspendido"}]')
                .join('\n');
            final fullText = 'RESUMEN LÍNEAS DE CRÉDITO CLIENTES (${selectedList.length})\n$summary\nDeuda total: S/ ${totalDebt.toStringAsFixed(2)}';
            widget.onCopy(fullText, 'Resumen de deudas');
          },
        ),
        AdminBulkAction<CustomerCreditEntity>(
          label: 'Copiar Contactos',
          icon: Icons.contact_phone_rounded,
          onPressed: (selectedList) {
            final contacts = selectedList
                .map((a) => '${a.customerName ?? "Cliente"}: Doc: ${a.customerDocument ?? "-"} | Tel: ${a.customerPhone ?? "-"}')
                .join('\n');
            widget.onCopy(contacts, 'Contactos');
          },
        ),
      ],
      columns: [
        // 1. Cliente
        AdminTableColumn<CustomerCreditEntity>(
          id: 'customer',
          label: 'CLIENTE',
          flex: 3,
          isSortable: true,
          tooltip: 'Nombre del cliente y datos de contacto',
          cellBuilder: (context, account) {
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(account.customerName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        account.customerName ?? 'Cliente Desconocido',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.customerDocument != null && account.customerDocument!.isNotEmpty
                            ? 'Doc: ${account.customerDocument}'
                            : (account.customerPhone != null && account.customerPhone!.isNotEmpty
                                ? 'Tel: ${account.customerPhone}'
                                : 'Sin documento'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        // 2. Estado
        AdminTableColumn<CustomerCreditEntity>(
          id: 'status',
          label: 'ESTADO',
          flex: 2,
          isSortable: true,
          tooltip: 'Estado de la línea de crédito',
          cellBuilder: (context, account) {
            final double pct = account.creditLimit > 0 ? (account.currentDebt / account.creditLimit) : 0.0;
            final isMaxedOut = account.isMaxedOut;
            final isRisk = pct >= 0.8 && !isMaxedOut && !account.isUnlimited;
            return Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(account, isMaxedOut, isRisk),
            );
          },
        ),

        // 3. Deuda Actual
        AdminTableColumn<CustomerCreditEntity>(
          id: 'debt',
          label: 'DEUDA ACTUAL',
          flex: 2,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Saldo deudor acumulado',
          cellBuilder: (context, account) {
            final double pct = account.creditLimit > 0 ? (account.currentDebt / account.creditLimit) : 0.0;
            final isMaxedOut = account.isMaxedOut;
            final isRisk = pct >= 0.8 && !isMaxedOut && !account.isUnlimited;
            return RichText(
              textAlign: TextAlign.end,
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'S/ ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextSpan(
                    text: account.currentDebt.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: account.currentDebt > 0
                          ? (isMaxedOut || isRisk ? AppColors.danger : const Color(0xFF0F172A))
                          : AppColors.success,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 4. Límite Total
        AdminTableColumn<CustomerCreditEntity>(
          id: 'limit',
          label: 'LÍMITE TOTAL',
          flex: 2,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Límite autorizado para crédito',
          cellBuilder: (context, account) {
            if (account.isUnlimited) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.all_inclusive_rounded, size: 13, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Sin límite',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              );
            }
            return RichText(
              textAlign: TextAlign.end,
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'S/ ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextSpan(
                    text: account.creditLimit.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 5. Disponible
        AdminTableColumn<CustomerCreditEntity>(
          id: 'available',
          label: 'DISPONIBLE',
          flex: 2,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Saldo de crédito disponible para compras',
          cellBuilder: (context, account) {
            if (account.isUnlimited) {
              return const Text(
                'Ilimitado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
              );
            }
            return RichText(
              textAlign: TextAlign.end,
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'S/ ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextSpan(
                    text: account.availableCredit.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: account.isActive ? const Color(0xFF0D9488) : AppColors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 6. Uso %
        AdminTableColumn<CustomerCreditEntity>(
          id: 'usage',
          label: 'USO %',
          flex: 2,
          isSortable: true,
          tooltip: 'Porcentaje de la línea de crédito consumido',
          cellBuilder: (context, account) {
            if (account.isUnlimited) {
              return const Text(
                'N/A',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              );
            }
            final double pct = account.creditLimit > 0 ? (account.currentDebt / account.creditLimit) : 0.0;
            final isMaxedOut = account.isMaxedOut;
            final isRisk = pct >= 0.8 && !isMaxedOut && !account.isUnlimited;
            final Color statusColor = !account.isActive
                ? AppColors.danger
                : (isMaxedOut
                    ? AppColors.danger
                    : (isRisk
                        ? const Color(0xFFEA580C)
                        : (account.currentDebt > 0 ? const Color(0xFFD97706) : const Color(0xFF0D9488))));

            return Row(
              children: [
                SizedBox(
                  width: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),

        // 7. Acciones Rápidas
        AdminTableColumn<CustomerCreditEntity>(
          id: 'actions',
          label: 'ACCIONES',
          flex: 3,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, account) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (account.isActive && account.currentDebt > 0) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => widget.onPayTap(account),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF0FDF4),
                      foregroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFFBBF7D0)),
                      ),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 14),
                    label: const Text(
                      'Abonar',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  tooltip: 'Ver historial',
                  splashRadius: 16,
                  color: AppColors.textSecondary,
                  onPressed: () => widget.onHistoryTap(account),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  tooltip: 'Editar límite',
                  splashRadius: 16,
                  color: AppColors.textSecondary,
                  onPressed: () => widget.onEditTap(account),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
                  tooltip: 'Más opciones',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    switch (val) {
                      case 'pay':
                        widget.onPayTap(account);
                        break;
                      case 'history':
                        widget.onHistoryTap(account);
                        break;
                      case 'edit':
                        widget.onEditTap(account);
                        break;
                      case 'toggle_status':
                        widget.onToggleStatusTap(account);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (account.isActive && account.currentDebt > 0)
                      const PopupMenuItem(
                        value: 'pay',
                        child: Text('💵 Abonar a cuenta'),
                      ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('📜 Historial'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('✏️ Editar límite'),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Text(
                        account.isActive ? '🚫 Suspender' : '✅ Reactivar',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, account, isSelected, onSelect) {
        final double pct = account.creditLimit > 0 ? (account.currentDebt / account.creditLimit) : 0.0;
        final isMaxedOut = account.isMaxedOut;
        final isRisk = pct >= 0.8 && !isMaxedOut && !account.isUnlimited;

        return InkWell(
          onTap: () => widget.onHistoryTap(account),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDFA) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.teal : AppColors.border,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _getInitials(account.customerName),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(account, isMaxedOut, isRisk),
                      ],
                    ),
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) => onSelect(val ?? false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  account.customerName ?? 'Cliente Desconocido',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  account.customerDocument != null && account.customerDocument!.isNotEmpty
                      ? 'Doc: ${account.customerDocument}'
                      : (account.customerPhone != null && account.customerPhone!.isNotEmpty
                          ? 'Tel: ${account.customerPhone}'
                          : 'Sin documento'),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deuda Actual',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'S/ ${account.currentDebt.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: account.currentDebt > 0 ? (isMaxedOut ? AppColors.danger : const Color(0xFF0F172A)) : AppColors.success,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Disponible',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          account.isUnlimited ? 'Ilimitado' : 'S/ ${account.availableCredit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D9488),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
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
    );
  }
}
