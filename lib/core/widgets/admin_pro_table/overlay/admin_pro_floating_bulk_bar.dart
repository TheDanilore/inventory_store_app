import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Acción para la barra flotante de selección.
class AdminBulkBarActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? color;

  const AdminBulkBarActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.color,
  });
}

class _BarInsets {
  final double left;
  final double right;
  const _BarInsets(this.left, this.right);

  bool closeTo(_BarInsets o) =>
      (left - o.left).abs() < 0.5 && (right - o.right).abs() < 0.5;
}

/// Barra flotante de selección en lote (Overlay).
/// Optimizada sin ticker continuo de vsync: reacciona únicamente ante cambios
/// de visibilidad, redimensionamiento de pantalla y layout bajo demanda.
class AdminProFloatingBulkBar extends StatefulWidget {
  final bool visible;
  final int count;
  final int pageCount;
  final GlobalKey anchorKey;
  final List<AdminBulkBarActionItem> actions;
  final VoidCallback onClear;
  final VoidCallback? onSelectPage;

  const AdminProFloatingBulkBar({
    super.key,
    required this.visible,
    required this.count,
    required this.pageCount,
    required this.anchorKey,
    required this.actions,
    required this.onClear,
    this.onSelectPage,
  });

  @override
  State<AdminProFloatingBulkBar> createState() => _AdminProFloatingBulkBarState();
}

class _AdminProFloatingBulkBarState extends State<AdminProFloatingBulkBar>
    with WidgetsBindingObserver {
  _BarInsets? _insets;
  int _shownCount = 0;

  @override
  void initState() {
    super.initState();
    _shownCount = widget.count;
    WidgetsBinding.instance.addObserver(this);
    if (widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMeasure());
    }
  }

  @override
  void didChangeMetrics() {
    if (widget.visible && mounted) {
      _updateMeasure();
    }
  }

  @override
  void didUpdateWidget(covariant AdminProFloatingBulkBar old) {
    super.didUpdateWidget(old);
    if (widget.count > 0) _shownCount = widget.count;
    if (widget.visible && (!old.visible || old.count != widget.count)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateMeasure();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateMeasure() {
    final m = _measure();
    if (m != null && (_insets == null || !m.closeTo(_insets!))) {
      setState(() => _insets = m);
    }
  }

  /// Distancia (en coordenadas del Overlay) entre los bordes de la tabla y los del Overlay.
  _BarInsets? _measure() {
    final anchor = widget.anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (anchor is! RenderBox ||
        overlay is! RenderBox ||
        !anchor.attached ||
        !overlay.attached ||
        !anchor.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final left = topLeft.dx.clamp(0.0, overlay.size.width);
    final right = (overlay.size.width - (topLeft.dx + anchor.size.width)).clamp(
      0.0,
      overlay.size.width,
    );
    return _BarInsets(left, right);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count > 0) _shownCount = widget.count;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final insets = _insets ?? _measure() ?? const _BarInsets(0, 0);
    final available = (screenWidth - insets.left - insets.right).clamp(
      280.0,
      screenWidth,
    );
    final compact = available < 720;
    final bottom = 24.0 + MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: insets.left,
        right: insets.right,
        bottom: bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: AnimatedSlide(
            duration: Duration(milliseconds: widget.visible ? 280 : 180),
            curve: widget.visible ? Curves.easeOutCubic : Curves.easeInCubic,
            offset: widget.visible ? Offset.zero : const Offset(0, 0.8),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: widget.visible ? 220 : 140),
              curve: Curves.easeOut,
              opacity: widget.visible ? 1 : 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: available - 32),
                child: _buildBar(compact),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(bool compact) {
    const slate = Color(0xFF334155);

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 1,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: slate, width: 1.1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _countPill(),
                    if (!compact && widget.onSelectPage != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: widget.onSelectPage,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF93C5FD),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text('Seleccionar todos (${widget.pageCount})'),
                      ),
                    ],
                    if (widget.actions.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        height: 22,
                        child: VerticalDivider(color: slate, thickness: 1.1),
                      ),
                      const SizedBox(width: 6),
                    ],
                    for (final a in widget.actions) ...[
                      _actionButton(a, compact),
                      const SizedBox(width: 2),
                    ],
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Deseleccionar todo (Esc)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        hoverColor: Colors.white.withValues(alpha: 0.10),
                        onTap: widget.onClear,
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
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

  Widget _countPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: Color(0xFF60A5FA),
          ),
          const SizedBox(width: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder:
                (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
            child: Text(
              '$_shownCount',
              key: ValueKey(_shownCount),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _shownCount == 1 ? 'seleccionado' : 'seleccionados',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(AdminBulkBarActionItem a, bool compact) {
    final color =
        a.isDestructive ? const Color(0xFFFCA5A5) : (a.color ?? Colors.white);

    final button = InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: a.onTap,
      hoverColor: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 16, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                a.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return compact ? Tooltip(message: a.label, child: button) : button;
  }
}

