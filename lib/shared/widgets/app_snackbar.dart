import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

enum SnackbarType { success, error, warning, info }

class AppSnackbar {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    dismiss();

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

    final overlayState = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) {
        return _AnimatedSnackbarWidget(
          message: message,
          backgroundColor: resolvedBackgroundColor,
          iconData: iconData,
          duration: duration,
          onDismissed: () => dismiss(),
        );
      },
    );

    overlayState.insert(_currentOverlay!);
  }

  static void dismiss() {
    if (_currentOverlay != null && _currentOverlay!.mounted) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
  }
}

class _AnimatedSnackbarWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData iconData;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AnimatedSnackbarWidget({
    required this.message,
    required this.backgroundColor,
    required this.iconData,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AnimatedSnackbarWidget> createState() =>
      _AnimatedSnackbarWidgetState();
}

class _AnimatedSnackbarWidgetState extends State<_AnimatedSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isDismissedBySwipe = false;
  bool _isBeingPressed = false; // Rastrea si el usuario está tocando la alerta

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
    _startAutoDismissTimer(widget.duration);
  }

  // Configura el temporizador de cierre automático
  void _startAutoDismissTimer(Duration duration) {
    Future.delayed(duration, () async {
      // Solo procede si sigue montado, nadie lo arrastró y no está siendo retenido por el dedo
      if (mounted && !_isDismissedBySwipe && !_isBeingPressed) {
        await _controller.reverse();
        widget.onDismissed();
      }
    });
  }

  // Al presionar el widget, bloqueamos la destrucción automática
  void _handleTapDown() {
    setState(() {
      _isBeingPressed = true;
    });
  }

  // Al soltar el widget, recalculamos un tiempo extra de cortesía para que se vaya
  void _handleTapUpOrCancel() {
    if (!_isBeingPressed) return;

    setState(() {
      _isBeingPressed = false;
    });

    // Le otorgamos 1.5 segundos extras de vida tras soltarlo para que el usuario termine de leer
    _startAutoDismissTimer(const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTapDown: (_) => _handleTapDown(),
              onTapUp: (_) => _handleTapUpOrCancel(),
              onTapCancel: () => _handleTapUpOrCancel(),
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  _isDismissedBySwipe = true;
                  widget.onDismissed();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(widget.iconData, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
      ),
    );
  }
}
