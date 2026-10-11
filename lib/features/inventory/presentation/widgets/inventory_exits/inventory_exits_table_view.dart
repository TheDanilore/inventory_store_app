import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';

class InventoryExitsTableView extends StatefulWidget {
  final List<InventoryExitEntity> exits;
  final InventoryExitEntity? selectedExit;
  final ValueChanged<InventoryExitEntity> onSelectExit;
  final VoidCallback? onRefresh;
  final AdminTablePaginationConfig? paginationConfig;

  const InventoryExitsTableView({
    super.key,
    required this.exits,
    required this.selectedExit,
    required this.onSelectExit,
    this.onRefresh,
    this.paginationConfig,
  });

  @override
  State<InventoryExitsTableView> createState() =>
      _InventoryExitsTableViewState();
}

class _InventoryExitsTableViewState extends State<InventoryExitsTableView> {
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

  List<InventoryExitEntity> _getSortedExits() {
    if (_sortColumnId == null) return widget.exits;
    final list = List<InventoryExitEntity>.from(widget.exits);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'id':
          cmp = a.id.compareTo(b.id);
          break;
        case 'date':
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        case 'reason':
          cmp = (a.reason ?? '').toLowerCase().compareTo((b.reason ?? '').toLowerCase());
          break;
        case 'warehouse':
          cmp = (a.warehouseName ?? '').toLowerCase().compareTo((b.warehouseName ?? '').toLowerCase());
          break;
        case 'items':
          cmp = a.itemCount.compareTo(b.itemCount);
          break;
        case 'total':
          cmp = a.totalCost.compareTo(b.totalCost);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  Widget _buildReasonBadge(String? rawReason) {
    final reason = (rawReason ?? 'AJUSTE').toUpperCase();
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (reason.contains('MERMA')) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECDD3);
      text = const Color(0xFFDC2626);
      icon = Icons.delete_outline_rounded;
    } else if (reason.contains('VENC') || reason.contains('CADUC')) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      icon = Icons.event_busy_rounded;
    } else if (reason.contains('TRASLAD') || reason.contains('TRANSFER')) {
      bg = const Color(0xFFFAF5FF);
      border = const Color(0xFFE9D5FF);
      text = const Color(0xFF7E22CE);
      icon = Icons.swap_horiz_rounded;
    } else if (reason.contains('USO') || reason.contains('INTERNO')) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF047857);
      icon = Icons.home_repair_service_outlined;
    } else {
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      text = const Color(0xFF1D4ED8);
      icon = Icons.tune_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedExits = _getSortedExits();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return AdminProTable<InventoryExitEntity>(
      items: sortedExits,
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
      onRowTap: widget.onSelectExit,
      minTableWidth: 960.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<InventoryExitEntity>(
          label: 'Copiar Códigos',
          icon: Icons.copy_rounded,
          onPressed: (selectedList) {
            final codes = selectedList
                .map((e) => e.id.length >= 8 ? '#${e.id.substring(0, 8).toUpperCase()}' : '#${e.id.toUpperCase()}')
                .join(', ');
            _copyToClipboard(context, codes, '${selectedList.length} códigos de salida');
          },
        ),
        AdminBulkAction<InventoryExitEntity>(
          label: 'Copiar Resumen de Salidas',
          icon: Icons.summarize_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            final total = selectedList.fold(0.0, (sum, e) => sum + e.totalCost);
            final summary = selectedList
                .map((e) => '- #${e.id.substring(0, 8).toUpperCase()} | Motivo: ${e.reason ?? "Ajuste"} | S/ ${e.totalCost.toStringAsFixed(2)}')
                .join('\n');
            final fullText = 'RESUMEN SALIDAS DE INVENTARIO (${selectedList.length})\n$summary\nCosto total: S/ ${total.toStringAsFixed(2)}';
            _copyToClipboard(context, fullText, 'Resumen de salidas');
          },
        ),
      ],
      columns: [
        // 1. Código
        AdminTableColumn<InventoryExitEntity>(
          id: 'id',
          label: 'CÓDIGO',
          fixedWidth: 105,
          isSortable: true,
          tooltip: 'Identificador interno de la salida',
          cellBuilder: (context, exit) {
            final shortId = exit.id.length >= 8
                ? exit.id.substring(0, 8).toUpperCase()
                : exit.id.toUpperCase();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _copyToClipboard(context, exit.id, 'Código de salida'),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              ],
            );
          },
        ),

        // 2. Fecha / Hora
        AdminTableColumn<InventoryExitEntity>(
          id: 'date',
          label: 'FECHA / HORA',
          fixedWidth: 135,
          isSortable: true,
          tooltip: 'Fecha de despacho o registro',
          cellBuilder: (context, exit) {
            final formattedDate = exit.createdAt != null
                ? dateFormat.format(exit.createdAt!)
                : '—';
            return Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),

        // 3. Motivo
        AdminTableColumn<InventoryExitEntity>(
          id: 'reason',
          label: 'MOTIVO',
          flex: 4,
          isSortable: true,
          tooltip: 'Causa o destino de la salida',
          cellBuilder: (context, exit) {
            return Align(
              alignment: Alignment.centerLeft,
              child: _buildReasonBadge(exit.reason),
            );
          },
        ),

        // 4. Almacén Origen
        AdminTableColumn<InventoryExitEntity>(
          id: 'warehouse',
          label: 'ALMACÉN ORIGEN',
          fixedWidth: 140,
          isSortable: true,
          tooltip: 'Almacén de donde se descontó el stock',
          cellBuilder: (context, exit) {
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
                    exit.warehouseName ?? 'Almacén general',
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

        // 5. Productos
        AdminTableColumn<InventoryExitEntity>(
          id: 'items',
          label: 'PRODUCTOS',
          fixedWidth: 100,
          isSortable: true,
          tooltip: 'Cantidad de líneas descontadas',
          cellBuilder: (context, exit) {
            return Text(
              '${exit.itemCount} prod.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            );
          },
        ),

        // 6. Costo Total
        AdminTableColumn<InventoryExitEntity>(
          id: 'total',
          label: 'COSTO TOTAL',
          fixedWidth: 115,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Valorización del stock retirado',
          cellBuilder: (context, exit) {
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
                      fontFamily: 'Inter',
                    ),
                  ),
                  TextSpan(
                    text: exit.totalCost.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFBE123C),
                      fontFamily: 'Inter',
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 7. Acciones
        AdminTableColumn<InventoryExitEntity>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 100,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, exit) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Ver detalle',
                  hoverColor: const Color(0xFFF1F5F9),
                  onPressed: () => widget.onSelectExit(exit),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Abrir salida',
                  onPressed: () => widget.onSelectExit(exit),
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, exit, isSelected, onSelect) {
        final shortId = exit.id.length >= 8
            ? exit.id.substring(0, 8).toUpperCase()
            : exit.id.toUpperCase();
        final formattedDate = exit.createdAt != null
            ? dateFormat.format(exit.createdAt!)
            : '—';

        return InkWell(
          onTap: () => widget.onSelectExit(exit),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
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
                Row(
                  children: [
                    _buildReasonBadge(exit.reason),
                    const SizedBox(width: 8),
                    Text(
                      '${exit.warehouseName ?? "Almacén general"} • ${exit.itemCount} prod.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Costo Retirado:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    RichText(
                      textAlign: TextAlign.end,
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'S/ ',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                          TextSpan(
                            text: exit.totalCost.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFBE123C),
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
