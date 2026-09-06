import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Componente de Paginación Adaptativo de Nivel Internacional (Stripe / Linear / Apple HIG).
///
/// Cambia de personalidad según el dispositivo:
/// - **Desktop / Tablet (>= 600dp)**: Alta densidad de información (34dp de alto),
///   resumen contextual a la izquierda ("Mostrando 1 - 8 de 34 variantes"), y controles
///   numéricos agrupados contiguamente a la derecha con cursores pointer y hover pro.
/// - **Mobile (< 600dp)**: Filosofía Apple HIG con botones táctiles ergonómicos
///   (touch targets de 44-48dp), haptic feedback y navegación ágil en el thumb zone.
class AdminPageBlocks extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  /// Número total de registros de la consulta (opcional).
  final int? totalItems;

  /// Número de registros por página (opcional, ej. 8 o 10).
  final int? itemsPerPage;

  /// Nombre del item para el resumen (opcional, ej. "variantes", "productos", "lotes").
  final String? itemName;

  /// Forzar modo compacto móvil independientemente del ancho de pantalla.
  final bool? isCompact;

  const AdminPageBlocks({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.totalItems,
    this.itemsPerPage,
    this.itemName,
    this.isCompact,
  });

  List<int?> _buildPages() {
    if (totalPages <= 1) return [0];

    final pages = <int?>[0];
    final start = (currentPage - 1) < 1 ? 1 : currentPage - 1;
    final end =
        (currentPage + 1) > (totalPages - 2)
            ? (totalPages - 2)
            : currentPage + 1;

    if (start > 1) {
      pages.add(null);
    }

    for (var i = start; i <= end; i++) {
      pages.add(i);
    }

    if (end < totalPages - 2) {
      pages.add(null);
    }

    pages.add(totalPages - 1);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 0) return const SizedBox.shrink();

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isAlt = HardwareKeyboard.instance.isAltPressed;
          if (isAlt && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (currentPage > 0) {
              onPageChanged(currentPage - 1);
              return KeyEventResult.handled;
            }
          }
          if (isAlt && event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (currentPage < totalPages - 1) {
              onPageChanged(currentPage + 1);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = isCompact ?? (constraints.maxWidth < 640);

          if (compact) {
            return _buildMobileLayout(context);
          }

          return _buildDesktopLayout(context);
        },
      ),
    );
  }

  // ── 1. PERSONALIDAD MOBILE (Apple HIG) ──
  Widget _buildMobileLayout(BuildContext context) {
    final canPrev = currentPage > 0;
    final canNext = currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Anterior
          _MobileNavButton(
            icon: Icons.chevron_left_rounded,
            label: 'Anterior',
            enabled: canPrev,
            onTap: () {
              HapticFeedback.lightImpact();
              onPageChanged(currentPage - 1);
            },
          ),

          // Indicador Central de Página
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentPage + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  ' / $totalPages',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (totalItems != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalItems',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botón Siguiente
          _MobileNavButton(
            icon: Icons.chevron_right_rounded,
            label: 'Siguiente',
            isTrailingIcon: true,
            enabled: canNext,
            onTap: () {
              HapticFeedback.lightImpact();
              onPageChanged(currentPage + 1);
            },
          ),
        ],
      ),
    );
  }

  // ── 2. PERSONALIDAD DESKTOP (Power User / Stripe & Linear) ──
  Widget _buildDesktopLayout(BuildContext context) {
    final pages = _buildPages();
    final canPrev = currentPage > 0;
    final canNext = currentPage < totalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Meta-Información Izquierda
        _buildInfoText(),

        // Clúster de Controles Agrupados (Derecha)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chevron Anterior
              _DesktopChevronButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Página anterior (Alt + ←)',
                enabled: canPrev,
                onTap: () => onPageChanged(currentPage - 1),
              ),

              const SizedBox(width: 4),

              // Botones Numéricos
              ...pages.map((page) {
                if (page == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '•••',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  );
                }

                final isSelected = page == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DesktopNumberButton(
                    pageNumber: page + 1,
                    isSelected: isSelected,
                    onTap: () => onPageChanged(page),
                  ),
                );
              }),

              const SizedBox(width: 4),

              // Chevron Siguiente
              _DesktopChevronButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Página siguiente (Alt + →)',
                enabled: canNext,
                onTap: () => onPageChanged(currentPage + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText() {
    if (totalItems != null && itemsPerPage != null && totalItems! > 0) {
      final start = (currentPage * itemsPerPage!) + 1;
      final end = math.min((currentPage + 1) * itemsPerPage!, totalItems!);
      final label = itemName ?? 'registros';

      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontFamily: 'Inter',
          ),
          children: [
            const TextSpan(text: 'Mostrando '),
            TextSpan(
              text: '$start - $end',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const TextSpan(text: ' de '),
            TextSpan(
              text: '$totalItems',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            TextSpan(text: ' $label'),
          ],
        ),
      );
    }

    return Text(
      'Página ${currentPage + 1} de $totalPages',
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBWIDGETS PRIVADOS ESPECIALIZADOS
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopNumberButton extends StatefulWidget {
  final int pageNumber;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopNumberButton({
    required this.pageNumber,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DesktopNumberButton> createState() => _DesktopNumberButtonState();
}

class _DesktopNumberButtonState extends State<_DesktopNumberButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: isSelected ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isSelected ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (_isHovered
                    ? AppColors.surfaceDark
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (_isHovered
                      ? AppColors.border
                      : Colors.transparent),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '${widget.pageNumber}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.textPrimary
                      : AppColors.textSecondary),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopChevronButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _DesktopChevronButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_DesktopChevronButton> createState() => _DesktopChevronButtonState();
}

class _DesktopChevronButtonState extends State<_DesktopChevronButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled && _isHovered
                  ? AppColors.surfaceDark
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: enabled && _isHovered
                    ? AppColors.border
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTrailingIcon;
  final bool enabled;
  final VoidCallback onTap;

  const _MobileNavButton({
    required this.icon,
    required this.label,
    this.isTrailingIcon = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppColors.border : Colors.transparent,
          ),
          boxShadow: enabled ? AppColors.cardShadow(opacity: 0.03) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailingIcon) ...[
              Icon(
                icon,
                size: 16,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            if (isTrailingIcon) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
