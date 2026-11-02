import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _kBackdrop = Color(0xFF01091D);
const Color _kCyan = Color(0xFF22D3EE);

/// Hero lateral izquierdo para Desktop (>= 1024px) con arte de marca,
/// orbe lumínico aislado y badges informativos.
class LoginDesktopHeroPanel extends StatelessWidget {
  final bool isDark;
  final ValueNotifier<Offset> parallax;
  final Animation<double> floatAnim;
  final Animation<double> blobAnim;

  const LoginDesktopHeroPanel({
    super.key,
    required this.isDark,
    required this.parallax,
    required this.floatAnim,
    required this.blobAnim,
  });

  Widget _buildFeatureBadge(
    String label,
    IconData icon, {
    required int delayMs,
  }) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs), duration: 400.ms)
        .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          onHover: (e) {
            parallax.value = Offset(
              (e.localPosition.dx / size.width - 0.5) * 2,
              (e.localPosition.dy / size.height - 0.5) * 2,
            );
          },
          onExit: (_) => parallax.value = Offset.zero,
          child: ClipRect(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 1.3,
                  colors:
                      isDark
                          ? const [
                            Color(0xFF0C1B33),
                            Color(0xFF061124),
                            _kBackdrop,
                          ]
                          : const [
                            Color(0xFF1E2138),
                            Color(0xFF111220),
                            Color(0xFF090A12),
                          ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Arte/fondo: Parallax con el mouse + flotación lenta
                  RepaintBoundary(
                    child: ValueListenableBuilder<Offset>(
                      valueListenable: parallax,
                      builder: (context, p, child) {
                        return AnimatedSlide(
                          offset: Offset(p.dx * 0.014, p.dy * 0.014),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          child: child,
                        );
                      },
                      child: AnimatedBuilder(
                        animation: floatAnim,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.05 + 0.03 * floatAnim.value,
                            alignment: Alignment.topCenter,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/login_bg.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  // Degradado inferior para legibilidad del texto
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            isDark
                                ? const Color(0xD901091D)
                                : const Color(0xDE090A12),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Orbe turquesa/azul aislado con RepaintBoundary
                  Positioned(
                    top: -80,
                    left: -80,
                    child: RepaintBoundary(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: blobAnim,
                          child: Container(
                            width: 480,
                            height: 480,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isDark ? _kCyan : const Color(0xFF3B82F6))
                                      .withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: blobAnim.value,
                              child: child,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Texto de marca abajo
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: SingleChildScrollView(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(56, 36, 56, 56),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gestión Inteligente de Inventario y Ventas',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Accede al panel centralizado para administrar catálogo, pedidos, POS omnicanal y métricas financieras en tiempo real.',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: Colors.white.withValues(alpha: 0.76),
                                height: 1.5,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildFeatureBadge(
                                  'Control de Stock',
                                  Icons.inventory_2_outlined,
                                  delayMs: 450,
                                ),
                                _buildFeatureBadge(
                                  'Caja POS',
                                  Icons.point_of_sale_rounded,
                                  delayMs: 550,
                                ),
                                _buildFeatureBadge(
                                  'Fidelización',
                                  Icons.loyalty_outlined,
                                  delayMs: 650,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
