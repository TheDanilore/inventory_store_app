import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';

class UserFormAccessSection extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool isEditing;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onGeneratePassword;
  final VoidCallback onSubmitted;

  const UserFormAccessSection({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.isEditing,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onGeneratePassword,
    required this.onSubmitted,
  });

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el correo electrónico';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Revisa el formato (ej: usuario@dominio.com)';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (isEditing) {
      if (v != null && v.isNotEmpty && v.length < 6) {
        return 'Mínimo 6 caracteres';
      }
      return null;
    }
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return UserFormSectionCard(
      title: 'Acceso al sistema',
      subtitle: 'Con estas credenciales el colaborador iniciará sesión.',
      icon: Icons.lock_person_rounded,
      children: [
        UserFormCustomTextField(
          controller: emailCtrl,
          label: 'Correo electrónico',
          required: !isEditing,
          hint: 'ejemplo@correo.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          readOnly: isEditing,
          textInputAction: TextInputAction.next,
          helper: isEditing ? 'El correo no se puede modificar.' : null,
          suffixIcon:
              isEditing
                  ? Tooltip(
                    message: 'El correo electrónico no puede ser alterado',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  )
                  : null,
          validator: isEditing ? null : _validateEmail,
        ),
        const SizedBox(height: 18),
        UserFormCustomTextField(
          controller: passwordCtrl,
          label: isEditing ? 'Nueva contraseña' : 'Contraseña',
          required: !isEditing,
          optional: isEditing,
          hint: 'Escribe o genera una contraseña',
          icon: Icons.key_rounded,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          validator: _validatePassword,
          suffixIcon: IconButton(
            tooltip: obscurePassword ? 'Mostrar' : 'Ocultar',
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey.shade600,
              size: 20,
            ),
            onPressed: onToggleObscure,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: passwordCtrl,
                builder: (context, _) {
                  if (passwordCtrl.text.isEmpty) {
                    return Text(
                      isEditing
                          ? 'Déjala vacía para mantener la actual.'
                          : 'Mínimo 6 caracteres.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }
                  return UserFormPasswordStrength(password: passwordCtrl.text);
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Genera una clave segura y la copia al portapapeles',
              child: TextButton.icon(
                onPressed: onGeneratePassword,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Generar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
