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
        const minTableWidth = 1000.0;
        final tableWidth =
            constraints.maxWidth < minTableWidth
                ? minTableWidth
                : constraints.maxWidth;

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Encabezado Fijo de Tabla ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            'COMPROBANTE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            'FECHA / HORA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
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
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            'ALMACÉN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 115,
                          child: Text(
                            'ORDEN COMPRA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 105,
                          child: Text(
                            'PAGO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            'TOTAL',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            'ACCIONES',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
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
                        final isSelected =
                            widget.selectedEntry?.id == entry.id;

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
                          onEnter:
                              (_) => setState(() => _hoveredId = entry.id),
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
                                        ? AppColors.tealLight.withValues(alpha: 0.45)
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
                                horizontal: 18,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  // 1. Comprobante / Entrada
                                  SizedBox(
                                    width: 120,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap:
                                              () => _copyToClipboard(
                                                context,
                                                shortId,
                                                'Código de entrada',
                                              ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: Text(
                                              '#$shortId',
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
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
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // 2. Fecha / Hora
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),

                                  // 3. Proveedor
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
                                            entry.supplierName ??
                                                'Sin proveedor',
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

                                  // 4. Almacén Destino
                                  SizedBox(
                                    width: 130,
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
                                            entry.warehouseName ??
                                                'Almacén general',
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

                                  // 5. Orden de Compra Asociada
                                  SizedBox(
                                    width: 115,
                                    child:
                                        entry.purchaseOrderId != null &&
                                                entry
                                                    .purchaseOrderId!
                                                    .isNotEmpty
                                            ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFAF5FF),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE9D5FF,
                                                  ),
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
                                                  Flexible(
                                                    child: Text(
                                                      '#${entry.purchaseOrderId!.length >= 8 ? entry.purchaseOrderId!.substring(0, 8).toUpperCase() : entry.purchaseOrderId!.toUpperCase()}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF7E22CE,
                                                        ),
                                                        fontFamily: 'monospace',
                                                      ),
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

                                  // 6. Modo de Pago
                                  SizedBox(
                                    width: 105,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildPaymentBadge(
                                        entry.paymentMode,
                                      ),
                                    ),
                                  ),

                                  // 7. Total Entrada
                                  SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 8. Acciones
                                  SizedBox(
                                    width: 110,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          tooltip: 'Ver detalle',
                                          onPressed:
                                              () => widget.onSelectEntry(entry),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 20,
                                            color:
                                                isHovered
                                                    ? AppColors.tealDark
                                                    : AppColors.textMuted,
                                          ),
                                          tooltip: 'Ver detalle',
                                          onPressed:
                                              () => widget.onSelectEntry(entry),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
