import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_form_card.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_success_veil.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_toggle_mode.dart';

const Color _kGlassTop = Color(0xFF0B1E3A);
const Color _kGlassBottom = Color(0xFF040E20);
const Color _kCyan = Color(0xFF22D3EE);

/// Hoja inferior deslizante (Bottom Sheet) para móvil con soporte bimodal
/// (claro/oscuro) y transiciones fluidas de elevación.
class LoginMobileSheet extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AuthState state;
  final bool isDark;
  final double restingSheetTop;
  final double screenHeight;
  final Animation<double> sheetAnim;
  final Animation<double> riseAnim;
  final Animation<double> frostAnim;
  final Animation<double> whitenAnim;
  final Animation<double> contentOutAnim;
  final Animation<double> logoAnim;
  final Animation<double> progressAnim;
  final List<Animation<double>> revealAnims;
  final AnimationController successCtrl;
  final AnimationController entranceCtrl;
  final VoidCallback onAuthenticate;
  final VoidCallback onToggleMode;

  const LoginMobileSheet({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.state,
    required this.isDark,
    required this.restingSheetTop,
    required this.screenHeight,
    required this.sheetAnim,
    required this.riseAnim,
    required this.frostAnim,
    required this.whitenAnim,
    required this.contentOutAnim,
    required this.logoAnim,
    required this.progressAnim,
    required this.revealAnims,
    required this.successCtrl,
    required this.entranceCtrl,
    required this.onAuthenticate,
    required this.onToggleMode,
  });

  Widget _reveal(int index, Widget child) {
    final anim = revealAnims[index];
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetBody = Stack(
      children: [
        AnimatedBuilder(
          animation: contentOutAnim,
          builder: (context, child) {
            final t = contentOutAnim.value;
            return IgnorePointer(
              ignoring: t > 0,
              child: Opacity(
                opacity: 1.0 - t,
                child: Transform.scale(scale: 1.0 - 0.03 * t, child: child),
              ),
            );
          },
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.22)
                              : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 8,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _reveal(
                              0,
                              LoginHeaderSection(
                                isLoginMode: state.isLoginMode,
                                showLogo: true,
                                logoSize: 56,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _reveal(
                              1,
                              LoginFormCard(
                                formKey: formKey,
                                nameController: nameController,
                                emailController: emailController,
                                passwordController: passwordController,
                                isLoginMode: state.isLoginMode,
                                isLoading: state.viewState == ViewState.loading,
                                isSuccess: state.viewState == ViewState.success,
                                isFlat: true,
                                onAuthenticate: onAuthenticate,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _reveal(
                              2,
                              LoginToggleMode(
                                isLoginMode: state.isLoginMode,
                                isLoading: state.viewState == ViewState.loading,
                                onToggle: onToggleMode,
                              ),
                            ),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: LoginSuccessVeil(reveal: logoAnim, progress: progressAnim),
            ),
          ),
        ),
      ],
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: restingSheetTop),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: sheetBody,
      builder: (context, restingTop, sheetChild) {
        return AnimatedBuilder(
          animation: Listenable.merge([successCtrl, entranceCtrl]),
          child: sheetChild,
          builder: (context, child) {
            final entranceOffsetY =
                (1.0 - sheetAnim.value) * screenHeight * 0.45;
            final top = (lerpDouble(restingTop, 0.0, riseAnim.value)! +
                    entranceOffsetY)
                .clamp(0.0, screenHeight);
            final radius = lerpDouble(32.0, 0.0, riseAnim.value)!;
            final glow = 1.0 - riseAnim.value;

            if (isDark) {
              final base = 0.88 - 0.30 * frostAnim.value;
              final alpha = base + (1.0 - base) * whitenAnim.value;

              return Positioned(
                top: top,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35 * glow),
                        blurRadius: 32,
                        offset: const Offset(0, -10),
                      ),
                      BoxShadow(
                        color: _kCyan.withValues(alpha: 0.12 * glow),
                        blurRadius: 36,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kGlassTop.withValues(alpha: alpha),
                            _kGlassBottom.withValues(alpha: alpha),
                          ],
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ),
              );
            } else {
              final alpha =
                  1.0 - 0.20 * frostAnim.value + 0.20 * whitenAnim.value;
              final shadowAlpha = 0.18 * (1.0 - riseAnim.value);

              return Positioned(
                top: top,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF0F172A,
                        ).withValues(alpha: shadowAlpha),
                        blurRadius: 32,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: alpha),
                      child: child,
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
