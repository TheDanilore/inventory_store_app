import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/core/widgets/adaptive_surface_card.dart';
import 'package:inventory_store_app/core/widgets/hover_shortcut_tooltip.dart';

/// Selector rápido de apariencia (Claro / Oscuro / Sistema) integrado en Perfil.
/// Dispara la transición circular [ThemeCircularWave] desde el botón seleccionado.
class ProfileAppearanceCard extends StatelessWidget {
  final bool compact;

  const ProfileAppearanceCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final disableAnimations = MediaQuery.disableAnimationsOf(context);
        final isDark = AppColors.isDark(context);

        return AdaptiveSurfaceCard(
          padding: EdgeInsets.all(compact ? 14 : 16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary(
                        context,
                      ).withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 16,
                      color: AppColors.brandPrimarySoft(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apariencia',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.txtPrimary(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          themeMode == ThemeMode.system
                              ? 'Sincronizado con el dispositivo'
                              : (themeMode == ThemeMode.dark
                                  ? 'Modo oscuro ejecutivo activo'
                                  : 'Modo claro activo'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.txtMuted(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HoverShortcutTooltip(
                message: 'Alternar claro / oscuro',
                shortcut: 'T',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfSubtle(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.brd(context)),
                  ),
                  child: Row(
                    children: [
                      _ThemeOptionSegment(
                        label: 'Claro',
                        icon: Icons.light_mode_rounded,
                        selected: themeMode == ThemeMode.light,
                        disableAnimations: disableAnimations,
                        onSelect:
                            (origin) => _applyTheme(
                              context,
                              ThemeMode.light,
                              origin,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _ThemeOptionSegment(
                        label: 'Oscuro',
                        icon: Icons.dark_mode_rounded,
                        selected: themeMode == ThemeMode.dark,
                        disableAnimations: disableAnimations,
                        onSelect:
                            (origin) => _applyTheme(
                              context,
                              ThemeMode.dark,
                              origin,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _ThemeOptionSegment(
                        label: 'Sistema',
                        icon: Icons.brightness_auto_rounded,
                        selected: themeMode == ThemeMode.system,
                        disableAnimations: disableAnimations,
                        onSelect:
                            (origin) => _applyTheme(
                              context,
                              ThemeMode.system,
                              origin,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyTheme(BuildContext context, ThemeMode mode, Offset? origin) {
    AppFeedbackService.selectionClick();
    ThemeCircularWave.switchTheme(context, origin: origin, targetMode: mode);
  }
}

class _ThemeOptionSegment extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool disableAnimations;
  final ValueChanged<Offset?> onSelect;

  const _ThemeOptionSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.disableAnimations,
    required this.onSelect,
  });

  @override
  State<_ThemeOptionSegment> createState() => _ThemeOptionSegmentState();
}

class _ThemeOptionSegmentState extends State<_ThemeOptionSegment> {
  bool _hovered = false;
  bool _pressed = false;

  void _triggerTap() {
    final renderBox = context.findRenderObject() as RenderBox?;
    Offset? origin;
    if (renderBox != null && renderBox.hasSize) {
      origin = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    }
    widget.onSelect(origin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final selectedBg =
        isDark ? AppColors.darkSurfaceHighlight : AppColors.surface;
    final bgColor =
        widget.selected
            ? selectedBg
            : (_hovered ? AppColors.surfHover(context) : Colors.transparent);

    final fgColor =
        widget.selected
            ? AppColors.brandPrimarySoft(context)
            : (_hovered
                ? AppColors.txtPrimary(context)
                : AppColors.txtSecondary(context));

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _triggerTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration:
                widget.disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration:
                  widget.disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.selected
                          ? (isDark
                              ? AppColors.darkBorderSubtle
                              : AppColors.border)
                          : Colors.transparent,
                ),
                boxShadow:
                    (widget.selected && !isDark)
                        ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 15, color: fgColor),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            widget.selected ? FontWeight.w700 : FontWeight.w500,
                        color: fgColor,
                      ),
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
