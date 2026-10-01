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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 920.0;
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
                          width: 100,
                          child: Text(
                            'CÓDIGO',
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
                            'MOTIVO',
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
                            'ALMACÉN ORIGEN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'PRODUCTOS',
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
                            'COSTO TOTAL',
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
                                  // 1. Código
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _copyToClipboard(
                                            context,
                                            exit.id,
                                            'Código de salida',
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
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
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // 3. Motivo
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildReasonBadge(exit.reason),
                                    ),
                                  ),

                                  // 4. Almacén Origen
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
                                            exit.warehouseName ??
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

                                  // 5. Productos
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${exit.itemCount} prod.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),

                                  // 6. Costo Total
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      'S/ ${exit.totalCost.toStringAsFixed(2)}',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.dangerDark,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 7. Acciones
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
                                              () => widget.onSelectExit(exit),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color:
                                                isSelected
                                                    ? AppColors.teal
                                                    : AppColors.textMuted,
                                          ),
                                          tooltip: 'Seleccionar',
                                          onPressed:
                                              () => widget.onSelectExit(exit),
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
