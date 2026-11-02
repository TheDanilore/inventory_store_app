import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Envuelve el contenido que debe desaparecer cuando el sidebar se colapsa
/// (etiquetas, badges, chevrons) y lo anima en sincronía con el ancho del
/// panel: el ancho se contrae con [AnimatedAlign.widthFactor] mientras el
/// contenido se desvanece y se desliza suavemente.
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
    return ClipRect(
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        widthFactor: collapsed ? 0.0 : 1.0,
        child: child
            .animate(target: collapsed ? 0 : 1)
            .fadeIn(duration: (duration.inMilliseconds * 0.75).ms)
            .slideX(
              begin: -0.12,
              end: 0,
              duration: duration,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

