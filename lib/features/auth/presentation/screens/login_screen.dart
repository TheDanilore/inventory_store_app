import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
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

  bool _isBackBtnPressed = false;

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
      duration: const Duration(seconds: 4),
    );
    _blobAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOutSine));
    _blobCtrl.repeat(reverse: true);
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

    if (!_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos obligatorios.',
        type: SnackbarType.warning,
      );
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (isLoginMode) {
      cubit.login(email, password);
    } else {
      cubit.register(email, password, name);
    }
  }

  void _onToggleMode(bool currentIsLoginMode) {
    final cubit = context.read<AuthCubit>();
    cubit.toggleMode();
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
      listener: (context, state) {
        if (state.viewState == ViewState.error && state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        } else if (state.viewState == ViewState.success) {
          _passwordController.clear();
          _blobCtrl.stop();
          if (!state.isLoginMode) {
            AppSnackbar.show(
              context,
              message: 'Registro exitoso.',
              type: SnackbarType.success,
            );
          }
          if (state.currentUser?.role == AppRoles.admin) {
            context.go('/admin');
          } else {
            context.go('/');
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

  // ── Layout Desktop: Split-Screen Auth (50% Hero Panel / 50% Auth Form) ──────
  Widget _buildDesktopSplitLayout(BuildContext context, AuthState state) {
    return Row(
      children: [
        // Lado Izquierdo: Hero Panel de Marca (50%)
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF0F3460)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _blobAnim,
                  builder: (context, child) {
                    return Positioned(
                      top: -100,
                      left: -100,
                      child: Transform.scale(
                        scale: _blobAnim.value,
                        child: Container(
                          width: 380,
                          height: 380,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Gestión Inteligente de Inventario y Ventas',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Accede al panel de control centralizado para administrar catálogo, pedidos, POS y reportes financieros en tiempo real.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          _buildFeatureBadge('Control de Stock'),
                          const SizedBox(width: 12),
                          _buildFeatureBadge('Caja POS'),
                          const SizedBox(width: 12),
                          _buildFeatureBadge('Fidelización'),
                        ],
                      ),
                    ],
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
            color: AppColors.background,
            child: Stack(
              children: [
                // Back Button invitado
                Positioned(
                  top: 24,
                  left: 24,
                  child: _buildBackButton(context),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
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

  // ── Layout Móvil / Tablet: 1 Columna Centrada ─────────────────────────────
  Widget _buildMobileLayout(BuildContext context, AuthState state) {
    return Stack(
      children: [
        // Blobs decorativos
        AnimatedBuilder(
          animation: _blobAnim,
          builder: (context, child) {
            return Positioned(
              top: -80,
              right: -80,
              child: Transform.scale(
                scale: _blobAnim.value,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.06),
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _blobAnim,
          builder: (context, child) {
            return Positioned(
              top: 40,
              left: -60,
              child: Transform.scale(
                scale: 2.0 - _blobAnim.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.05),
                  ),
                ),
              ),
            );
          },
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
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LoginHeaderSection(isLoginMode: state.isLoginMode),
                            const SizedBox(height: 32),
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
                            const SizedBox(height: 32),
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
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return TextButton.icon(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        label: const Text(
          'Volver a la Tienda',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isBackBtnPressed = true),
      onTapUp: (_) => setState(() => _isBackBtnPressed = false),
      onTapCancel: () => setState(() => _isBackBtnPressed = false),
      child: AnimatedScale(
        scale: _isBackBtnPressed ? 0.90 : 1.0,
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
