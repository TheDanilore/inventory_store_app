import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

enum SnackbarType { success, error, warning, info }

class _SnackbarModel {
  final String id;
  final String message;
  final SnackbarType type;
  final Color backgroundColor;
  final IconData iconData;
  final Duration duration;

  _SnackbarModel({
    required this.id,
    required this.message,
    required this.type,
    required this.backgroundColor,
    required this.iconData,
    required this.duration,
  });
}

class AppSnackbar {
  static OverlayEntry? _overlayEntry;
  static final List<_SnackbarModel> _queue = [];
  static final GlobalKey<_SnackbarStackWidgetState> _stackKey =
      GlobalKey<_SnackbarStackWidgetState>();

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Mantenemos tus colores e iconos originales intactos
    final resolvedBackgroundColor =
        backgroundColor ??
        switch (type) {
          SnackbarType.success => AppColors.success,
          SnackbarType.error => AppColors.accent,
          SnackbarType.warning => AppColors.warning,
          SnackbarType.info => AppColors.info,
        };

    final IconData iconData = switch (type) {
      SnackbarType.success => Icons.check_circle_outline_rounded,
      SnackbarType.error || SnackbarType.warning => Icons.warning_amber_rounded,
      SnackbarType.info => Icons.info_outline_rounded,
    };

    final newSnackbar = _SnackbarModel(
      id: UniqueKey().toString(),
      message: message,
      type: type,
      backgroundColor: resolvedBackgroundColor,
      iconData: iconData,
      duration: duration,
    );

    // Vibración eliminada por auditoría UX para reducir estrés

    // Insertamos al inicio para que la más nueva tome la posición frontal
    _queue.insert(0, newSnackbar);

    final overlayState = Overlay.of(context);

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          return _SnackbarStackWidget(
            key: _stackKey,
            items: _queue,
            onRemove: (id) => _removeItem(id),
          );
        },
      );
      overlayState.insert(_overlayEntry!);
    } else {
      _stackKey.currentState?.refresh();
    }
  }

  static void _removeItem(String id) {
    _queue.removeWhere((element) => element.id == id);
    if (_queue.isEmpty) {
      dismiss();
    } else {
      _stackKey.currentState?.refresh();
    }
  }

  static void dismiss() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _queue.clear();
    }
  }

  /// Variante que usa [ScaffoldMessengerState] capturado antes del await
  /// para evitar el warning use_build_context_synchronously.
  static void showMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final resolvedBackgroundColor =
        backgroundColor ??
        switch (type) {
          SnackbarType.success => AppColors.success,
          SnackbarType.error => AppColors.accent,
          SnackbarType.warning => AppColors.warning,
          SnackbarType.info => AppColors.info,
        };

    final IconData iconData = switch (type) {
      SnackbarType.success => Icons.check_circle_outline_rounded,
      SnackbarType.error || SnackbarType.warning => Icons.warning_amber_rounded,
      SnackbarType.info => Icons.info_outline_rounded,
    };

    final newSnackbar = _SnackbarModel(
      id: UniqueKey().toString(),
      message: message,
      type: type,
      backgroundColor: resolvedBackgroundColor,
      iconData: iconData,
      duration: duration,
    );

    _queue.insert(0, newSnackbar);

    final overlayState = messenger.context
        .findAncestorStateOfType<OverlayState>();
    if (overlayState == null) return;

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          return _SnackbarStackWidget(
            key: _stackKey,
            items: _queue,
            onRemove: (id) => _removeItem(id),
          );
        },
      );
      overlayState.insert(_overlayEntry!);
    } else {
      _stackKey.currentState?.refresh();
    }
  }
}

// Contenedor que usa Positioned tradicional (Garantiza que SIEMPRE aparezca en pantalla)
class _SnackbarStackWidget extends StatefulWidget {
  final List<_SnackbarModel> items;
  final Function(String) onRemove;

  const _SnackbarStackWidget({
    super.key,
    required this.items,
    required this.onRemove,
  });

