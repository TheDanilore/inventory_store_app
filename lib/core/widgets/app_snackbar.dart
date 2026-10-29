import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';

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

  /// Muestra una notificación toast moderna, limpia y anti-saturación.
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration? duration,
  }) {
    final cleanMessage =
        type == SnackbarType.error
            ? FriendlyErrorMessage.format(message)
            : message.trim();

    if (cleanMessage.isEmpty) return;

    // 1. DEDUPLICACIÓN: Evitar que el mismo mensaje se muestre dos veces simultáneamente
    if (_queue.any((element) => element.message == cleanMessage)) {
      return;
    }

    final resolvedDuration =
        duration ??
        switch (type) {
          SnackbarType.success => const Duration(milliseconds: 2500),
          SnackbarType.info => const Duration(milliseconds: 2800),
          SnackbarType.warning => const Duration(milliseconds: 3200),
          SnackbarType.error => const Duration(milliseconds: 4000),
        };

    final resolvedBackgroundColor =
        backgroundColor ??
        switch (type) {
          SnackbarType.success => AppColors.success,
          SnackbarType.error => AppColors.accent,
          SnackbarType.warning => AppColors.warning,
          SnackbarType.info => AppColors.info,
        };

    final IconData iconData = switch (type) {
      SnackbarType.success => Icons.check_circle_rounded,
      SnackbarType.error => Icons.error_rounded,
      SnackbarType.warning => Icons.warning_rounded,
      SnackbarType.info => Icons.info_rounded,
    };

    final newSnackbar = _SnackbarModel(
      id: UniqueKey().toString(),
      message: cleanMessage,
      type: type,
      backgroundColor: resolvedBackgroundColor,
      iconData: iconData,
      duration: resolvedDuration,
    );

    // 2. ANTI-SATURACIÓN: Máximo 1 toast activo a la vez. Si entra uno nuevo,
    // reemplaza de forma fluida el anterior en vez de apilar 3 capas encima.
    _queue.clear();
    _queue.add(newSnackbar);

    final overlayState =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.of(context);

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
      try {
        _overlayEntry!.remove();
      } catch (_) {}
      _overlayEntry = null;
      _queue.clear();
    }
  }

  /// Variante que usa [ScaffoldMessengerState] para callbacks asíncronos.
  static void showMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration? duration,
  }) {
    show(
      messenger.context,
      message: message,
      type: type,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }
}

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
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 640;
    final activeItem = widget.items.first;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      right: isDesktop ? 20 : 16,
      left: isDesktop ? null : 16,
      width: isDesktop ? 390 : null,
      child: Material(
        color: Colors.transparent,
        child: _AnimatedSnackbarWidget(
          key: ValueKey(activeItem.id),
          item: activeItem,
          onDismissed: () => widget.onRemove(activeItem.id),
        ),
      ),
    );
  }
}

class _AnimatedSnackbarWidget extends StatefulWidget {
  final _SnackbarModel item;
  final VoidCallback onDismissed;

  const _AnimatedSnackbarWidget({
    super.key,
    required this.item,
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
      duration: const Duration(milliseconds: 240),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: widget.item.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _startTimer(widget.item.duration);
  }

  void _startTimer(Duration duration) {
    _progressController.duration = duration;
    _progressController.reverse(from: 1.0).then((_) async {
      if (mounted && !_isDismissedBySwipe && !_isBeingPressed) {
        await _controller.reverse();
        if (mounted) widget.onDismissed();
      }
    });
  }

  void _handleTapDown() {
    setState(() => _isBeingPressed = true);
    _progressController.stop();
  }

  void _handleTapUpOrCancel() {
    if (!_isBeingPressed) return;
    setState(() => _isBeingPressed = false);
    _startTimer(const Duration(milliseconds: 1200));
  }

  Future<void> _manualDismiss() async {
    _isDismissedBySwipe = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTapDown: (_) => _handleTapDown(),
          onTapUp: (_) => _handleTapUpOrCancel(),
          onTapCancel: () => _handleTapUpOrCancel(),
          child: Dismissible(
            key: ValueKey(widget.item.id),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              _isDismissedBySwipe = true;
              widget.onDismissed();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.item.backgroundColor.withValues(
                        alpha: 0.94,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.item.iconData,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.item.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    letterSpacing: -0.15,
                                    height: 1.25,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _manualDismiss,
                                  hoverColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progressController.value,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.4),
                              ),
                              minHeight: 2.0,
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
    );
  }
}
