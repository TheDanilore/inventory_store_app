import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
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

  // ── Controladores de Animación ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _heroSlideAnim;
  late final Animation<double> _sheetSlideAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _blobCtrl;
  late final Animation<double> _blobAnim;

  late final AnimationController _sheetExpandCtrl;
  late final Animation<double> _sheetExpandAnim;

  @override
  void initState() {
    super.initState();

    // 1. Animación de Entrada Fluida (Hero desliza desde arriba, Sheet desliza desde abajo)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroSlideAnim = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
    _sheetSlideAnim = Tween<double>(begin: 0.40, end: 0.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceCtrl.forward();

    // 2. Respiración sutil continua de la luz ambiental decorativa
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _blobAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOutSine));
    _blobCtrl.repeat(reverse: true);

    // 3. Animación al Iniciar Sesión con Éxito (El bottom sheet sube hasta el tope cubriendo la pantalla)
    _sheetExpandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _sheetExpandAnim = CurvedAnimation(
      parent: _sheetExpandCtrl,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _entranceCtrl.dispose();
    _blobCtrl.dispose();
    _sheetExpandCtrl.dispose();
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
      listener: (context, state) async {
        if (state.viewState == ViewState.error && state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        } else if (state.viewState == ViewState.success) {
          TextInput.finishAutofillContext(shouldSave: true);
          _blobCtrl.stop();
          AppFeedbackService.lightImpact();

          // ── TRANSICIÓN AL LOGUEAR: El Sheet se eleva suavemente hasta el tope ──
          _sheetExpandCtrl.forward();

          if (!state.isLoginMode) {
            AppSnackbar.show(
              context,
              message: 'Registro exitoso.',
              type: SnackbarType.success,
            );
          }

          // Esperar que complete la animación para transicionar sin saltos bruscos
          await Future.delayed(const Duration(milliseconds: 580));
          if (context.mounted) {
            context.read<AuthCubit>().completeLogin();
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F111E),
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
    return AnimatedBuilder(
      animation: _sheetExpandCtrl,
      builder: (context, child) {
        final scale = 1.0 + (_sheetExpandAnim.value * 0.02);
        final opacity = (1.0 - _sheetExpandAnim.value * 0.9).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Row(
          children: [
            // Lado Izquierdo: Hero Panel de Marca con Arte 3D (50%)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.2),
                    radius: 1.3,
                    colors: [
                      Color(0xFF1E2138),
                      Color(0xFF111220),
                      Color(0xFF090A12),
                    ],
                    stops: [0.0, 0.65, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -80,
                      left: -80,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _blobAnim,
                          child: Container(
                            width: 480,
                            height: 480,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.14),
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

                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56.0,
                          vertical: 36.0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.82,
                                      colors: [
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.65, 1.0],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 340,
                                      maxWidth: 440,
                                    ),
                                    child: Image.asset(
                                      'assets/images/login_hero_3d.jpg',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.storefront_rounded,
                                                size: 90,
                                                color: Colors.white,
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

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
                                  color: Colors.white.withValues(alpha: 0.72),
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
                                    delayMs: 150,
                                  ),
                                  _buildFeatureBadge(
                                    'Caja POS',
                                    Icons.point_of_sale_rounded,
                                    delayMs: 250,
                                  ),
                                  _buildFeatureBadge(
                                    'Fidelización',
                                    Icons.loyalty_outlined,
                                    delayMs: 350,
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

            // Lado Derecho: Formulario Autenticación (50%)
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                child: Stack(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _buildBackButton(context),
                        ),
                      ),
                    ),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LoginHeaderSection(
                                isLoginMode: state.isLoginMode,
                              ),
                              const SizedBox(height: 26),
                              LoginFormCard(
                                formKey: _formKey,
                                nameController: _nameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                isLoginMode: state.isLoginMode,
                                isLoading: state.viewState == ViewState.loading,
                                isSuccess: state.viewState == ViewState.success,
                                onAuthenticate:
                                    () => _authenticate(state.isLoginMode),
                              ),
                              const SizedBox(height: 20),
                              LoginToggleMode(
                                isLoginMode: state.isLoginMode,
                                isLoading: state.viewState == ViewState.loading,
                                onToggle:
                                    () => _onToggleMode(state.isLoginMode),
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
          ],
        ),
      ),
    );
  }

  // ── Layout Móvil: Hero Superior Visual 3D + Bottom Sheet Curvado con Elevación al Top ──
  Widget _buildMobileLayout(BuildContext context, AuthState state) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 0;

    // Altura del hero visual superior (36-40% de la pantalla)
    final heroHeight = (screenHeight * 0.38).clamp(200.0, 320.0);
    final restingSheetTop = isKeyboardOpen ? 64.0 : heroHeight;

    return Stack(
      children: [
        // ── 1. ZONA HERO SUPERIOR: ARTE 3D + ATMÓSFERA TECH DE FONDO ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight + 36,
          child: AnimatedBuilder(
            animation: _sheetExpandCtrl,
            builder: (context, child) {
              final heroOpacity = (1.0 - _sheetExpandAnim.value * 1.8).clamp(
                0.0,
                1.0,
              );
              return Opacity(opacity: heroOpacity, child: child);
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.25,
                  colors: [
                    Color(0xFF1E2138),
                    Color(0xFF111220),
                    Color(0xFF090A12),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Orbe ambiental con respiración
                  Positioned(
                    top: -60,
                    right: -50,
                    child: AnimatedBuilder(
                      animation: _blobAnim,
                      builder:
                          (context, _) => Transform.scale(
                            scale: _blobAnim.value,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: 0.20),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),

                  // Arte 3D con animación de entrada (desliza hacia abajo suavemente)
                  SafeArea(
                    bottom: false,
                    child: AnimatedBuilder(
                      animation: _entranceCtrl,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _heroSlideAnim.value * 60),
                          child: Opacity(
                            opacity: _fadeAnim.value,
                            child: child,
                          ),
                        );
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20.0,
                            top: 4.0,
                          ),
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const RadialGradient(
                                center: Alignment.center,
                                radius: 0.82,
                                colors: [
                                  Colors.black,
                                  Colors.black,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.68, 1.0],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/login_hero_3d.jpg',
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (context, error, stackTrace) => const Icon(
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

                  // Botón Volver con contraste oscuro
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: _buildBackButton(context, isDark: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 2. BOTTOM SHEET CURVADO: ENTRADA Y ELEVACIÓN AL TOPE AL LOGUEAR ──
        AnimatedBuilder(
          animation: Listenable.merge([_sheetExpandCtrl, _entranceCtrl]),
          builder: (context, child) {
            // Animación de entrada inicial: sube desde la base
            final entranceOffsetY = _sheetSlideAnim.value * screenHeight;

            // Al iniciar sesión (éxito): se eleva fluidamente hasta el tope (0.0) cubriendo la pantalla
            final currentTop =
                lerpDouble(restingSheetTop, 0.0, _sheetExpandAnim.value)!;

            // El radio de borde superior pasa de 32 a 0 al alcanzar la cima
            final currentRadius =
                lerpDouble(32.0, 0.0, _sheetExpandAnim.value)!;

            return Positioned(
              top: (currentTop + entranceOffsetY).clamp(0.0, screenHeight),
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(currentRadius),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(currentRadius),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: SafeArea(
            top: _sheetExpandAnim.value > 0.4,
            child: Column(
              children: [
                // Pill / Handle indicador superior del Sheet
                AnimatedBuilder(
                  animation: _sheetExpandCtrl,
                  builder: (context, child) {
                    final handleOpacity = (1.0 - _sheetExpandAnim.value * 2.5)
                        .clamp(0.0, 1.0);
                    return Opacity(opacity: handleOpacity, child: child);
                  },
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                // Formulario escroleable dentro del Bottom Sheet
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título y subtítulo elegantes (sin logo duplicado, el 3D está arriba)
                          LoginHeaderSection(
                            isLoginMode: state.isLoginMode,
                            showLogo: false,
                          ),
                          const SizedBox(height: 22),

                          // Formulario de credenciales plano integrado en el sheet
                          LoginFormCard(
                            formKey: _formKey,
                            nameController: _nameController,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            isLoginMode: state.isLoginMode,
                            isLoading: state.viewState == ViewState.loading,
                            isSuccess: state.viewState == ViewState.success,
                            isFlat: true,
                            onAuthenticate:
                                () => _authenticate(state.isLoginMode),
                          ),
                          const SizedBox(height: 18),

                          // Alternar entre Iniciar Sesión y Registro
                          LoginToggleMode(
                            isLoginMode: state.isLoginMode,
                            isLoading: state.viewState == ViewState.loading,
                            onToggle: () => _onToggleMode(state.isLoginMode),
                          ),
                          const SizedBox(height: 36),
                        ],
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

  Widget _buildBackButton(BuildContext context, {bool isDark = false}) {
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

    return _MobileBackButton(isDark: isDark);
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
  final bool isDark;
  const _MobileBackButton({this.isDark = false});

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
              color:
                  widget.isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              boxShadow:
                  widget.isDark ? null : AppColors.cardShadow(opacity: 0.08),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: widget.isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }
}
