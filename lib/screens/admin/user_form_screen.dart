import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';

class UserFormScreen extends StatefulWidget {
  final String initialRole;

  const UserFormScreen({super.key, required this.initialRole});

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

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
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

  void _showMessage(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    AppSnackbar.show(context, message: text, backgroundColor: color);
  }

  String? _required(String? value, String field) {
    if ((value ?? '').trim().isEmpty) return 'Ingresa $field';
    return null;
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await _supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('No se pudo crear el usuario de autenticación.');
      }

      await _supabase.from('profiles').upsert(
        {
          'auth_user_id': authUser.id,
          'full_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'document_type': _docType,
          'document_number': _docCtrl.text.trim(),
          'role': _role,
          'is_active': true,
        },
        onConflict: 'auth_user_id',
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: _role == AppRoles.admin
            ? 'Administrador creado con éxito.'
            : 'Cliente creado con éxito.',
        backgroundColor: AppColors.success,
      );
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('No se pudo crear el usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _role == AppRoles.admin ? 'Nuevo administrador' : 'Nuevo cliente',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de usuario',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppRoles.customer,
                            child: Text('Cliente'),
                          ),
                          DropdownMenuItem(
                            value: AppRoles.admin,
                            child: Text('Administrador'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _role = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Nombre completo',
                        icon: Icons.person,
                        validator: (v) => _required(v, 'el nombre completo'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _emailCtrl,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => _required(v, 'el correo'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _passwordCtrl,
                        label: 'Contraseña temporal',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (v) => _required(v, 'la contraseña'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'Teléfono',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => _required(v, 'el teléfono'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _docType,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de documento',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                                DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                                DropdownMenuItem(value: 'CE', child: Text('CE')),
                                DropdownMenuItem(
                                  value: 'PASAPORTE',
                                  child: Text('Pasaporte'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _docType = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _docCtrl,
                              label: 'Número de documento',
                              icon: Icons.badge_outlined,
                              validator: (v) => _required(v, 'el documento'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppPrimaryButton(
                        label:
                            _role == AppRoles.admin
                                ? 'Crear administrador'
                                : 'Crear cliente',
                        onPressed: _isLoading ? null : _saveUser,
                        icon: const Icon(Icons.save, color: Colors.white),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
