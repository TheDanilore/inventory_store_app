import 'dart:async';
import 'package:flutter/material.dart';

/// Coreografía de entrada escalonada (Fade + Slide vertical sutil) con curva
/// orgánica de desaceleración estilo Apple HIG.
class StaggeredReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayStep;
  final Duration duration;
  final double offsetY;

  const StaggeredReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 320),
    this.offsetY = 12.0,
  });

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      return;
    }

    final delay = widget.delayStep * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
