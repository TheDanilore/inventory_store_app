import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

class SupplierCreditsTable extends StatefulWidget {
  final List<SupplierCreditEntity> accounts;
  final SupplierCreditEntity? selectedAccount;
  final Function(SupplierCreditEntity) onSelectAccount;
  final Function(SupplierCreditEntity) onPay;
  final Function(SupplierCreditEntity) onViewHistory;
  final AdminTablePaginationConfig? paginationConfig;

  const SupplierCreditsTable({
    super.key,
    required this.accounts,
    this.selectedAccount,
    required this.onSelectAccount,
    required this.onPay,
    required this.onViewHistory,
    this.paginationConfig,
  });

  @override
  State<SupplierCreditsTable> createState() => _SupplierCreditsTableState();
}

class _SupplierCreditsTableState extends State<SupplierCreditsTable> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  Color _getDebtColor(double pct, bool isMaxedOut, double debt) {
    if (debt <= 0) return AppColors.textMuted;
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warningDark;
    return AppColors.textPrimary;
  }

  Color _getProgressColor(double pct, bool isMaxedOut) {
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warning;
    return AppColors.teal;
  }

  /// 50000 -> "S/ 50,000.00"
  String _money(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'S/ $intPart.${parts[1]}';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  List<SupplierCreditEntity> _getSortedAccounts() {
    if (_sortColumnId == null) return widget.accounts;
    final list = List<SupplierCreditEntity>.from(widget.accounts);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'supplier':
          cmp = a.supplierName.toLowerCase().compareTo(
            b.supplierName.toLowerCase(),
          );
          break;
        case 'creditLimit':
          cmp = a.creditLimit.compareTo(b.creditLimit);
          break;
        case 'currentDebt':
          cmp = a.currentDebt.compareTo(b.currentDebt);
          break;
        case 'availableCredit':
          cmp = a.availableCredit.compareTo(b.availableCredit);
          break;
        case 'usage':
          cmp = a.usagePercent.compareTo(b.usagePercent);
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
    final sortedList = _getSortedAccounts();

    return AdminProTable<SupplierCreditEntity>(
      items: sortedList,
      itemId: (account) => account.creditId,
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
      onRowTap: widget.onSelectAccount,
      minTableWidth: 1020.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<SupplierCreditEntity>(
          label: 'Copiar Resumen Deudas',
          icon: Icons.copy_all_rounded,
          onPressed: (selectedItems) {
            final text = selectedItems
                .map(
                  (a) =>
                      '${a.supplierName}: Deuda S/ ${a.currentDebt.toStringAsFixed(2)} / Límite S/ ${a.creditLimit.toStringAsFixed(2)}',
                )
                .join('\n');
            _copyToClipboard(
              context,
              text,
              '${selectedItems.length} cuentas de proveedores',
            );
          },
        ),
      ],
      columns: [
        // 1. PROVEEDOR
        AdminTableColumn<SupplierCreditEntity>(
          id: 'supplier',
          label: 'Proveedor',
          flex: 4,
          isSortable: true,
          cellBuilder: (context, account) {
            return Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        account.isActive
                            ? AppColors.tealLight
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    account.supplierName.isNotEmpty
                        ? account.supplierName.substring(0, 1).toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color:
                          account.isActive
                              ? AppColors.tealDark
                              : Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
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
                        account.supplierName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (account.supplierTaxId != null &&
                          account.supplierTaxId!.isNotEmpty)
                        InkWell(
                          onTap:
                              () => _copyToClipboard(
                                context,
                                account.supplierTaxId!,
                                'RUC',
                              ),
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            'RUC ${account.supplierTaxId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else if (account.supplierPhone != null &&
                          account.supplierPhone!.isNotEmpty)
                        Text(
                          'Tel: ${account.supplierPhone}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        )
                      else
                        const Text(
                          '—',
                          style: TextStyle(
                            fontSize: 11,
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

        // 2. LÍNEA CRÉDITO
        AdminTableColumn<SupplierCreditEntity>(
          id: 'creditLimit',
          label: 'Línea Crédito',
          fixedWidth: 140,
          alignment: Alignment.centerRight,
          isSortable: true,
          cellBuilder: (context, account) {
            return Text(
              _money(account.creditLimit),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            );
          },
        ),

        // 3. DEUDA ACTUAL
        AdminTableColumn<SupplierCreditEntity>(
          id: 'currentDebt',
          label: 'Deuda Actual',
          fixedWidth: 140,
          alignment: Alignment.centerRight,
          isSortable: true,
          cellBuilder: (context, account) {
            final pct = account.usagePercent.clamp(0.0, 1.0);
            final debtColor = _getDebtColor(
              pct,
              account.isMaxedOut,
              account.currentDebt,
            );

            return Text(
              _money(account.currentDebt),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: debtColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),

        // 4. DISPONIBLE
        AdminTableColumn<SupplierCreditEntity>(
          id: 'availableCredit',
          label: 'Disponible',
          fixedWidth: 140,
          alignment: Alignment.centerRight,
          isSortable: true,
          cellBuilder: (context, account) {
            return Text(
              _money(account.availableCredit),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    account.availableCredit > 0
                        ? AppColors.tealDark
                        : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),

        // 5. USO DE LÍNEA
        AdminTableColumn<SupplierCreditEntity>(
          id: 'usage',
          label: 'Uso de Línea',
          fixedWidth: 160,
          isSortable: true,
          cellBuilder: (context, account) {
            final pct = account.usagePercent.clamp(0.0, 1.0);
            final progressColor = _getProgressColor(pct, account.isMaxedOut);

            return Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: progressColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // 6. ESTADO
        AdminTableColumn<SupplierCreditEntity>(
          id: 'status',
          label: 'Estado',
          fixedWidth: 105,
          isSortable: true,
          cellBuilder: (context, account) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color:
                      account.isActive
                          ? AppColors.successLight
                          : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        account.isActive
                            ? AppColors.success.withValues(alpha: 0.3)
                            : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            account.isActive
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      account.isActive ? 'Activa' : 'Suspendida',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color:
                            account.isActive
                                ? AppColors.successDark
                                : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // 7. ACCIONES
        AdminTableColumn<SupplierCreditEntity>(
          id: 'actions',
          label: 'Acciones',
          fixedWidth: 135,
          isSortable: false,
          alignment: Alignment.centerRight,
          cellBuilder: (context, account) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (account.currentDebt > 0 && account.isActive) ...[
                  FilledButton.tonal(
                    onPressed: () => widget.onPay(account),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.tealLight,
                      foregroundColor: AppColors.tealDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payment_rounded, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Abonar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  tooltip: 'Historial de movimientos',
                  splashRadius: 16,
                  color: AppColors.textSecondary,
                  onPressed: () => widget.onViewHistory(account),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
