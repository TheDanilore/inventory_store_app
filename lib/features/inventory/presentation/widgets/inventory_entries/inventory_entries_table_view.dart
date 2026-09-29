import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';

class InventoryEntriesTableView extends StatefulWidget {
  final List<InventoryEntryEntity> entries;
  final InventoryEntryEntity? selectedEntry;
  final ValueChanged<InventoryEntryEntity> onSelectEntry;
  final VoidCallback? onRefresh;

  const InventoryEntriesTableView({
    super.key,
    required this.entries,
    required this.selectedEntry,
    required this.onSelectEntry,
    this.onRefresh,
  });

  @override
  State<InventoryEntriesTableView> createState() =>
      _InventoryEntriesTableViewState();
}

class _InventoryEntriesTableViewState extends State<InventoryEntriesTableView> {
  String? _hoveredId;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  Widget _buildPaymentBadge(String? paymentMode) {
    final mode = (paymentMode ?? 'CONTADO').toUpperCase();
    final isCredit = mode.contains('CREDIT') || mode.contains('CRÉDITO');

    final bg = isCredit ? const Color(0xFFEFF6FF) : AppColors.successLight;
    final text = isCredit ? const Color(0xFF1D4ED8) : AppColors.successDark;
    final label = isCredit ? 'Crédito' : 'Contado';
    final icon =
        isCredit ? Icons.credit_card_rounded : Icons.payments_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 980.0;
        final needsScroll = constraints.maxWidth < minTableWidth;

        final tableContent = SizedBox(
          width: needsScroll ? minTableWidth : constraints.maxWidth,
          child: Column(
            children: [
              // --- Encabezado Fijo de Tabla ---
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'COMPROBANTE / ENTRADA',
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
                        'PROVEEDOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ALMACÉN DESTINO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ORDEN COMPRA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'PAGO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'TOTAL ENTRADA',
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
                        textAlign: TextAlign.center,
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
              Expanded(
                child: ListView.separated(
                  itemCount: widget.entries.length,
                  separatorBuilder:
                      (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE2E8F0),
                      ),
                  itemBuilder: (context, index) {
                    final entry = widget.entries[index];
                    final isHovered = _hoveredId == entry.id;
                    final isSelected = widget.selectedEntry?.id == entry.id;

                    final shortId =
                        entry.id.length >= 8
                            ? entry.id.substring(0, 8).toUpperCase()
                            : entry.id.toUpperCase();

                    final docInfo =
                        (entry.documentNumber != null &&
                                entry.documentNumber!.isNotEmpty)
                            ? '${entry.documentType}: ${entry.documentNumber}'
                            : entry.documentType;

                    final formattedDate =
                        entry.createdAt != null
                            ? dateFormat.format(entry.createdAt!)
                            : (entry.documentDate != null
                                ? dateFormat.format(entry.documentDate!)
                                : '—');

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredId = entry.id),
                      onExit: (_) => setState(() => _hoveredId = null),
                      child: InkWell(
                        onTap: () => widget.onSelectEntry(entry),
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.teal.withValues(alpha: 0.06)
                                    : (isHovered
                                        ? const Color(0xFFF8FAFC)
                                        : Colors.white),
                            border: Border(
                              left: BorderSide(
                                color:
                                    isSelected
                                        ? AppColors.teal
                                        : Colors.transparent,
                                width: 3.5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // 1. Comprobante / Entrada
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '#$shortId',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap:
                                              () => _copyToClipboard(
                                                context,
                                                entry.id,
                                                'Código de entrada',
                                              ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 13,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$docInfo • $formattedDate',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Proveedor
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
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
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 3. Almacén Destino
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.storefront_rounded,
                                      size: 14,
                                      color: AppColors.textMuted,
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
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 4. Orden de Compra Asociada
                              Expanded(
                                flex: 3,
                                child:
                                    entry.purchaseOrderId != null &&
                                            entry.purchaseOrderId!.isNotEmpty
                                        ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF5FF),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFE9D5FF),
                                            ),
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
                                              Text(
                                                '#${entry.purchaseOrderId!.length >= 8 ? entry.purchaseOrderId!.substring(0, 8).toUpperCase() : entry.purchaseOrderId!.toUpperCase()}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF7E22CE),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : const Text(
                                          '—',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                              ),

                              // 5. Modo de Pago
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildPaymentBadge(entry.paymentMode),
                                ),
                              ),

                              // 6. Total Entrada
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 7. Acciones
                              SizedBox(
                                width: 100,
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => widget.onSelectEntry(entry),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                      Icons.visibility_rounded,
                                      size: 14,
                                      color: AppColors.tealDark,
                                    ),
                                    label: const Text(
                                      'Detalle',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableContent,
          );
        }

        return tableContent;
      },
    );
  }
}
