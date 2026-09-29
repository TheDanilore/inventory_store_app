import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

/// Tarjeta responsiva de Almacén para Móvil, Tablet y Grid View.
/// Cumple con las directrices de Apple HIG y área táctil mínima de 48x48dp.
class WarehouseCard extends StatelessWidget {
  final WarehouseEntity warehouse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleStatus;

  const WarehouseCard({
    super.key,
    required this.warehouse,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final wh = warehouse;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          hoverColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila Superior: Ícono + Nombre + Badge ─────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            wh.isActive
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              wh.isActive
                                  ? AppColors.primary.withValues(alpha: 0.16)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.store_mall_directory_rounded,
                        color:
                            wh.isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                        size: 22,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
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
                    const SizedBox(width: 8),
                    _CardStatusBadge(
                      isActive: wh.isActive,
                      onTap: () => onToggleStatus(!wh.isActive),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Ubicación / Dirección ─────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color:
                            wh.address?.isNotEmpty == true
                                ? AppColors.primary
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
                            fontSize: 12,
                            color:
                                wh.address?.isNotEmpty == true
                                    ? AppColors.textPrimary
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

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // ── Footer: Switch Activo + Botones Editar/Borrar ──────
                Row(
                  children: [
                    // Switch de estado con target táctil adecuado
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: wh.isActive,
                            onChanged: onToggleStatus,
                            activeThumbColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wh.isActive ? 'Operativo' : 'Inactivo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                wh.isActive
                                    ? AppColors.successDark
                                    : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Botón Editar (>= 48x48dp touch target)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 19),
                        tooltip: 'Editar almacén',
                        color: AppColors.textSecondary,
                        onPressed: onEdit,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          hoverColor: AppColors.primaryLight.withValues(
                            alpha: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón Eliminar (>= 48x48dp touch target)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                        ),
                        tooltip: 'Eliminar almacén',
                        color: AppColors.error,
                        onPressed: onDelete,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorLight.withValues(
                            alpha: 0.35,
                          ),
                          hoverColor: AppColors.errorLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardStatusBadge extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CardStatusBadge({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.successLight.withValues(alpha: 0.6)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive
                    ? AppColors.success.withValues(alpha: 0.3)
                    : const Color(0xFFCBD5E1),
          ),
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
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: isActive ? AppColors.successDark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
