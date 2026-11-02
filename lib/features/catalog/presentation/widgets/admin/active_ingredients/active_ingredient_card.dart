import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';

/// Formatea nombres de ingredientes químicos a Title Case inteligente,
/// preservando siglas técnicas cortas (ej: "PREFONOFOS" -> "Prefonofos", "NPK" -> "NPK").
String formatIngredientName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+'));
  return words
      .map((w) {
        if (w.isEmpty) return '';
        if (w.length == 1) return w.toUpperCase();
        if (w.length <= 3 &&
            w == w.toUpperCase() &&
            !RegExp(r'[0-9]').hasMatch(w)) {
          return w;
        }
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Tarjeta Pro Tool & Scientific para mostrar un componente químico.
///
/// Encapsulada con [RepaintBoundary] para aislar animaciones de hover y clics
/// sin causar invalidación de capas de renderizado en dispositivos de bajos recursos.
class ActiveIngredientCard extends StatefulWidget {
  final ActiveIngredientEntity ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ActiveIngredientCard({
    super.key,
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ActiveIngredientCard> createState() => _ActiveIngredientCardState();
}

class _ActiveIngredientCardState extends State<ActiveIngredientCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedName = formatIngredientName(widget.ingredient.name);
    final hasDesc =
        widget.ingredient.description != null &&
        widget.ingredient.description!.trim().isNotEmpty;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onEdit,
            onHighlightChanged: (val) => setState(() => _isPressed = val),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedScale(
              scale: _isPressed ? 0.985 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        _isHovered
                            ? AppColors.teal.withValues(alpha: 0.45)
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                    width: _isHovered ? 1.4 : 1.0,
                  ),
                  boxShadow:
                      _isHovered
                          ? [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : (isDark ? [] : AppColors.cardShadow(opacity: 0.025)),
                ),
                child: Row(
                  children: [
                    // Monograma / Avatar Científico
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            _isHovered
                                ? (isDark
                                    ? AppColors.tealDark.withValues(alpha: 0.3)
                                    : AppColors.tealLight)
                                : (isDark
                                    ? const Color(
                                      0xFF134E4A,
                                    ).withValues(alpha: 0.25)
                                    : const Color(0xFFF0FDFA)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _isHovered
                                  ? AppColors.teal.withValues(alpha: 0.3)
                                  : (isDark
                                      ? const Color(0xFF134E4A)
                                      : const Color(0xFFCCFBF1)),
                        ),
                      ),
                      child: Icon(
                        Icons.science_rounded,
                        color:
                            isDark ? const Color(0xFF2DD4BF) : AppColors.tealDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Información del Componente
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  formattedName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color:
                                        isDark
                                            ? const Color(0xFFF8FAFC)
                                            : AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'Activo',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? const Color(0xFF94A3B8)
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasDesc
                                ? widget.ingredient.description!
                                : 'Principio activo registrado',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  hasDesc
                                      ? (isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppColors.textSecondary)
                                      : (isDark
                                          ? const Color(0xFF64748B)
                                          : AppColors.textMuted),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Acciones Rápidas (Editar / Eliminar)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          color: AppColors.slate,
                          tooltip: 'Editar',
                          onTap: widget.onEdit,
                        ),
                        const SizedBox(width: 4),
                        _ActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          tooltip: 'Eliminar',
                          onTap: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHover = true),
        onExit: (_) => setState(() => _isHover = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  _isHover
                      ? widget.color.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}
