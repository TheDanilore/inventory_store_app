import 'package:flutter/material.dart';

/// Oculta o muestra las etiquetas del sidebar sin mantener [AnimationController]s
/// ni widgets de texto ocultos en RAM cuando el panel está colapsado.
class CollapsibleLabel extends StatelessWidget {
  final bool collapsed;
  final Widget child;
  final Duration duration;

  const CollapsibleLabel({
    super.key,
    required this.collapsed,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    if (collapsed) return const SizedBox.shrink();
    return child;
  }
}
