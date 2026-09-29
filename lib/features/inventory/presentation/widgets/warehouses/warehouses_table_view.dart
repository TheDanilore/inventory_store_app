import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

/// Tabla Pro de nivel empresarial para Almacenes en Desktop.
/// Implementa aislamiento de hover a nivel de fila y colores 100% seguros frente
/// al error de interpolación lerp de Flutter Web.
class WarehousesTableView extends StatelessWidget {
  final List<WarehouseEntity> warehouses;
  final ValueChanged<WarehouseEntity> onEdit;
  final ValueChanged<WarehouseEntity> onDelete;
  final void Function(WarehouseEntity warehouse, bool newStatus) onToggleStatus;

  const WarehousesTableView({
    super.key,
    required this.warehouses,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 840.0;
          final tableWidth =
              constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Cabecera Fija Pro ──────────────────────────────────
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'ALMACÉN / SUCURSAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            'DIRECCIÓN / UBICACIÓN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Text(
                            'ESTADO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'ACCIONES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Filas de Almacén ─────────────────────────────────
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: warehouses.length,
                    separatorBuilder:
                        (context, index) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                    itemBuilder: (context, index) {
                      final wh = warehouses[index];
                      return _WarehouseTableRow(
                        key: ValueKey(wh.id),
                        warehouse: wh,
                        onEdit: () => onEdit(wh),
                        onDelete: () => onDelete(wh),
                        onToggleStatus: (val) => onToggleStatus(wh, val),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fila individual con aislamiento local de hover para 60fps constantes
class _WarehouseTableRow extends StatefulWidget {
  final WarehouseEntity warehouse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleStatus;

  const _WarehouseTableRow({
    super.key,
    required this.warehouse,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  State<_WarehouseTableRow> createState() => _WarehouseTableRowState();
}

class _WarehouseTableRowState extends State<_WarehouseTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final wh = widget.warehouse;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        color: _isHovered ? const Color(0xFFF8FAFC) : const Color(0xFFFFFFFF),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onEdit,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // --- Columna: Nombre & Ícono ---
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color:
                                wh.isActive
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  wh.isActive
                                      ? AppColors.primary.withValues(
                                        alpha: 0.16,
                                      )
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.store_mall_directory_rounded,
                            color:
                                wh.isActive
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wh.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: #${wh.id.length > 8 ? wh.id.substring(0, 8).toUpperCase() : wh.id.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Columna: Dirección ---
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color:
                              wh.address?.isNotEmpty == true
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            wh.address?.isNotEmpty == true
                                ? wh.address!
                                : 'Sin dirección registrada',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  wh.address?.isNotEmpty == true
                                      ? AppColors.textSecondary
                                      : AppColors.textMuted,
                              fontStyle:
                                  wh.address?.isNotEmpty == true
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Columna: Estado Interactivo ---
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        _StatusPill(
                          isActive: wh.isActive,
                          onTap: () => widget.onToggleStatus(!wh.isActive),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.82,
                          child: Switch(
                            value: wh.isActive,
                            onChanged: widget.onToggleStatus,
                            activeThumbColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Columna: Acciones ---
                  SizedBox(
                    width: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar almacén',
                          color: AppColors.textSecondary,
                          onPressed: widget.onEdit,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            hoverColor: AppColors.primaryLight.withValues(
                              alpha: 0.5,
                            ),
                            padding: const EdgeInsets.all(7),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          tooltip: 'Eliminar almacén',
                          color: AppColors.error,
                          onPressed: widget.onDelete,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.errorLight.withValues(
                              alpha: 0.35,
                            ),
                            hoverColor: AppColors.errorLight,
                            padding: const EdgeInsets.all(7),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _StatusPill({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isActive
            ? AppColors.successLight.withValues(alpha: 0.5)
            : const Color(0xFFF1F5F9);
    final fgColor = isActive ? AppColors.successDark : AppColors.textMuted;
    final borderColor =
        isActive
            ? AppColors.success.withValues(alpha: 0.3)
            : const Color(0xFFCBD5E1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              isActive ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
