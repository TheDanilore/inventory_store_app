import 'dart:ui' show ImageFilter, lerpDouble;
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

// ── Paleta del login (sale del logo y del fondo nuevo) ─────────────────────
const Color _kBackdrop = Color(0xFF01091D); // igual al borde inferior del fondo
const Color _kNavy = Color(0xFF061426); // velo final de la transición
const Color _kGlassTop = Color(0xFF0B1E3A);
const Color _kGlassBottom = Color(0xFF040E20);
const Color _kCyan = Color(0xFF22D3EE);

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

  // Curvas creadas con [_curve]; se liberan juntas en dispose().
  final List<CurvedAnimation> _curved = [];

  // ── 1. Entrada: una sola secuencia orquestada ───────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _heroAnim;
  late final Animation<double> _sheetAnim;
  late final Animation<double> _fadeAnim;
  late final List<Animation<double>> _revealAnims; // header, form, toggle

  // ── 2. Ambiente: luz que respira + fondo que flota lentamente ───────────
  late final AnimationController _blobCtrl;
  late final Animation<double> _blobAnim;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  final ValueNotifier<Offset> _parallax = ValueNotifier<Offset>(Offset.zero);

  // ── 3. Éxito: el sheet sube, el fondo se desenfoca y todo se vuelve vidrio
  //       azul marino con la marca mientras se abre el panel.
  late final AnimationController _successCtrl;
  late final Animation<double> _riseAnim; // sheet sube al tope (0 → 0.5)
  late final Animation<double> _contentOutAnim; // formulario se disuelve
  late final Animation<double> _frostAnim; // blur + velo translúcido
  late final Animation<double> _logoAnim; // marca aparece
  late final Animation<double> _progressAnim; // barra de progreso
  late final Animation<double> _whitenAnim; // termina en color sólido

  Animation<double> _curve(
    AnimationController parent,
    double begin,
    double end,
    Curve curve,
  ) {
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(begin, end, curve: curve),
    );
    _curved.add(anim);
    return anim;
  }

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroAnim = _curve(_entranceCtrl, 0.0, 0.70, Curves.easeOutCubic);
    _sheetAnim = _curve(_entranceCtrl, 0.0, 0.65, Curves.easeOutQuart);
    _fadeAnim = _curve(_entranceCtrl, 0.0, 0.50, Curves.easeOut);
    _revealAnims = [
      for (var i = 0; i < 3; i++)
        _curve(
          _entranceCtrl,
          0.32 + i * 0.10,
          0.72 + i * 0.10,
          Curves.easeOutCubic,
        ),
    ];
    _entranceCtrl.forward();

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _blobAnim = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(_curve(_blobCtrl, 0.0, 1.0, Curves.easeInOutSine));
    _blobCtrl.repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    );
    _floatAnim = _curve(_floatCtrl, 0.0, 1.0, Curves.easeInOutSine);
    _floatCtrl.repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _riseAnim = _curve(_successCtrl, 0.00, 0.50, Curves.easeInOutCubic);
    _contentOutAnim = _curve(_successCtrl, 0.00, 0.28, Curves.easeIn);
    _frostAnim = _curve(_successCtrl, 0.10, 0.60, Curves.easeOut);
    _logoAnim = _curve(_successCtrl, 0.50, 0.85, Curves.easeOutCubic);
    _progressAnim = _curve(_successCtrl, 0.55, 1.00, Curves.easeInOut);
    _whitenAnim = _curve(_successCtrl, 0.70, 1.00, Curves.easeInOut);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (final c in _curved) {
      c.dispose();
    }
    _entranceCtrl.dispose();
    _blobCtrl.dispose();
    _floatCtrl.dispose();
    _successCtrl.dispose();
    _parallax.dispose();
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

  /// Aparición escalonada de un bloque del formulario (fade + leve subida).
  Widget _reveal(int index, Widget child) {
    final anim = _revealAnims[index];
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
          FocusManager.instance.primaryFocus?.unfocus();
          _blobCtrl.stop();
          _floatCtrl.stop();
          AppFeedbackService.lightImpact();

          if (!state.isLoginMode) {
            AppSnackbar.show(
              context,
              message: 'Registro exitoso.',
              type: SnackbarType.success,
            );
          }

          // Secuencia: botón verde → el formulario se disuelve → vidrio azul
          // con la marca → recién ahí se entrega el control al panel.
          await _successCtrl.forward();
          if (context.mounted) {
            context.read<AuthCubit>().completeLogin();
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: _kBackdrop,
          // Pantalla oscura → íconos claros en la barra de estado
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;

                if (isDesktop) {
                  return _buildDesktopSplitLayout(context, state);
                }
                return _buildMobileLayout(context, state);
              },
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DESKTOP: split-screen (fondo de marca / formulario de vidrio)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopSplitLayout(BuildContext context, AuthState state) {
    return Stack(
      children: [
        // Contenido: al éxito se desenfoca y crece apenas
        AnimatedBuilder(
          animation: _successCtrl,
          builder: (context, child) {
            Widget result = Transform.scale(
              scale: 1.0 + 0.015 * _riseAnim.value,
              child: child,
            );
            final sigma = 16.0 * _frostAnim.value;
            if (sigma > 0.01) {
              result = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: result,
              );
            }
            return result;
          },
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Row(
              children: [
                Expanded(child: _buildDesktopHeroPanel()),
                Expanded(child: _buildDesktopFormPanel(context, state)),
              ],
            ),
          ),
        ),

        // Velo de vidrio azul + marca (solo visible al iniciar sesión)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _successCtrl,
              builder: (context, child) {
                final alpha =
                    0.78 * _frostAnim.value + 0.22 * _whitenAnim.value;
                return ColoredBox(
                  color: _kNavy.withValues(alpha: alpha),
                  child: child,
                );
              },
              child: Center(
                child: _SuccessVeilContent(
                  reveal: _logoAnim,
                  progress: _progressAnim,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeroPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          onHover: (e) {
            _parallax.value = Offset(
              (e.localPosition.dx / size.width - 0.5) * 2,
              (e.localPosition.dy / size.height - 0.5) * 2,
            );
          },
          onExit: (_) => _parallax.value = Offset.zero,
          child: ClipRect(
            child: ColoredBox(
              color: _kBackdrop,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo de marca: parallax con el mouse + flotación lenta
                  ValueListenableBuilder<Offset>(
                    valueListenable: _parallax,
                    builder: (context, p, child) {
                      return AnimatedSlide(
                        offset: Offset(p.dx * 0.012, p.dy * 0.012),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        child: child,
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.07 + 0.03 * _floatAnim.value,
                          alignment: Alignment.topCenter,
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/login_bg.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // Degradado inferior para que el texto se lea siempre
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD901091D)],
                          stops: [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Orbe turquesa que respira
                  Positioned(
                    top: -80,
                    left: -80,
                    child: RepaintBoundary(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _blobAnim,
                          child: Container(
                            width: 480,
                            height: 480,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _kCyan.withValues(alpha: 0.10),
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
                  ),

                  // Texto de marca abajo, sobre la zona tranquila del fondo
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

  Widget _buildDesktopFormPanel(BuildContext context, AuthState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1B36), _kBackdrop],
        ),
      ),
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
                    _reveal(
                      0,
                      LoginHeaderSection(
                        isLoginMode: state.isLoginMode,
                        logoSize: 76,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _reveal(
                      1,
                      LoginFormCard(
                        formKey: _formKey,
                        nameController: _nameController,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isLoginMode: state.isLoginMode,
                        isLoading: state.viewState == ViewState.loading,
                        isSuccess: state.viewState == ViewState.success,
                        onAuthenticate: () => _authenticate(state.isLoginMode),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _reveal(
                      2,
                      LoginToggleMode(
                        isLoginMode: state.isLoginMode,
                        isLoading: state.viewState == ViewState.loading,
                        onToggle: () => _onToggleMode(state.isLoginMode),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MÓVIL: fondo de marca + sheet de vidrio oscuro. Al éxito el sheet sube
  //  al tope y todo se convierte en vidrio azul con la marca al centro.
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context, AuthState state) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;

    final heroHeight = (screenHeight * 0.38).clamp(200.0, 320.0);
    final restingSheetTop = isKeyboardOpen ? 64.0 : heroHeight;

    // Contenido del sheet (formulario) – se construye una sola vez por estado
    final sheetBody = Stack(
      children: [
        AnimatedBuilder(
          animation: _contentOutAnim,
          builder: (context, child) {
            final t = _contentOutAnim.value;
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
                // Handle del sheet
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
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
                                logoSize: 52,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _reveal(
                              1,
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
                            ),
                            const SizedBox(height: 18),
                            _reveal(
                              2,
                              LoginToggleMode(
                                isLoginMode: state.isLoginMode,
                                isLoading: state.viewState == ViewState.loading,
                                onToggle:
                                    () => _onToggleMode(state.isLoginMode),
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

        // Marca + progreso, aparece cuando el sheet ya cubre la pantalla
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: _SuccessVeilContent(
                reveal: _logoAnim,
                progress: _progressAnim,
              ),
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        // 1. FONDO a pantalla completa: al éxito se desenfoca y crece
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _successCtrl,
            builder: (context, child) {
              final f = _frostAnim.value;
              Widget backdrop = Transform.scale(
                scale: 1.0 + 0.14 * f,
                child: child,
              );
              if (f > 0.01) {
                backdrop = ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 26 * f, sigmaY: 26 * f),
                  child: backdrop,
                );
              }
              return backdrop;
            },
            child: _buildMobileBackdrop(isKeyboardOpen),
          ),
        ),

        // 2. Botón volver (se desvanece junto al formulario)
        Positioned(
          top: 0,
          left: 0,
          child: AnimatedBuilder(
            animation: _contentOutAnim,
            builder:
                (context, child) =>
                    Opacity(opacity: 1.0 - _contentOutAnim.value, child: child),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: _buildBackButton(context, isDark: true),
              ),
            ),
          ),
        ),

        // 3. SHEET: entra desde abajo, sube al tope y se vuelve vidrio azul
        TweenAnimationBuilder<double>(
          // El tope del sheet se anima al abrir/cerrar el teclado (sin saltos)
          tween: Tween<double>(end: restingSheetTop),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: sheetBody,
          builder: (context, restingTop, sheetChild) {
            return AnimatedBuilder(
              animation: Listenable.merge([_successCtrl, _entranceCtrl]),
              child: sheetChild,
              builder: (context, child) {
                final entranceOffsetY =
                    (1.0 - _sheetAnim.value) * screenHeight * 0.45;
                final top = (lerpDouble(restingTop, 0.0, _riseAnim.value)! +
                        entranceOffsetY)
                    .clamp(0.0, screenHeight);
                final radius = lerpDouble(32.0, 0.0, _riseAnim.value)!;
                // Vidrio en reposo → más translúcido al subir → sólido al final
                final base = 0.88 - 0.30 * _frostAnim.value;
                final alpha = base + (1.0 - base) * _whitenAnim.value;
                final glow = 1.0 - _riseAnim.value;

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
              },
            );
          },
        ),
      ],
    );
  }

  /// Fondo de marca (flujo logístico → caja POS → métricas) a todo el ancho,
  /// con el borde inferior fundido en el color de fondo.
  Widget _buildMobileBackdrop(bool isKeyboardOpen) {
    return ColoredBox(
      color: _kBackdrop,
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
              child: AnimatedBuilder(
                animation: Listenable.merge([_entranceCtrl, _floatCtrl]),
                builder: (context, child) {
                  final h = _heroAnim.value;
                  return Opacity(
                    opacity: h,
                    child: Transform.scale(
                      alignment: Alignment.topCenter,
                      scale: 1.08 - 0.08 * h + 0.025 * _floatAnim.value,
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
                    'assets/images/login_bg.jpg',
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
          // Orbe turquesa que respira (detrás del arte, en la esquina)
          Positioned(
            top: -60,
            right: -50,
            child: IgnorePointer(
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
                              _kCyan.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
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

  Widget _buildBackButton(BuildContext context, {bool isDark = false}) {
    if (!context.canPop()) {
      return const SizedBox.shrink();
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    if (isDesktop) {
      return TextButton.icon(
        onPressed: () => context.pop(),
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        label: Text(
          'Volver',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
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

/// Marca + barra de progreso que aparecen sobre el vidrio azul al iniciar
/// sesión. Es el único "momento" de la transición: todo lo demás se calla.
class _SuccessVeilContent extends StatelessWidget {
  final Animation<double> reveal;
  final Animation<double> progress;

  const _SuccessVeilContent({required this.reveal, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, progress]),
      builder: (context, _) {
        final t = reveal.value;
        if (t <= 0) return const SizedBox.shrink();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(
              scale: 0.94 + 0.06 * t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.38),
                          blurRadius: 44,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: _kCyan,
                          ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Abriendo tu panel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 120,
                      height: 3,
                      child: LinearProgressIndicator(
                        value: progress.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor: const AlwaysStoppedAnimation<Color>(_kCyan),
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
