import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

/// Header reutilizable para todos los bottom sheets del panel admin.
///
/// Incluye:
/// - Drag handle estándar
/// - Título con animación de entrada (SlideTransition + FadeTransition)
/// - Slot [trailing] para pill de estado, badge de motivo, etc.
class DetailSheetHeader extends StatefulWidget {
  final String title;

  /// Widget opcional en la esquina derecha del header (ej. _Pill de estado).
  final Widget? trailing;

  /// Padding horizontal del contenido del header. Default: 24.
  final double horizontalPadding;

  const DetailSheetHeader({
    super.key,
    required this.title,
    this.trailing,
    this.horizontalPadding = 24,
  });

  @override
  State<DetailSheetHeader> createState() => _DetailSheetHeaderState();
}

class _DetailSheetHeaderState extends State<DetailSheetHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // ── Título + trailing ─────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 12),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusPill — Badge de estado/motivo reutilizable (reemplaza al _Pill privado)
// ─────────────────────────────────────────────────────────────────────────────

/// Badge de estado compacto con punto de color e ícono opcional.
/// Diseñado para encajar en el slot [trailing] de [DetailSheetHeader].
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, // subido de 10 a 12 para cumplir WCAG
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
