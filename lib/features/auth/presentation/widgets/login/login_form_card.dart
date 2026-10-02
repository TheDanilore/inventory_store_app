import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
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
  late final ValueNotifier<bool> _obscurePasswordNotifier;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _obscurePasswordNotifier = ValueNotifier<bool>(true);
  }

  @override
  void dispose() {
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (widget.isLoginMode) return null;
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Ingresa tu nombre completo';
    if (name.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    if (name.length > 80) return 'El nombre no puede exceder 80 caracteres';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Ingresa tu correo';
    if (!_emailRegex.hasMatch(email)) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.trim().isEmpty) return 'Ingresa tu contraseña';
    if (!widget.isLoginMode && password.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    return null;
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(
      text: widget.emailController.text.trim(),
    );
    final cubit = context.read<AuthCubit>();
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    try {
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
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
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
                  _ForgotPasswordDialogContent(
                    emailController: emailCtrl,
                    emailRegex: _emailRegex,
                    onSend: (email) async {
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
                            message:
                                'Enlace enviado. Revisa tu bandeja de entrada.',
                            type: SnackbarType.success,
                          );
                        }
                      }
                    },
                  ),
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
                child: _ForgotPasswordDialogContent(
                  emailController: emailCtrl,
                  emailRegex: _emailRegex,
                  onSend: (email) async {
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
                          message:
                              'Enlace enviado. Revisa tu bandeja de entrada.',
                          type: SnackbarType.success,
                        );
                      }
                    }
                  },
                ),
              ),
            );
          },
        );
      }
    } finally {
      emailCtrl.dispose();
    }
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
      child: AutofillGroup(
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
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
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
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),

              ValueListenableBuilder<bool>(
                valueListenable: _obscurePasswordNotifier,
                builder: (context, obscure, _) {
                  return AppTextField(
                    controller: widget.passwordController,
                    label: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      widget.isLoginMode
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    onFieldSubmitted:
                        widget.isLoading
                            ? null
                            : (_) => widget.onAuthenticate(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed:
                          () => _obscurePasswordNotifier.value = !obscure,
                    ),
                    obscureText: obscure,
                    validator: _validatePassword,
                  );
                },
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

              _SubmitButton(
                isLoading: widget.isLoading,
                isLoginMode: widget.isLoginMode,
                onPressed: widget.onAuthenticate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final bool isLoginMode;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.isLoginMode,
    required this.onPressed,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _isButtonPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            onPressed: widget.isLoading ? null : widget.onPressed,
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
                      widget.isLoginMode ? 'Iniciar sesión' : 'Crear cuenta',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialogContent extends StatefulWidget {
  final TextEditingController emailController;
  final RegExp emailRegex;
  final Future<void> Function(String email) onSend;

  const _ForgotPasswordDialogContent({
    required this.emailController,
    required this.emailRegex,
    required this.onSend,
  });

  @override
  State<_ForgotPasswordDialogContent> createState() =>
      _ForgotPasswordDialogContentState();
}

class _ForgotPasswordDialogContentState
    extends State<_ForgotPasswordDialogContent> {
  bool _isSending = false;

  Future<void> _handleSubmit() async {
    if (_isSending) return;
    final email = widget.emailController.text.trim();
    if (email.isEmpty || !widget.emailRegex.hasMatch(email)) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un correo electrónico válido.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isSending = true);
    await widget.onSend(email);
  }

  @override
  Widget build(BuildContext context) {
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
          controller: widget.emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSending ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSending ? null : _handleSubmit,
              child:
                  _isSending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Enviar enlace',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        ),
      ],
    );
  }
}
