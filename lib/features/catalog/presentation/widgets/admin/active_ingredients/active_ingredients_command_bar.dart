import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra de búsqueda estilo Linear/Apple HIG con accesos rápidos.
class ActiveIngredientsSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;
  final bool showShortcut;

  const ActiveIngredientsSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
    required this.showShortcut,
  });

  @override
  State<ActiveIngredientsSearchBar> createState() =>
      _ActiveIngredientsSearchBarState();
}

class _ActiveIngredientsSearchBarState
    extends State<ActiveIngredientsSearchBar> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 44,
      decoration: BoxDecoration(
        color:
            _isFocused
                ? (isDark ? AppColors.darkSurface : AppColors.surface)
                : (isDark
                    ? AppColors.darkSurfaceElevated
                    : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _isFocused
                  ? AppColors.teal
                  : (isDark ? AppColors.darkBorder : AppColors.border),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar componente químico...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color:
                _isFocused
                    ? AppColors.tealDark
                    : (isDark ? const Color(0xFF64748B) : AppColors.textMuted),
          ),
          suffixIcon:
              widget.hasQuery
                  ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                    splashRadius: 16,
                    onPressed: widget.onClear,
                  )
                  : (widget.showShortcut
                      ? Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Ctrl K',
                                style: TextStyle(
                                  fontSize: 10.5,
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
                      )
                      : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

/// Píldora de estado minimalista que indica el total de componentes registrados.
class ActiveIngredientsCounterBadge extends StatelessWidget {
  final int count;

  const ActiveIngredientsCounterBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'componente' : 'componentes'}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
