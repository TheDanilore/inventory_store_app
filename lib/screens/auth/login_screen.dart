import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

import 'widgets/login_header_section.dart';
import 'widgets/login_form_card.dart';
import 'widgets/login_toggle_mode.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // GoRouter maneja la redirección, ya no es necesario checar sesión manualmente aquí.
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Removido _checkSession ya que GoRouter lo maneja globalmente

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos obligatorios.',
        type: SnackbarType.warning,
      );
      return;
    }

    final provider = context.read<AuthProvider>();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final error = await provider.authenticate(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted) return;

    if (error != null) {
      AppSnackbar.show(context, message: error, type: SnackbarType.error);
    } else {
      if (!provider.isLoginMode) {
        AppSnackbar.show(
          context,
          message: 'Registro exitoso. Iniciando sesión...',
          type: SnackbarType.success,
        );
      }
      // Al autenticar exitosamente, AuthProvider notifica y GoRouter redirige solo.
    }
  }

  void _onToggleMode() {
    final provider = context.read<AuthProvider>();
    provider.toggleMode();
    if (provider.isLoginMode) {
      _nameController.clear();
    }
    _fadeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Back button (guest mode)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onPressed: () {
                        // Si hay historial, retrocede. Si no, va a /customer (modo invitado).
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/customer');
                        }
                      },
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LoginHeaderSection(
                              isLoginMode: provider.isLoginMode,
                            ),
                            const SizedBox(height: 32),
                            LoginFormCard(
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isLoginMode: provider.isLoginMode,
                              isLoading: provider.isLoading,
                              onAuthenticate: _authenticate,
                            ),
                            const SizedBox(height: 20),
                            LoginToggleMode(
                              isLoginMode: provider.isLoginMode,
                              isLoading: provider.isLoading,
                              onToggle: _onToggleMode,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
