import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _obscureConfirm = ValueNotifier<bool>(true);
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _obscurePassword.dispose();
    _obscureConfirm.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackbar.show(
        context,
        message: 'Por favor corrige los campos con error.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    final cubit = context.read<AuthCubit>();
    final newPassword = _passwordController.text;

    final success = await cubit.changePassword(newPassword);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AppSnackbar.show(
        context,
        message: '¡Contraseña actualizada con éxito! Inicia sesión con tu nueva clave.',
        type: SnackbarType.success,
      );
      // Cierra la sesión temporal de recuperación
      await cubit.logout();
      if (mounted) {
        context.go('/login');
      }
    } else {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage ?? 'No se pudo actualizar la contraseña. El enlace pudo haber expirado.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Danilore One Logo
                    Center(
                      child: Container(
                        height: 90,
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Image.asset('assets/logo_full.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icono y Título
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Restablecer Contraseña',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresa tu nueva contraseña para volver a acceder a tu cuenta.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Campo: Nueva Contraseña
                    ValueListenableBuilder<bool>(
                      valueListenable: _obscurePassword,
                      builder: (context, obscure, _) {
                        return AppTextField(
                          controller: _passwordController,
                          label: 'Nueva Contraseña',
                          hintText: 'Mínimo 6 caracteres',
                          icon: Icons.lock_outline_rounded,
                          obscureText: obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => _obscurePassword.value = !obscure,
                          ),
                          validator: (val) {
                            final text = val ?? '';
                            if (text.isEmpty) return 'Ingresa una nueva contraseña';
                            if (text.length < 6) return 'Debe tener al menos 6 caracteres';
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campo: Confirmar Contraseña
                    ValueListenableBuilder<bool>(
                      valueListenable: _obscureConfirm,
                      builder: (context, obscure, _) {
                        return AppTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar Contraseña',
                          hintText: 'Repite tu nueva contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscureText: obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => _obscureConfirm.value = !obscure,
                          ),
                          validator: (val) {
                            if (val != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Botón de Enviar
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _onSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar Nueva Contraseña',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Volver a login
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Volver al inicio de sesión',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
