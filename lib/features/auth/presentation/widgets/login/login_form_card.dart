import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/login/login_button.dart';

class LoginFormCard extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoginMode;
  final bool isLoading;
  final bool isSuccess;
  final bool isFlat;
  final VoidCallback onAuthenticate;

  const LoginFormCard({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.isLoginMode,
    required this.isLoading,
    this.isSuccess = false,
    this.isFlat = false,
    required this.onAuthenticate,
  });

  @override
  State<LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends State<LoginFormCard> {
  final ValueNotifier<bool> _obscurePasswordNotifier = ValueNotifier<bool>(
    true,
  );

  @override
  void dispose() {
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (widget.isLoginMode) return null;
    final val = value?.trim() ?? '';
    if (val.isEmpty) return 'Ingresa tu nombre completo';
    if (val.length < 3) return 'Mínimo 3 caracteres';
    return null;
  }

  String? _validateEmail(String? value) {
    final val = value?.trim() ?? '';
    if (val.isEmpty) return 'Ingresa tu correo';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    if (!emailRegex.hasMatch(val)) return 'Ingresa un correo válido';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: widget.emailController.text);
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );

    try {
      showDialog(
        context: context,
        builder:
            (dialogContext) => _ForgotPasswordDialogContent(
              emailController: emailCtrl,
              emailRegex: emailRegex,
              onSend: (email) => _sendPasswordResetEmail(dialogContext, email),
            ),
      );
    } catch (_) {
      emailCtrl.dispose();
    }
  }

  Future<void> _sendPasswordResetEmail(
    BuildContext dialogContext,
    String email,
  ) async {
    final emailCtrl = TextEditingController(text: email);
    try {
      final cubit = context.read<AuthCubit>();
      final errorMsg = await cubit.resetPassword(email);

      if (!dialogContext.mounted) return;

      if (errorMsg == null) {
        Navigator.pop(dialogContext);
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.',
            type: SnackbarType.success,
          );
        }
      } else {
        AppSnackbar.show(
          dialogContext,
          message: errorMsg,
          type: SnackbarType.error,
        );
      }
    } finally {
      emailCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cyanLinkColor =
        isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2);

    return Container(
      padding: widget.isFlat ? EdgeInsets.zero : const EdgeInsets.all(24),
      decoration:
          widget.isFlat
              ? null
              : (isDark
                  ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppColors.radiusXl),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  )
                  : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppColors.radiusXl),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  )),
      child: AutofillGroup(
        child: Form(
          key: widget.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Acordeón ultra-fluido para el campo de Nombre sin parpadeos
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child:
                    !widget.isLoginMode
                        ? Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _GlassField(
                            controller: widget.nameController,
                            label: 'Nombre completo',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: _validateName,
                          ),
                        )
                        : const SizedBox.shrink(),
              ),

              _GlassField(
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
                  final suffix = IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder:
                          (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                      child: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey<bool>(obscure),
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.62)
                                : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    onPressed: () => _obscurePasswordNotifier.value = !obscure,
                  );

                  return _GlassField(
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
                    suffixIcon: suffix,
                    obscureText: obscure,
                    validator: _validatePassword,
                  );
                },
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child:
                    widget.isLoginMode
                        ? Column(
                          children: [
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    widget.isLoading
                                        ? null
                                        : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: cyanLinkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                        : const SizedBox(height: 20),
              ),

              LoginButton(
                isLoading: widget.isLoading,
                isSuccess: widget.isSuccess,
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

/// Campo de texto adaptable para el login:
/// En Modo Oscuro: translúcido oscuro con resplandor cian (#22D3EE) y texto blanco.
/// En Modo Claro: fondo gris muy claro (#F8FAFC) con bordes suaves, iconos cian (#0891B2) y texto marino.
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final bool obscureText;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onFieldSubmitted,
    this.validator,
    this.suffixIcon,
    this.obscureText = false,
  });

  static const _cyanBright = Color(0xFF22D3EE);
  static const _cyanDark = Color(0xFF0891B2);

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cyanColor = isDark ? _cyanBright : _cyanDark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      obscureText: obscureText,
      cursorColor: cyanColor,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.48)
                  : const Color(0xFF94A3B8),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: cyanColor.withValues(alpha: isDark ? 0.9 : 1.0),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 16,
        ),
        errorStyle: TextStyle(
          color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: _border(
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFE2E8F0),
        ),
        focusedBorder: _border(cyanColor, 1.6),
        errorBorder: _border(
          isDark ? const Color(0xFFF87171) : AppColors.error,
        ),
        focusedErrorBorder: _border(
          isDark ? const Color(0xFFF87171) : AppColors.error,
          1.6,
        ),
        border: _border(
          isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFE2E8F0),
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
  final _dialogFormKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!(_dialogFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSend(widget.emailController.text.trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0B1E3A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        side: BorderSide(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFE2E8F0),
        ),
      ),
      title: Text(
        'Recuperar Contraseña',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Form(
        key: _dialogFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa tu correo para enviarte las instrucciones de restablecimiento.',
              style: TextStyle(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.66)
                        : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _GlassField(
              controller: widget.emailController,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.isEmpty) return 'Ingresa tu correo';
                if (!widget.emailRegex.hasMatch(text)) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor:
                isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0891B2),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text(
                    'Enviar Enlace',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
        ),
      ],
    );
  }
}
