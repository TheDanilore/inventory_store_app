import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';

/// Componente de Paginación Adaptativo de Nivel Internacional (Stripe / Linear / Apple HIG).
///
/// Cambia de personalidad según el dispositivo:
/// - **Desktop / Tablet (>= 640dp)**: Alta densidad de información (34dp de alto).
///   A la izquierda: Selector de registros por página ("Mostrar [ 10 ⌄ ] de 1,240 productos").
///   A la derecha: Controles numéricos y chevrons independientes sin clúster gris encerrado,
///   con botón activo sólido de alto contraste y hover sutil sin superposición de sombras.
/// - **Mobile (< 640dp)**: Filosofía Apple HIG con botones táctiles ergonómicos
///   (touch targets de 44dp), haptic feedback e indicador numérico central ("1 / 3 • 57").
class AdminPageBlocks extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  /// Número total de registros de la consulta (opcional).
  final int? totalItems;

  /// Número de registros por página (opcional, ej. 10, 20, 24).
  final int? itemsPerPage;

  /// Lista de opciones para el selector de registros por página.
  final List<int> availableItemsPerPage;

  /// Callback cuando el usuario cambia el número de registros por página.
  final ValueChanged<int>? onItemsPerPageChanged;

  /// Nombre del item para el resumen (opcional, ej. "productos", "órdenes", "variantes").
  final String? itemName;

  /// Forzar modo compacto móvil independientemente del ancho de pantalla.
  final bool? isCompact;

  /// Si es true, el componente siempre se visualiza incluso si solo hay 1 página.
  final bool alwaysShow;

  const AdminPageBlocks({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.totalItems,
    this.itemsPerPage,
    this.availableItemsPerPage = const [10, 20, 24, 50, 100],
    this.onItemsPerPageChanged,
    this.itemName,
    this.isCompact,
    this.alwaysShow = true,
  });

  static String formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  List<int?> _buildPages(int effectiveTotalPages, int effectiveCurrentPage) {
    if (effectiveTotalPages <= 1) return [0];
    if (effectiveTotalPages <= 7) {
      return List.generate(effectiveTotalPages, (i) => i);
    }

    final pages = <int?>[0];
    final start = (effectiveCurrentPage - 1) < 1 ? 1 : effectiveCurrentPage - 1;
    final end =
        (effectiveCurrentPage + 1) > (effectiveTotalPages - 2)
            ? (effectiveTotalPages - 2)
            : effectiveCurrentPage + 1;

    if (start > 1) {
      pages.add(null);
    }

    for (var i = start; i <= end; i++) {
      pages.add(i);
    }

    if (end < effectiveTotalPages - 2) {
      pages.add(null);
    }

    pages.add(effectiveTotalPages - 1);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTotalPages = math.max(1, totalPages);
    final effectiveCurrentPage = currentPage.clamp(0, effectiveTotalPages - 1);

    if (!alwaysShow &&
        totalPages <= 0 &&
        (totalItems == null || totalItems == 0)) {
      return const SizedBox.shrink();
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isAlt = HardwareKeyboard.instance.isAltPressed;
          final isControl = HardwareKeyboard.instance.isControlPressed;
          final isMeta = HardwareKeyboard.instance.isMetaPressed;
          final isModifier = isAlt || isControl || isMeta;
          if (isModifier && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (effectiveCurrentPage > 0) {
              onPageChanged(effectiveCurrentPage - 1);
              return KeyEventResult.handled;
            }
          }
          if (isModifier && event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (effectiveCurrentPage < effectiveTotalPages - 1) {
              onPageChanged(effectiveCurrentPage + 1);
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
            return _buildMobileLayout(
              context,
              effectiveTotalPages: effectiveTotalPages,
              effectiveCurrentPage: effectiveCurrentPage,
            );
          }

          return _buildDesktopLayout(
            context,
            effectiveTotalPages: effectiveTotalPages,
            effectiveCurrentPage: effectiveCurrentPage,
          );
        },
      ),
    );
  }

  // ── 1. PERSONALIDAD MOBILE (Apple HIG) ──
  Widget _buildMobileLayout(
    BuildContext context, {
    required int effectiveTotalPages,
    required int effectiveCurrentPage,
  }) {
    final canPrev = effectiveCurrentPage > 0;
    final canNext = effectiveCurrentPage < effectiveTotalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              onPageChanged(effectiveCurrentPage - 1);
            },
          ),

          // Indicador Central de Página (1 / 3 • 57)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${effectiveCurrentPage + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' / $effectiveTotalPages',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (totalItems != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 3.5,
                    height: 3.5,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatNumber(totalItems!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
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
              onPageChanged(effectiveCurrentPage + 1);
            },
          ),
        ],
      ),
    );
  }

  // ── 2. PERSONALIDAD DESKTOP (Stripe & Linear Reference) ──
  Widget _buildDesktopLayout(
    BuildContext context, {
    required int effectiveTotalPages,
    required int effectiveCurrentPage,
  }) {
    final pages = _buildPages(effectiveTotalPages, effectiveCurrentPage);
    final canPrev = effectiveCurrentPage > 0;
    final canNext = effectiveCurrentPage < effectiveTotalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Meta-Información Izquierda: "Mostrar [ 10 ⌄ ] de 1,240 productos"
        _buildLeftInfo(context, effectiveTotalPages, effectiveCurrentPage),

        // Controles de Navegación Independientes (Derecha)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chevron Anterior
            _DesktopChevronButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Página anterior (${AppShortcutLabels.modPlus}←)',
              enabled: canPrev,
              onTap: () => onPageChanged(effectiveCurrentPage - 1),
            ),

            const SizedBox(width: 4),

            // Botones Numéricos individuales (sin contenedor gris envolvente)
            ...pages.map((page) {
              if (page == null) {
                return const SizedBox(
                  width: 32,
                  height: 34,
                  child: Center(
                    child: Text(
                      '•••',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                );
              }

              final isSelected = page == effectiveCurrentPage;
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
              tooltip: 'Página siguiente (${AppShortcutLabels.modPlus}→)',
              enabled: canNext,
              onTap: () => onPageChanged(effectiveCurrentPage + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftInfo(
    BuildContext context,
    int effectiveTotalPages,
    int effectiveCurrentPage,
  ) {
    final label = itemName ?? 'resultados';
    final currentSize = itemsPerPage ?? 10;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Mostrar',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),

        // Selector / Dropdown de Items por Página
        _buildItemsPerPageDropdown(context, currentSize),

        const SizedBox(width: 8),
        const Text(
          'de',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),

        if (totalItems != null) ...[
          Text(
            formatNumber(totalItems!),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Text(
            'página ${effectiveCurrentPage + 1} de $effectiveTotalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemsPerPageDropdown(BuildContext context, int currentSize) {
    final options =
        availableItemsPerPage.contains(currentSize)
            ? availableItemsPerPage
            : ([currentSize, ...availableItemsPerPage]..sort());

    final dropdownChild = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$currentSize',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );

    if (onItemsPerPageChanged == null) {
      return dropdownChild;
    }

    return PopupMenuButton<int>(
      initialValue: currentSize,
      tooltip: 'Elementos por página',
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 4,
      color: Colors.white,
      onSelected: (val) {
        if (val != currentSize) {
          onItemsPerPageChanged!(val);
        }
      },
      itemBuilder: (context) {
        return options.map((opt) {
          final isSelected = opt == currentSize;
          return PopupMenuItem<int>(
            value: opt,
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$opt $itemName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected
                            ? AppColors.primary
                            : const Color(0xFF1E293B),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: dropdownChild,
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
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary
                    : (_isHovered
                        ? const Color(0xFFF1F5F9)
                        : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            boxShadow:
                isSelected
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
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color:
                  isSelected
                      ? Colors.white
                      : (_isHovered
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF475569)),
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
            duration: const Duration(milliseconds: 140),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  enabled && _isHovered
                      ? const Color(0xFFF1F5F9)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color:
                  enabled
                      ? (_isHovered
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF475569))
                      : const Color(0xFFCBD5E1),
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
