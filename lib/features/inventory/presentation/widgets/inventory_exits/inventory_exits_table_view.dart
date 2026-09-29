import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';

class InventoryExitsTableView extends StatefulWidget {
  final List<InventoryExitEntity> exits;
  final InventoryExitEntity? selectedExit;
  final ValueChanged<InventoryExitEntity> onSelectExit;
  final VoidCallback? onRefresh;

  const InventoryExitsTableView({
    super.key,
    required this.exits,
    required this.selectedExit,
    required this.onSelectExit,
    this.onRefresh,
  });

  @override
  State<InventoryExitsTableView> createState() =>
      _InventoryExitsTableViewState();
}

class _InventoryExitsTableViewState extends State<InventoryExitsTableView> {
  String? _hoveredId;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  Widget _buildReasonBadge(String? rawReason) {
    final reason = (rawReason ?? 'AJUSTE').toUpperCase();
    Color bg;
    Color text;
    IconData icon;

    if (reason.contains('MERMA')) {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
      icon = Icons.delete_outline_rounded;
    } else if (reason.contains('VENC') || reason.contains('CADUC')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
      icon = Icons.event_busy_rounded;
    } else if (reason.contains('TRASLAD') || reason.contains('TRANSFER')) {
      bg = const Color(0xFFFAF5FF);
      text = const Color(0xFF7E22CE);
      icon = Icons.swap_horiz_rounded;
    } else if (reason.contains('USO') || reason.contains('INTERNO')) {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF15803D);
      icon = Icons.home_repair_service_outlined;
    } else {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
      icon = Icons.tune_rounded;
    }

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
            reason,
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
        const minTableWidth = 880.0;
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
                        'CÓDIGO / SALIDA',
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
                        'MOTIVO',
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
                        'ALMACÉN ORIGEN',
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
                        'PRODUCTOS',
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
                        'COSTO DE SALIDA',
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
                        'FECHA Y HORA',
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
                  itemCount: widget.exits.length,
                  separatorBuilder:
                      (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE2E8F0),
                      ),
                  itemBuilder: (context, index) {
                    final exit = widget.exits[index];
                    final isHovered = _hoveredId == exit.id;
                    final isSelected = widget.selectedExit?.id == exit.id;

                    final shortId =
                        exit.id.length >= 8
                            ? exit.id.substring(0, 8).toUpperCase()
                            : exit.id.toUpperCase();

                    final formattedDate =
                        exit.createdAt != null
                            ? dateFormat.format(exit.createdAt!)
                            : '—';

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredId = exit.id),
                      onExit: (_) => setState(() => _hoveredId = null),
                      child: InkWell(
                        onTap: () => widget.onSelectExit(exit),
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
                              // 1. Código / Salida
                              Expanded(
                                flex: 4,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                          Icons.outbox_rounded,
                                          size: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                            exit.id,
                                            'Código de salida',
                                          ),
                                      borderRadius: BorderRadius.circular(4),
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
                              ),

                              // 2. Motivo
                              Expanded(
                                flex: 3,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildReasonBadge(exit.reason),
                                ),
                              ),

                              // 3. Almacén Origen
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
                                        exit.warehouseName ?? 'Almacén general',
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

                              // 4. Productos
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${exit.itemCount} prod.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),

                              // 5. Costo Total
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'S/ ${exit.totalCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dangerDark,
                                  ),
                                ),
                              ),

                              // 6. Fecha y Hora
                              Expanded(
                                flex: 3,
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // 7. Acciones
                              SizedBox(
                                width: 100,
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: () => widget.onSelectExit(exit),
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
