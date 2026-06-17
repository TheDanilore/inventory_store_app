import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/user_form_provider.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class UserFormScreen extends StatelessWidget {
  final String? initialRole;
  final Map<String, dynamic>? existingUser;

  const UserFormScreen({super.key, this.initialRole, this.existingUser});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => UserFormProvider(
            existingUser: existingUser,
            initialRole: initialRole,
          ),
      child: const _UserFormContent(),
    );
  }
}

class _UserFormContent extends StatefulWidget {
  const _UserFormContent();

  @override
  State<_UserFormContent> createState() => _UserFormContentState();
}

class _UserFormContentState extends State<_UserFormContent> {
  final _formKey = GlobalKey<FormState>();

  void _handleProviderMessages(
    BuildContext context,
    UserFormProvider provider,
  ) {
    if (provider.errorMessage != null) {
      AppSnackbar.show(
        context,
        message: provider.errorMessage!,
        type: SnackbarType.error,
      );
      provider.clearMessages();
    } else if (provider.successMessage != null) {
      AppSnackbar.show(
        context,
        message: provider.successMessage!,
        type: SnackbarType.success,
      );
      provider.clearMessages();
    }
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $fieldName';
    return null;
  }

  Future<void> _onSave(UserFormProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await provider.saveUser();
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserFormProvider>(
      builder: (context, provider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleProviderMessages(context, provider);
        });

        final isEditing = provider.isEditing;

        return AdminLayout(
          title: isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
          showBackButton: true,
          showProfileButton: false,
          showDrawerButton: false,
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 100,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── SELECTOR DE ROL ─────────────────────────────────────
                      const Text(
                        'Tipo de cuenta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'Cliente',
                              icon: Icons.people_alt_rounded,
                              isSelected: provider.role == AppRoles.customer,
                              color: AppColors.primary,
                              onTap: () => provider.setRole(AppRoles.customer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'Administrador',
                              icon: Icons.admin_panel_settings_rounded,
                              isSelected: provider.role == AppRoles.admin,
                              color: Colors.indigo,
                              onTap: () => provider.setRole(AppRoles.admin),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── ESTADO ACTIVO (solo en modo edición) ────────────────
                      if (isEditing) ...[
                        _SectionCard(
                          title: 'Estado de la cuenta',
                          icon: Icons.toggle_on_rounded,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Usuario activo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      provider.isActive
                                          ? 'Puede iniciar sesión'
                                          : 'Acceso bloqueado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            provider.isActive
                                                ? Colors.green.shade600
                                                : Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: provider.isActive,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: provider.toggleActive,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ─── CREDENCIALES ────────────────────────────────────────
                      _SectionCard(
                        title: 'Credenciales de Acceso',
                        icon: Icons.lock_person_rounded,
                        children: [
                          _CustomTextField(
                            controller: provider.emailCtrl,
                            label: 'Correo Electrónico',
                            hint: 'ejemplo@correo.com',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: isEditing,
                            validator:
                                isEditing
                                    ? null
                                    : (v) =>
                                        _required(v, 'el correo electrónico'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CustomTextField(
                                  controller: provider.passwordCtrl,
                                  label:
                                      isEditing
                                          ? 'Nueva contraseña (opcional)'
                                          : 'Contraseña temporal',
                                  hint:
                                      isEditing
                                          ? 'Dejar vacío para no cambiar'
                                          : 'Mínimo 6 caracteres',
                                  icon: Icons.vpn_key_rounded,
                                  obscureText: provider.obscurePassword,
                                  validator: (v) {
                                    if (isEditing) {
                                      if (v != null &&
                                          v.isNotEmpty &&
                                          v.length < 6) {
                                        return 'Mínimo 6 caracteres';
                                      }
                                      return null;
                                    }
                                    if (v == null || v.isEmpty) {
                                      return 'Ingresa una contraseña';
                                    }
                                    if (v.length < 6) {
                                      return 'Mínimo 6 caracteres';
                                    }
                                    return null;
                                  },
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      provider.obscurePassword
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                    onPressed:
                                        provider.togglePasswordVisibility,
                                  ),
                                ),
                              ),
                              if (!isEditing) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24,
                                  ), // Alinear con el input (debajo del label)
                                  child: Tooltip(
                                    message: 'Generar y copiar',
                                    child: ElevatedButton(
                                      onPressed:
                                          () => provider.generatePassword(
                                            context,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.surface,
                                        foregroundColor: AppColors.primary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.password_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── DATOS PERSONALES ────────────────────────────────────
                      _SectionCard(
                        title: 'Datos Personales',
                        icon: Icons.person_rounded,
                        children: [
                          _CustomTextField(
                            controller: provider.nameCtrl,
                            label: 'Nombre completo',
                            hint: 'Nombres y Apellidos',
                            icon: Icons.badge_rounded,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => _required(v, 'el nombre'),
                          ),
                          const SizedBox(height: 16),
                          _CustomTextField(
                            controller: provider.phoneCtrl,
                            label: 'Teléfono (Opcional)',
                            hint: 'Ej. 987654321',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Documento de Identidad (Opcional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: provider.docType,
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Colors.grey,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    items:
                                        ['DNI', 'CE', 'RUC', 'PASAPORTE']
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(
                                                  type,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      if (val != null) provider.setDocType(val);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CustomTextField(
                                  controller: provider.docCtrl,
                                  hint: 'Número de documento',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── BOTÓN FIJO INFERIOR ─────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          provider.isLoading ? null : () => _onSave(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isEditing ? Colors.indigo : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          provider.isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isEditing
                                        ? Icons.save_rounded
                                        : Icons.person_add_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing
                                        ? 'Guardar cambios'
                                        : (provider.role == AppRoles.admin
                                            ? 'Crear Administrador'
                                            : 'Crear Cliente'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const _CustomTextField({
    required this.controller,
    this.label,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade500 : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon:
                icon != null
                    ? Icon(icon, size: 18, color: Colors.grey.shade400)
                    : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? Colors.grey.shade300 : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
