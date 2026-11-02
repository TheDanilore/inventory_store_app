import 'package:flutter/material.dart';

const Color _kBackdrop = Color(0xFF01091D);
const Color _kCyan = Color(0xFF22D3EE);

/// Fondo de marca adaptado para móvil con aislamiento de repintado.
class LoginMobileBackdrop extends StatelessWidget {
  final bool isKeyboardOpen;
  final bool isDark;
  final Animation<double> heroAnim;
  final AnimationController entranceCtrl;
  final AnimationController floatCtrl;
  final Animation<double> floatAnim;
  final Animation<double> blobAnim;

  const LoginMobileBackdrop({
    super.key,
    required this.isKeyboardOpen,
    required this.isDark,
    required this.heroAnim,
    required this.entranceCtrl,
    required this.floatCtrl,
    required this.floatAnim,
    required this.blobAnim,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isDark ? _kBackdrop : const Color(0xFF0F111E),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: isKeyboardOpen ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([entranceCtrl, floatCtrl]),
                  builder: (context, child) {
                    final h = heroAnim.value;
                    return Opacity(
                      opacity: h,
                      child: Transform.scale(
                        alignment: Alignment.topCenter,
                        scale: 1.08 - 0.08 * h + 0.025 * floatAnim.value,
                        child: child,
                      ),
                    );
                  },
                  child: ShaderMask(
                    shaderCallback:
                        (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.86, 1.0],
                        ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/login_bg.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder:
                          (context, error, stackTrace) => const SizedBox(
                            height: 240,
                            child: Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 84,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Orbe turquesa/azul que respira en la esquina superior derecha
          Positioned(
            top: -60,
            right: -50,
            child: RepaintBoundary(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: blobAnim,
                  builder:
                      (context, _) => Transform.scale(
                        scale: blobAnim.value,
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                (isDark ? _kCyan : const Color(0xFF3B82F6))
                                    .withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
