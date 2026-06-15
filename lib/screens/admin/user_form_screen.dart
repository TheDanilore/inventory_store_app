import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class UserFormScreen extends StatefulWidget {
  final String? initialRole;

  /// Si se pasa [existingUser], el formulario opera en modo EDICIÓN.
  final Map<String, dynamic>? existingUser;

  const UserFormScreen({super.key, this.initialRole, this.existingUser});

  /// Modo edición
  bool get isEditing => existingUser != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docCtrl = TextEditingController();

  String _docType = 'DNI';
  late String _role;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      // Modo edición: pre-llenamos los campos
      final u = widget.existingUser!;
      _nameCtrl.text = u['full_name'] ?? '';
      _emailCtrl.text = u['email'] ?? '';
      _phoneCtrl.text = u['phone'] ?? '';
      _docCtrl.text = u['document_number'] ?? '';
      _docType = u['document_type'] ?? 'DNI';
      _role = u['role'] ?? AppRoles.customer;
      _isActive = u['is_active'] ?? true;
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

  // ─── CREAR USUARIO ──────────────────────────────────────────────────────────
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.functions.invoke(
        'crear-usuario-admin',
        body: {
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role': _role,
          'name': _nameCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          'document_type': _docType,
          'document_number':
              _docCtrl.text.trim().isNotEmpty ? _docCtrl.text.trim() : null,
        },
      );

      if (response.status != 200) {
        throw Exception('Error al crear usuario: ${response.data}');
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Usuario creado exitosamente',
          type: SnackbarType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String mensajeError = 'Ocurrió un error inesperado.';
        if (e.toString().contains('already been registered')) {
          mensajeError = 'Este correo ya está registrado en el sistema.';
        } else {
          mensajeError = 'Error: $e';
        }
        AppSnackbar.show(
          context,
          message: mensajeError,
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── EDITAR USUARIO ─────────────────────────────────────────────────────────
  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final profileId = widget.existingUser!['id'];

      // 1. Actualizar datos del perfil en la tabla profiles
      await _supabase
          .from('profiles')
          .update({
            'full_name': _nameCtrl.text.trim(),
            'phone':
                _phoneCtrl.text.trim().isNotEmpty
                    ? _phoneCtrl.text.trim()
                    : null,
            'document_type': _docType,
            'document_number':
                _docCtrl.text.trim().isNotEmpty ? _docCtrl.text.trim() : null,
            'role': _role,
            'is_active': _isActive,
          })
          .eq('id', profileId);

      // 2. Si cambió la contraseña, actualizarla vía Edge Function
      if (_passwordCtrl.text.trim().isNotEmpty) {
        final pwResponse = await _supabase.functions.invoke(
          'actualizar-password-admin',
          body: {
            'auth_user_id': widget.existingUser!['auth_user_id'],
            'new_password': _passwordCtrl.text,
          },
        );
        if (pwResponse.status != 200) {
          throw Exception(
            'Perfil guardado, pero error al cambiar contraseña: ${pwResponse.data}',
          );
        }
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Usuario actualizado correctamente',
          type: SnackbarType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                            isSelected: _role == AppRoles.customer,
                            color: AppColors.primary,
                            onTap:
                                () => setState(() => _role = AppRoles.customer),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            title: 'Administrador',
                            icon: Icons.admin_panel_settings_rounded,
                            isSelected: _role == AppRoles.admin,
                            color: Colors.indigo,
                            onTap: () => setState(() => _role = AppRoles.admin),
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
                                    (val) => setState(() => _isActive = val),
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
                          controller: _emailCtrl,
                          label: 'Correo Electrónico',
                          hint: 'ejemplo@correo.com',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          // En edición el email es solo lectura
                          readOnly: isEditing,
                          validator:
                              isEditing
                                  ? null
                                  : (v) =>
                                      _required(v, 'el correo electrónico'),
                        ),
                        const SizedBox(height: 16),
                        _CustomTextField(
                          controller: _passwordCtrl,
                          label:
                              isEditing
                                  ? 'Nueva contraseña (opcional)'
                                  : 'Contraseña temporal',
                          hint:
                              isEditing
                                  ? 'Dejar vacío para no cambiar'
                                  : 'Mínimo 6 caracteres',
                          icon: Icons.vpn_key_rounded,
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (isEditing) {
                              // Solo validar si se ingresó algo
                              if (v != null && v.isNotEmpty && v.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            }
                            if (v == null || v.isEmpty) {
                              return 'Ingresa una contraseña';
                            }
                            if (v.length < 6) return 'Mínimo 6 caracteres';
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
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
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
                          controller: _nameCtrl,
                          label: 'Nombre completo',
                          hint: 'Nombres y Apellidos',
                          icon: Icons.badge_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => _required(v, 'el nombre'),
                        ),
                        const SizedBox(height: 16),
                        _CustomTextField(
                          controller: _phoneCtrl,
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
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _docType,
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
          ),

          // ─── BOTÓN FIJO INFERIOR ─────────────────────────────────────────
          Container(
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
                    _isLoading ? null : (isEditing ? _updateUser : _createUser),
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
                    _isLoading
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
                                  : (_role == AppRoles.admin
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
        ],
      ),
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
