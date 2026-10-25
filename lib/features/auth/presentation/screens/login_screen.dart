import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_form_card.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_toggle_mode.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  late final AnimationController _blobCtrl;
  late final Animation<double> _blobAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _blobAnim = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOutSine));
    _blobCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _blobCtrl.dispose();
    super.dispose();
  }

  void _authenticate(bool isLoginMode) {
    final cubit = context.read<AuthCubit>();
    if (cubit.state.viewState == ViewState.loading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos obligatorios.',
        type: SnackbarType.warning,
      );
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (isLoginMode) {
      cubit.login(email, password);
    } else {
      cubit.register(email, password, name);
    }
  }

  void _onToggleMode(bool currentIsLoginMode) {
    final cubit = context.read<AuthCubit>();
    cubit.toggleMode();
    _formKey.currentState?.reset();
    if (!currentIsLoginMode) {
      _nameController.clear();
    }
    _fadeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen:
          (previous, current) => previous.viewState != current.viewState,
      buildWhen:
          (previous, current) =>
              previous.viewState != current.viewState ||
              previous.isLoginMode != current.isLoginMode ||
              previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.viewState == ViewState.error && state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        } else if (state.viewState == ViewState.success) {
          TextInput.finishAutofillContext(shouldSave: true);
          _blobCtrl.stop();
          if (!state.isLoginMode) {
            AppSnackbar.show(
              context,
              message: 'Registro exitoso.',
              type: SnackbarType.success,
            );
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;

              if (isDesktop) {
                return _buildDesktopSplitLayout(context, state);
              }
              return _buildMobileLayout(context, state);
            },
          ),
        );
      },
    );
  }

  // ── Layout Desktop: Split-Screen Auth (50% Hero 3D / 50% Auth Form) ──────
  Widget _buildDesktopSplitLayout(BuildContext context, AuthState state) {
    return Row(
      children: [
        // Lado Izquierdo: Hero Panel de Marca con Arte 3D (50%)
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.2, -0.3),
                radius: 1.4,
                colors: [
                  Color(0xFF22243D), // Navy azulado iluminado
                  Color(0xFF141525), // Navy profundo
                  Color(0xFF0C0D17), // Charcoal oscuro
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Orbe de luz ambiental decorativo de fondo
                Positioned(
                  top: -80,
                  left: -80,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _blobAnim,
                      child: Container(
                        width: 440,
                        height: 440,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _blobAnim.value,
                          child: child,
                        );
                      },
                    ),
                  ),
                ),

                // Contenido Hero centrado y elegante
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56.0,
                      vertical: 40.0,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Composición 3D Hero Artwork
                          Center(
                            child: Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 310,
                                    maxWidth: 360,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.20),
                                        blurRadius: 40,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 16),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.50,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(0, 18),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Stack(
                                      children: [
                                        Image.asset(
                                          'assets/images/login_hero_3d.jpg',
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.white10,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          24,
                                                        ),
                                                    child: const Icon(
                                                      Icons.storefront_rounded,
                                                      size: 80,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                        ),
                                        // Sutil viñeta y resplandor de borde
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                              width: 1.2,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(
                                                  alpha: 0.35,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                                .scale(
                                  begin: const Offset(0.92, 0.92),
                                  end: const Offset(1.0, 1.0),
                                  duration: 800.ms,
                                  curve: Curves.easeOutBack,
                                ),
                          ),
                          const SizedBox(height: 36),

                          // Título Principal Hero
                          const Text(
                                'Gestión Inteligente de Inventario y Ventas',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.9,
                                  height: 1.2,
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 500.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 14),

                          // Subtítulo
                          Text(
                                'Accede al panel centralizado para administrar catálogo, pedidos, POS omnicanal y métricas financieras en tiempo real.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.5,
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 300.ms, duration: 500.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 28),

                          // Badges Glassmorphic
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildFeatureBadge(
                                'Control de Stock',
                                Icons.inventory_2_outlined,
                                delayMs: 400,
                              ),
                              _buildFeatureBadge(
                                'Caja POS',
                                Icons.point_of_sale_rounded,
                                delayMs: 480,
                              ),
                              _buildFeatureBadge(
                                'Fidelización',
                                Icons.loyalty_outlined,
                                delayMs: 560,
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

        // Lado Derecho: Formulario de Autenticación (50%)
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: 24, left: 24, child: _buildBackButton(context)),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 32,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LoginHeaderSection(isLoginMode: state.isLoginMode),
                            const SizedBox(height: 28),
                            LoginFormCard(
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isLoginMode: state.isLoginMode,
                              isLoading: state.viewState == ViewState.loading,
                              onAuthenticate:
                                  () => _authenticate(state.isLoginMode),
                            ),
                            const SizedBox(height: 20),
                            LoginToggleMode(
                              isLoginMode: state.isLoginMode,
                              isLoading: state.viewState == ViewState.loading,
                              onToggle: () => _onToggleMode(state.isLoginMode),
                            ),
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
      ],
    );
  }

  // ── Layout Móvil / Tablet: 1 Columna Centrada con Fondo Ambiental ─────────
  Widget _buildMobileLayout(BuildContext context, AuthState state) {
    return Stack(
      children: [
        // Orbe superior derecho iluminado suavemente
        Positioned(
          top: -100,
          right: -90,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _blobAnim,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              builder: (context, child) {
                return Transform.scale(scale: _blobAnim.value, child: child);
              },
            ),
          ),
        ),
        // Orbe inferior izquierdo con acento suave
        Positioned(
          bottom: 20,
          left: -80,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _blobAnim,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              builder: (context, child) {
                return Transform.scale(
                  scale: 2.0 - _blobAnim.value,
                  child: child,
                );
              },
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: _buildBackButton(context),
                ),
              ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LoginHeaderSection(isLoginMode: state.isLoginMode),
                            const SizedBox(height: 28),
                            LoginFormCard(
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isLoginMode: state.isLoginMode,
                              isLoading: state.viewState == ViewState.loading,
                              onAuthenticate:
                                  () => _authenticate(state.isLoginMode),
                            ),
                            const SizedBox(height: 20),
                            LoginToggleMode(
                              isLoginMode: state.isLoginMode,
                              isLoading: state.viewState == ViewState.loading,
                              onToggle: () => _onToggleMode(state.isLoginMode),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    if (!context.canPop()) {
      return const SizedBox.shrink();
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    if (isDesktop) {
      return TextButton.icon(
        onPressed: () => context.pop(),
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        label: const Text(
          'Volver',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const _MobileBackButton();
  }

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
}

class _MobileBackButton extends StatefulWidget {
  const _MobileBackButton();

  @override
  State<_MobileBackButton> createState() => _MobileBackButtonState();
}

class _MobileBackButtonState extends State<_MobileBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              boxShadow: AppColors.cardShadow(opacity: 0.08),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }
}
