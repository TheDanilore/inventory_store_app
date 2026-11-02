import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_eclipse_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_back_button.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_desktop_hero_panel.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_form_card.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_mobile_backdrop.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_mobile_sheet.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_success_veil.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_toggle_mode.dart';

const Color _kBackdrop = Color(0xFF01091D);
const Color _kNavy = Color(0xFF061426);

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

  final List<CurvedAnimation> _curved = [];

  // Entrada
  late final AnimationController _entranceCtrl;
  late final Animation<double> _heroAnim;
  late final Animation<double> _sheetAnim;
  late final Animation<double> _fadeAnim;
  late final List<Animation<double>> _revealAnims;

  // Ambiente
  late final AnimationController _blobCtrl;
  late final Animation<double> _blobAnim;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  final ValueNotifier<Offset> _parallax = ValueNotifier<Offset>(Offset.zero);

  // Éxito
  late final AnimationController _successCtrl;
  late final Animation<double> _riseAnim;
  late final Animation<double> _contentOutAnim;
  late final Animation<double> _frostAnim;
  late final Animation<double> _logoAnim;
  late final Animation<double> _progressAnim;
  late final Animation<double> _whitenAnim;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

          await _successCtrl.forward();
          if (context.mounted) {
            context.read<AuthCubit>().completeLogin();
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? _kBackdrop : const Color(0xFF0F111E),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value:
                    isDark
                        ? SystemUiOverlayStyle.light
                        : (isDesktop
                            ? SystemUiOverlayStyle.dark
                            : SystemUiOverlayStyle.light),
                child:
                    isDesktop
                        ? _buildDesktopSplitLayout(context, state, isDark)
                        : _buildMobileLayout(context, state, isDark),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopSplitLayout(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _successCtrl,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + 0.015 * _riseAnim.value,
              child: child,
            );
          },
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Row(
              children: [
                Expanded(
                  child: LoginDesktopHeroPanel(
                    isDark: isDark,
                    parallax: _parallax,
                    floatAnim: _floatAnim,
                    blobAnim: _blobAnim,
                  ),
                ),
                Expanded(child: _buildDesktopFormPanel(context, state, isDark)),
              ],
            ),
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _successCtrl,
              builder: (context, child) {
                final alpha =
                    0.78 * _frostAnim.value + 0.22 * _whitenAnim.value;
                return ColoredBox(
                  color: (isDark ? _kNavy : Colors.white).withValues(
                    alpha: alpha,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: LoginSuccessVeil(
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

  Widget _buildDesktopFormPanel(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? null : AppColors.background,
        gradient:
            isDark
                ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1B36), _kBackdrop],
                )
                : null,
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LoginBackButton(isDark: isDark),
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, _) {
                      return ThemeEclipseButton(
                        isDark: isDark,
                        size: 38,
                        tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                        onTapWithOrigin: (origin) {
                          ThemeCircularWave.switchTheme(
                            context,
                            origin: origin,
                          );
                        },
                      );
                    },
                  ),
                ],
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

  Widget _buildMobileLayout(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;

    final heroHeight = (screenHeight * 0.38).clamp(200.0, 320.0);
    final restingSheetTop = isKeyboardOpen ? 64.0 : heroHeight;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _successCtrl,
            builder: (context, child) {
              final f = _frostAnim.value;
              return Transform.scale(scale: 1.0 + 0.14 * f, child: child);
            },
            child: LoginMobileBackdrop(
              isKeyboardOpen: isKeyboardOpen,
              isDark: isDark,
              heroAnim: _heroAnim,
              entranceCtrl: _entranceCtrl,
              floatCtrl: _floatCtrl,
              floatAnim: _floatAnim,
              blobAnim: _blobAnim,
            ),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          child: AnimatedBuilder(
            animation: _contentOutAnim,
            builder:
                (context, child) =>
                    Opacity(opacity: 1.0 - _contentOutAnim.value, child: child),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.only(left: 8.0, top: 4.0),
                child: LoginBackButton(isDark: true),
              ),
            ),
          ),
        ),

        Positioned(
          top: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _contentOutAnim,
            builder:
                (context, child) =>
                    Opacity(opacity: 1.0 - _contentOutAnim.value, child: child),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0, top: 4.0),
                child: BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, _) {
                    return ThemeEclipseButton(
                      isDark: isDark,
                      size: 38,
                      tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                      onTapWithOrigin: (origin) {
                        ThemeCircularWave.switchTheme(context, origin: origin);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        LoginMobileSheet(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          state: state,
          isDark: isDark,
          restingSheetTop: restingSheetTop,
          screenHeight: screenHeight,
          sheetAnim: _sheetAnim,
          riseAnim: _riseAnim,
          frostAnim: _frostAnim,
          whitenAnim: _whitenAnim,
          contentOutAnim: _contentOutAnim,
          logoAnim: _logoAnim,
          progressAnim: _progressAnim,
          revealAnims: _revealAnims,
          successCtrl: _successCtrl,
          entranceCtrl: _entranceCtrl,
          onAuthenticate: () => _authenticate(state.isLoginMode),
          onToggleMode: () => _onToggleMode(state.isLoginMode),
        ),
      ],
    );
  }
}