  @override
  State<_SnackbarStackWidget> createState() => _SnackbarStackWidgetState();
}

class _SnackbarStackWidgetState extends State<_SnackbarStackWidget> {
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Tomamos máximo 3 para el efecto visual de capas
    final visibleItems = widget.items.take(3).toList();

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          // Renderizamos al revés para que la tarjeta activa (index 0) dibuje encima de las viejas
          children:
              visibleItems.reversed.map((item) {
                final index = visibleItems.indexOf(item);
                return _AnimatedSnackbarWidget(
                  key: ValueKey(item.id),
                  item: item,
                  index: index,
                  onDismissed: () => widget.onRemove(item.id),
                );
              }).toList(),
        ),
      ),
    );
  }
}

class _AnimatedSnackbarWidget extends StatefulWidget {
  final _SnackbarModel item;
  final int index; // 0 = Frente, 1 = Capa intermedia, 2 = Capa del fondo
  final VoidCallback onDismissed;

  const _AnimatedSnackbarWidget({
    super.key,
    required this.item,
    required this.index,
    required this.onDismissed,
  });

  @override
  State<_AnimatedSnackbarWidget> createState() =>
      _AnimatedSnackbarWidgetState();
}

class _AnimatedSnackbarWidgetState extends State<_AnimatedSnackbarWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isDismissedBySwipe = false;
  bool _isBeingPressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: widget.item.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _startAutoDismissTimer(widget.item.duration);
  }

  void _startAutoDismissTimer(Duration duration) {
    if (widget.index == 0) {
      _progressController.duration = duration;
      _progressController.reverse(from: _progressController.value == 0 ? 1.0 : _progressController.value).then((_) async {
        if (mounted && !_isDismissedBySwipe && !_isBeingPressed && widget.index == 0) {
          await _controller.reverse();
          widget.onDismissed();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedSnackbarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la tarjeta superior expira y esta pasa al frente, activa su temporizador automáticamente
    if (widget.index == 0 && oldWidget.index != 0) {
      _startAutoDismissTimer(widget.item.duration);
    }
  }

  void _handleTapDown() {
    if (widget.index == 0) {
      setState(() => _isBeingPressed = true);
      _progressController.stop();
    }
  }

  void _handleTapUpOrCancel() {
    if (!_isBeingPressed) return;
    setState(() => _isBeingPressed = false);
    _startAutoDismissTimer(const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ecuaciones de diseño UX/UI en capas (Fondo completo + Efecto 3D de profundidad)
    final double scale =
        1.0 - (widget.index * 0.05); // Reduce el tamaño de las capas traseras
    final double translationY =
        widget.index * 12.0; // Desplaza verticalmente simulando la pila
    final double opacity =
        1.0 - (widget.index * 0.25); // Atenúa las alertas del fondo

    return AnimatedOpacity(
      opacity: opacity.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 250),
      child: Transform.translate(
        offset: Offset(0, translationY),
        child: Transform.scale(
          scale: scale,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTapDown: (_) => _handleTapDown(),
                onTapUp: (_) => _handleTapUpOrCancel(),
                onTapCancel: () => _handleTapUpOrCancel(),
                child: Dismissible(
                  key: ValueKey(widget.item.id),
                  // Solo la tarjeta frontal se puede barrer horizontalmente con el dedo
                  direction:
                      widget.index == 0
                          ? DismissDirection.horizontal
                          : DismissDirection.none,
                  onDismissed: (direction) {
                    _isDismissedBySwipe = true;
                    widget.onDismissed();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.item.backgroundColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.item.backgroundColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.item.backgroundColor.withValues(alpha: 0.3),
                              blurRadius: (16 - (widget.index * 2)).toDouble(),
                              offset: Offset(0, (8 + widget.index).toDouble()),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      widget.item.iconData,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.item.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.index == 0)
                              AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withValues(alpha: 0.5),
                                    ),
                                    minHeight: 2,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
