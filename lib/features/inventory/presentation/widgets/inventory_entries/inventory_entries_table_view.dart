import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';

class InventoryEntriesTableView extends StatefulWidget {
  final List<InventoryEntryEntity> entries;
  final InventoryEntryEntity? selectedEntry;
  final ValueChanged<InventoryEntryEntity> onSelectEntry;
  final VoidCallback? onRefresh;
  final AdminTablePaginationConfig? paginationConfig;

  const InventoryEntriesTableView({
    super.key,
    required this.entries,
    required this.selectedEntry,
    required this.onSelectEntry,
    this.onRefresh,
    this.paginationConfig,
  });

  @override
  State<InventoryEntriesTableView> createState() =>
      _InventoryEntriesTableViewState();
}

class _InventoryEntriesTableViewState extends State<InventoryEntriesTableView> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  List<InventoryEntryEntity> _getSortedEntries() {
    if (_sortColumnId == null) return widget.entries;
    final list = List<InventoryEntryEntity>.from(widget.entries);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'voucher':
          cmp = (a.documentNumber ?? a.id).compareTo(b.documentNumber ?? b.id);
          break;
        case 'date':
          final dateA =
              a.createdAt ??
              a.documentDate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              b.createdAt ??
              b.documentDate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        case 'supplier':
          cmp = (a.supplierName ?? '').toLowerCase().compareTo(
            (b.supplierName ?? '').toLowerCase(),
          );
          break;
        case 'warehouse':
          cmp = (a.warehouseName ?? '').toLowerCase().compareTo(
            (b.warehouseName ?? '').toLowerCase(),
          );
          break;
        case 'total':
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  Widget _buildPaymentBadge(String? paymentMode) {
    final mode = (paymentMode ?? 'CONTADO').trim().toUpperCase();

    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    if (mode == 'AJUSTE' || mode.contains('AJUSTE')) {
      bg = const Color(0xFFFFFBEB); // Amber 50
      border = const Color(0xFFFDE68A); // Amber 200
      text = const Color(0xFFB45309); // Amber 700
      label = 'Ajuste';
      icon = Icons.tune_rounded;
    } else if (mode.contains('CREDIT') || mode.contains('CRÉDITO')) {
      bg = const Color(0xFFEFF6FF); // Blue 50
      border = const Color(0xFFBFDBFE); // Blue 200
      text = const Color(0xFF1D4ED8); // Blue 700
      label = 'Crédito';
      icon = Icons.credit_card_rounded;
    } else if (mode == 'DONACION' || mode == 'DONACIÓN') {
      bg = const Color(0xFFFDF4FF); // Purple 50
      border = const Color(0xFFF0ABFC); // Purple 200
      text = const Color(0xFF86198F); // Purple 700
      label = 'Donación';
      icon = Icons.volunteer_activism_rounded;
    } else if (mode == 'TRANSFERENCIA') {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBAE6FD);
      text = const Color(0xFF0369A1);
      label = 'Transferencia';
      icon = Icons.sync_alt_rounded;
    } else {
      bg = const Color(0xFFECFDF5); // Emerald 50
      border = const Color(0xFFA7F3D0); // Emerald 200
      text = const Color(0xFF047857); // Emerald 700
      label = mode == 'CONTADO' ? 'Contado' : (mode.isEmpty ? '—' : mode);
      icon = Icons.payments_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedEntries = _getSortedEntries();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return AdminProTable<InventoryEntryEntity>(
      items: sortedEntries,
      itemId: (e) => e.id,
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
      onRowTap: widget.onSelectEntry,
      minTableWidth: 1000.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<InventoryEntryEntity>(
          label: 'Copiar Códigos',
          icon: Icons.copy_rounded,
          onPressed: (selectedList) {
            final codes = selectedList
                .map(
                  (e) =>
                      e.id.length >= 8
                          ? '#${e.id.substring(0, 8).toUpperCase()}'
                          : '#${e.id.toUpperCase()}',
                )
                .join(', ');
            _copyToClipboard(
              context,
              codes,
              '${selectedList.length} códigos de entrada',
            );
          },
        ),
        AdminBulkAction<InventoryEntryEntity>(
          label: 'Copiar Resumen de Entradas',
          icon: Icons.summarize_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            final total = selectedList.fold(
              0.0,
              (sum, e) => sum + e.totalAmount,
            );
            final summary = selectedList
                .map(
                  (e) =>
                      '- #${e.id.substring(0, 8).toUpperCase()} | ${e.supplierName ?? "Sin prov."} | ${e.documentType}: ${e.documentNumber ?? "-"} | S/ ${e.totalAmount.toStringAsFixed(2)}',
                )
                .join('\n');
            final fullText =
                'RESUMEN ENTRADAS DE INVENTARIO (${selectedList.length})\n$summary\nTotal acumulado: S/ ${total.toStringAsFixed(2)}';
            _copyToClipboard(context, fullText, 'Resumen de entradas');
          },
        ),
      ],
      columns: [
        // 1. Comprobante / Entrada
        AdminTableColumn<InventoryEntryEntity>(
          id: 'voucher',
          label: 'COMPROBANTE',
          fixedWidth: 125,
          isSortable: true,
          tooltip: 'Código interno y número de comprobante',
          cellBuilder: (context, entry) {
            final shortId =
                entry.id.length >= 8
                    ? entry.id.substring(0, 8).toUpperCase()
                    : entry.id.toUpperCase();
            final docInfo =
                (entry.documentNumber != null &&
                        entry.documentNumber!.isNotEmpty)
                    ? '${entry.documentType}: ${entry.documentNumber}'
                    : entry.documentType;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap:
                      () => _copyToClipboard(
                        context,
                        shortId,
                        'Código de entrada',
                      ),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '#$shortId',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                if (docInfo.isNotEmpty &&
                    docInfo.toUpperCase() != 'NINGUNO') ...[
                  const SizedBox(height: 2),
                  Text(
                    docInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        // 2. Fecha / Hora
        AdminTableColumn<InventoryEntryEntity>(
          id: 'date',
          label: 'FECHA / HORA',
          fixedWidth: 135,
          isSortable: true,
          tooltip: 'Fecha de recepción en almacén',
          cellBuilder: (context, entry) {
            final formattedDate =
                entry.createdAt != null
                    ? dateFormat.format(entry.createdAt!)
                    : (entry.documentDate != null
                        ? dateFormat.format(entry.documentDate!)
                        : '—');
            return Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            );
          },
        ),

        // 3. Proveedor
        AdminTableColumn<InventoryEntryEntity>(
          id: 'supplier',
          label: 'PROVEEDOR',
          flex: 3,
          isSortable: true,
          tooltip: 'Proveedor que despachó la mercadería',
          cellBuilder: (context, entry) {
            return Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: 15,
                      color: AppColors.tealDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.supplierName ?? 'Sin proveedor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // 4. Almacén Destino
        AdminTableColumn<InventoryEntryEntity>(
          id: 'warehouse',
          label: 'ALMACÉN',
          flex: 2,
          isSortable: true,
          tooltip: 'Almacén donde ingresó el stock',
          cellBuilder: (context, entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    entry.warehouseName ?? 'Almacén general',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // 5. Orden de Compra
        AdminTableColumn<InventoryEntryEntity>(
          id: 'purchaseOrder',
          label: 'ORDEN COMPRA',
          fixedWidth: 120,
          isSortable: false,
          tooltip: 'Orden de compra vinculada',
          cellBuilder: (context, entry) {
            if (entry.purchaseOrderId != null &&
                entry.purchaseOrderId!.isNotEmpty) {
              final poShort =
                  entry.purchaseOrderId!.length >= 8
                      ? entry.purchaseOrderId!.substring(0, 8).toUpperCase()
                      : entry.purchaseOrderId!.toUpperCase();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 12,
                      color: Color(0xFF7E22CE),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '#$poShort',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7E22CE),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const Text(
              '—',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            );
          },
        ),

        // 6. Modo de Pago
        AdminTableColumn<InventoryEntryEntity>(
          id: 'payment',
          label: 'PAGO',
          fixedWidth: 105,
          isSortable: false,
          tooltip: 'Condición de pago registrada',
          cellBuilder: (context, entry) {
            return Align(
              alignment: Alignment.centerLeft,
              child: _buildPaymentBadge(entry.paymentMode),
            );
          },
        ),

        // 7. Total Entrada
        AdminTableColumn<InventoryEntryEntity>(
          id: 'total',
          label: 'TOTAL',
          fixedWidth: 115,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Valor total monetario de la entrada',
          cellBuilder: (context, entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'S/ ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextSpan(
                        text: entry.totalAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Inter',
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),

        // 8. Acciones
        AdminTableColumn<InventoryEntryEntity>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 100,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, entry) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'Ver detalle',
                  hoverColor: const Color(0xFFF1F5F9),
                  onPressed: () => widget.onSelectEntry(entry),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Abrir entrada',
                  onPressed: () => widget.onSelectEntry(entry),
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, entry, isSelected, onSelect) {
        final shortId =
            entry.id.length >= 8
                ? entry.id.substring(0, 8).toUpperCase()
                : entry.id.toUpperCase();
        final docInfo =
            (entry.documentNumber != null && entry.documentNumber!.isNotEmpty)
                ? '${entry.documentType}: ${entry.documentNumber}'
                : entry.documentType;
        final formattedDate =
            entry.createdAt != null
                ? dateFormat.format(entry.createdAt!)
                : (entry.documentDate != null
                    ? dateFormat.format(entry.documentDate!)
                    : '—');

        return InkWell(
          onTap: () => widget.onSelectEntry(entry),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '#$shortId',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) => onSelect(val ?? false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.supplierName ?? 'Sin proveedor',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.warehouseName ?? "Almacén general"} • $docInfo',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPaymentBadge(entry.paymentMode),
                    RichText(
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
                            text: entry.totalAmount.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
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
