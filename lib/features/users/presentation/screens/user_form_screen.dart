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
  String _role = AppRoles.customer;
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
      _role = widget.existingUser?.role ?? AppRoles.customer;
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
            context.pop(true); // Return true to indicate change
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              _isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: Colors.grey.shade200, height: 1),
            ),
          ),
          body: Stack(
            children: [
              Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        const Text(
                          'Selecciona el Rol',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                    () =>
                                        setState(() => _role = AppRoles.admin),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (_isEditing) ...[
                        _SectionCard(
                          title: 'Estado del Usuario',
                          icon: Icons.shield_rounded,
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
                                      _isActive
                                          ? 'Puede iniciar sesión'
                                          : 'Acceso bloqueado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            _isActive
                                                ? Colors.green.shade600
                                                : Colors.red.shade600,
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
                        ),
                        const SizedBox(height: 20),
                      ],

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
                            validator:
                                _isEditing
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
                                  controller: _passwordCtrl,
                                  label:
                                      _isEditing
                                          ? 'Nueva contraseña (opcional)'
                                          : 'Contraseña temporal',
                                  hint:
                                      _isEditing
                                          ? 'Dejar vacío para no cambiar'
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
                              if (!_isEditing) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Tooltip(
                                    message: 'Generar y copiar',
                                    child: ElevatedButton(
                                      onPressed: _generatePassword,
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

                      _SectionCard(
                        title: 'Datos Personales',
                        icon: Icons.badge_rounded,
                        children: [
                          _CustomTextField(
                            controller: _nameCtrl,
                            label: 'Nombre completo o Razón social',
                            hint: 'Ej. Juan Pérez',
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => _required(v, 'el nombre'),
                          ),
                          const SizedBox(height: 16),
                          _CustomTextField(
                            controller: _phoneCtrl,
                            label: 'Teléfono',
                            hint: 'Opcional',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
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
                      onPressed: isLoading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isEditing ? Colors.indigo : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          isLoading
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
                                    _isEditing
                                        ? Icons.save_rounded
                                        : Icons.person_add_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditing
                                        ? 'Guardar cambios'
                                        : (_role == AppRoles.admin
                                            ? 'Crear Administrador'
                                            : _role == AppRoles.employee
                                            ? 'Crear Empleado'
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                  color: isSelected ? color : Colors.grey.shade600,
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
