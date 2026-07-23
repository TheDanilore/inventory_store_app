import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

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
  bool _isButtonPressed = false;

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
    final cubit = context.read<AuthCubit>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget buildResetContent(BuildContext ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recuperar contraseña',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo electrónico para enviarte un enlace de recuperación.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: emailCtrl,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              AppPrimaryButton(
                label: 'Enviar enlace',
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

                  Navigator.pop(ctx);

                  final error = await cubit.resetPassword(email);
                  if (mounted) {
                    if (error != null) {
                      AppSnackbar.show(
                        context,
                        message: error,
                        type: SnackbarType.error,
                      );
                    } else {
                      AppSnackbar.show(
                        context,
                        message: 'Enlace enviado. Revisa tu bandeja de entrada.',
                        type: SnackbarType.success,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      );
    }

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                buildResetContent(ctx),
              ],
            ),
          );
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: SizedBox(
              width: 400,
              child: buildResetContent(ctx),
            ),
          );
        },
      );
    }

    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
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
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: 14),
            ],

            AppTextField(
              controller: widget.emailController,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),

            AppTextField(
              controller: widget.passwordController,
              label: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: widget.isLoading
                  ? null
                  : (_) => widget.onAuthenticate(),
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

            GestureDetector(
              onTapDown:
                  widget.isLoading
                      ? null
                      : (_) => setState(() => _isButtonPressed = true),
              onTapUp:
                  widget.isLoading
                      ? null
                      : (_) => setState(() => _isButtonPressed = false),
              onTapCancel:
                  widget.isLoading
                      ? null
                      : () => setState(() => _isButtonPressed = false),
              child: AnimatedScale(
                scale: _isButtonPressed ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : widget.onAuthenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
