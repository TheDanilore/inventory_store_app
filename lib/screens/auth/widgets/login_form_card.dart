import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/auth_provider.dart';

class LoginFormCard extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoginMode;
  final bool isLoading;
  final VoidCallback onAuthenticate;

  const LoginFormCard({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.isLoginMode,
    required this.isLoading,
    required this.onAuthenticate,
  });

  @override
  State<LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends State<LoginFormCard> {
  bool _obscurePassword = true;

  String? _validateName(String? value) {
    if (widget.isLoginMode) return null;
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Ingresa tu nombre completo';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Ingresa tu correo';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = (value ?? '').trim();
    if (password.isEmpty) return 'Ingresa tu contraseña';
    if (!widget.isLoginMode && password.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    return null;
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: widget.emailController.text);
    final provider = context.read<AuthProvider>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa tu correo electrónico para enviarte un enlace de recuperación.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  AppSnackbar.show(
                    ctx,
                    message: 'Ingresa un correo válido.',
                    type: SnackbarType.warning,
                  );
                  return;
                }

                Navigator.pop(ctx); // Cerrar diálogo antes de procesar

                final error = await provider.sendPasswordResetEmail(email);
                if (error != null) {
                  if (mounted) {
                    AppSnackbar.show(
                      context,
                      message: error,
                      type: SnackbarType.error,
                    );
                  }
                } else {
                  if (mounted) {
                    AppSnackbar.show(
                      context,
                      message: 'Enlace enviado. Revisa tu bandeja de entrada.',
                      type: SnackbarType.success,
                    );
                  }
                }
              },
              child: const Text('Enviar enlace'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isLoginMode) ...[
              AppTextField(
                controller: widget.nameController,
                label: 'Nombre completo',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: _validateName,
              ),
              const SizedBox(height: 14),
            ],

            AppTextField(
              controller: widget.emailController,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),

            AppTextField(
              controller: widget.passwordController,
              label: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              obscureText: _obscurePassword,
              validator: _validatePassword,
            ),

            if (widget.isLoginMode) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      widget.isLoading ? null : _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 22),
            ],

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onAuthenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    widget.isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          widget.isLoginMode
                              ? 'Iniciar sesión'
                              : 'Crear cuenta',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
