import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class UserFormScreen extends StatelessWidget {
  final String? initialRole;
  final UserEntity? existingUser;

  const UserFormScreen({super.key, this.initialRole, this.existingUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserFormCubit>(),
      child: _UserFormContent(
        initialRole: initialRole,
        existingUser: existingUser,
      ),
    );
  }
}

class _UserFormContent extends StatefulWidget {
  final String? initialRole;
  final UserEntity? existingUser;

  const _UserFormContent({this.initialRole, this.existingUser});

  @override
  State<_UserFormContent> createState() => _UserFormContentState();
}

class _UserFormContentState extends State<_UserFormContent> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _docCtrl;

  // Estados locales
  String _docType = 'DNI';
  late String _role;
  bool _isActive = true;
  bool _obscurePassword = true;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.existingUser?.fullName ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.existingUser?.email ?? '');
    _passwordCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: widget.existingUser?.phone ?? '');
    _docCtrl = TextEditingController(
      text: widget.existingUser?.documentNumber ?? '',
    );

    if (_isEditing) {
      _docType = widget.existingUser?.documentType ?? 'DNI';
      _role =
          widget.existingUser?.role ?? widget.initialRole ?? AppRoles.customer;
      _isActive = widget.existingUser?.isActive ?? true;
    } else {
      _role = widget.initialRole ?? AppRoles.customer;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $fieldName';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el correo electrónico';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un formato de correo válido (ej: usuario@dominio.com)';
    }
    return null;
  }

  String? _validateDocument(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Número de documento opcional
    }
    final clean = value.trim();
    if (_docType == 'DNI') {
      if (clean.length != 8) return 'El DNI debe tener 8 dígitos';
    } else if (_docType == 'RUC') {
      if (clean.length != 11) return 'El RUC debe tener 11 dígitos';
    } else if (clean.length < 4) {
      return 'Mínimo 4 caracteres';
    }
    return null;
  }

  List<TextInputFormatter> get _documentFormatters {
    if (_docType == 'DNI') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ];
    } else if (_docType == 'RUC') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ];
    } else {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
        LengthLimitingTextInputFormatter(15),
      ];
    }
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    final generated =
        List.generate(
          10,
          (index) => chars[random.nextInt(chars.length)],
        ).join();

    setState(() {
      _passwordCtrl.text = generated;
      _obscurePassword = false;
    });

    Clipboard.setData(ClipboardData(text: generated));
    AppSnackbar.show(
      context,
      message: 'Contraseña generada y copiada al portapapeles: $generated',
      type: SnackbarType.success,
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    context.read<UserFormCubit>().saveUser(
      id: widget.existingUser?.id,
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text.trim(),
      role: _role,
      phone: _phoneCtrl.text.trim(),
      documentType: _docType,
      documentNumber: _docCtrl.text.trim(),
      isActive: _isActive,
    );
  }

  void _onCancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserFormCubit, UserFormState>(
      listener: (context, state) {
        if (state is UserFormSuccess) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.success,
          );
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/admin/users');
          }
        } else if (state is UserFormError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is UserFormLoading;

        return AdminLayout(
          title: _isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
          showBackButton: true,
          showProfileButton: false,
          showDrawerButton: false,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── BANNER SUPERIOR INFORMATIVO ──────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              _isEditing
                                  ? Colors.indigo.shade50
                                  : AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _isEditing
                                    ? Colors.indigo.shade200
                                    : AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    _isEditing
                                        ? Colors.indigo.shade100
                                        : AppColors.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isEditing
                                    ? Icons.edit_note_rounded
                                    : Icons.person_add_alt_1_rounded,
                                color:
                                    _isEditing
                                        ? Colors.indigo.shade800
                                        : AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEditing
                                        ? 'Edición de Perfil de Usuario'
                                        : 'Creación de Nuevo Usuario',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _isEditing
                                              ? Colors.indigo.shade900
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isEditing
                                        ? 'Modifica los datos personales y el rol de acceso.'
                                        : 'El usuario se creará en el sistema con el rol preseleccionado.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          _isEditing
                                              ? Colors.indigo.shade700
                                              : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── SELECTOR DE ROL ──────────────
                      _SectionCard(
                        title: 'Rol y Permisos',
                        icon: Icons.shield_outlined,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _RoleCard(
                                  title: 'Cliente',
                                  icon: Icons.person_outline_rounded,
                                  isSelected: _role == AppRoles.customer,
                                  color: AppColors.primary,
                                  onTap:
                                      () => setState(
                                        () => _role = AppRoles.customer,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleCard(
                                  title: 'Empleado',
                                  icon: Icons.badge_outlined,
                                  isSelected: _role == AppRoles.employee,
                                  color: Colors.orange.shade600,
                                  onTap:
                                      () => setState(
                                        () => _role = AppRoles.employee,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RoleCard(
                                  title: 'Admin',
                                  icon: Icons.admin_panel_settings_outlined,
                                  isSelected: _role == AppRoles.admin,
                                  color: Colors.indigo,
                                  onTap:
                                      () => setState(
                                        () => _role = AppRoles.admin,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estado de la Cuenta',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isActive
                                          ? 'Activo: puede iniciar sesión y operar'
                                          : 'Inactivo: acceso suspendido',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            _isActive
                                                ? Colors.green.shade600
                                                : Colors.red.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _isActive,
                                  activeThumbColor: AppColors.primary,
                                  onChanged:
                                      (v) => setState(() => _isActive = v),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── CREDENCIALES DE ACCESO ──────────────
                      _SectionCard(
                        title: 'Credenciales de Acceso',
                        icon: Icons.lock_person_rounded,
                        children: [
                          _CustomTextField(
                            controller: _emailCtrl,
                            label: 'Correo Electrónico',
                            hint: 'ejemplo@correo.com',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isEditing,
                            suffixIcon:
                                _isEditing
                                    ? Tooltip(
                                      message:
                                          'El correo electrónico no puede ser alterado',
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                    )
                                    : null,
                            validator: _isEditing ? null : _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CustomTextField(
                                  controller: _passwordCtrl,
                                  label:
                                      _isEditing
                                          ? 'Nueva Contraseña (Opcional)'
                                          : 'Contraseña de Acceso',
                                  hint:
                                      _isEditing
                                          ? 'Dejar vacío para mantener la actual'
                                          : 'Mínimo 6 caracteres',
                                  icon: Icons.vpn_key_rounded,
                                  obscureText: _obscurePassword,
                                  validator: (v) {
                                    if (_isEditing) {
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
                                      _obscurePassword
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                    onPressed:
                                        () => setState(
                                          () =>
                                              _obscurePassword =
                                                  !_obscurePassword,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Tooltip(
                                  message: 'Generar clave segura y copiar',
                                  child: ElevatedButton(
                                    onPressed: _generatePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.surface,
                                      foregroundColor: AppColors.primary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── DATOS PERSONALES ──────────────
                      _SectionCard(
                        title: 'Datos Personales y Contacto',
                        icon: Icons.badge_rounded,
                        children: [
                          _CustomTextField(
                            controller: _nameCtrl,
                            label: 'Nombre completo o Razón social',
                            hint: 'Ej. Juan Pérez',
                            textCapitalization: TextCapitalization.words,
                            icon: Icons.person_rounded,
                            validator: (v) => _required(v, 'el nombre'),
                          ),
                          const SizedBox(height: 16),
                          _CustomTextField(
                            controller: _phoneCtrl,
                            label: 'Teléfono o WhatsApp',
                            hint: 'Ej. 987654321 (Opcional)',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Documento de Identidad',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _docType,
                                    isExpanded: true,
                                    icon: Icon(
                                      Icons.expand_more_rounded,
                                      color: Colors.grey.shade500,
                                    ),
                                    items:
                                        ['DNI', 'RUC', 'CE', 'PAS'].map((
                                          String value,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _docType = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CustomTextField(
                                  controller: _docCtrl,
                                  hint:
                                      _docType == 'DNI'
                                          ? '8 dígitos'
                                          : _docType == 'RUC'
                                          ? '11 dígitos'
                                          : 'N° de documento',
                                  keyboardType:
                                      (_docType == 'DNI' || _docType == 'RUC')
                                          ? TextInputType.number
                                          : TextInputType.text,
                                  inputFormatters: _documentFormatters,
                                  validator: _validateDocument,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ─── BARRA DE ACCIÓN INTEGRADA (DESKTOP Y MÓVIL) ─────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: isLoading ? null : _onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _onSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isEditing
                                          ? Colors.indigo.shade700
                                          : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child:
                                    isLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _isEditing
                                                  ? Icons.save_rounded
                                                  : Icons.person_add_rounded,
                                              size: 19,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isEditing
                                                  ? 'Guardar Cambios'
                                                  : (_role == AppRoles.admin
                                                      ? 'Crear Administrador'
                                                      : _role ==
                                                          AppRoles.employee
                                                      ? 'Crear Empleado'
                                                      : 'Crear Cliente'),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
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
          const SizedBox(height: 18),
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
  final List<TextInputFormatter>? inputFormatters;

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
    this.inputFormatters,
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
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : Colors.black87,
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
