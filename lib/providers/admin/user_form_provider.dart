import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserFormProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // Controladores
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final docCtrl = TextEditingController();

  // Estados
  String docType = 'DNI';
  String role = AppRoles.customer;
  bool isActive = true;
  bool obscurePassword = true;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  final Map<String, dynamic>? existingUser;
  bool get isEditing => existingUser != null;

  UserFormProvider({this.existingUser, String? initialRole}) {
    if (isEditing) {
      final u = existingUser!;
      nameCtrl.text = u['full_name'] ?? '';
      emailCtrl.text = u['email'] ?? '';
      phoneCtrl.text = u['phone'] ?? '';
      docCtrl.text = u['document_number'] ?? '';
      docType = u['document_type'] ?? 'DNI';
      role = u['role'] ?? AppRoles.customer;
      isActive = u['is_active'] ?? true;
    } else {
      role = initialRole ?? AppRoles.customer;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    phoneCtrl.dispose();
    docCtrl.dispose();
    super.dispose();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setRole(String newRole) {
    role = newRole;
    notifyListeners();
  }

  void setDocType(String newType) {
    docType = newType;
    notifyListeners();
  }

  void toggleActive(bool value) {
    isActive = value;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void generatePassword(BuildContext context) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    final generated =
        List.generate(
          10,
          (index) => chars[random.nextInt(chars.length)],
        ).join();

    passwordCtrl.text = generated;
    obscurePassword = false;
    notifyListeners();

    Clipboard.setData(ClipboardData(text: generated));
    _successMessage =
        'Contraseña generada y copiada al portapapeles: $generated';
    notifyListeners();
  }

  Future<bool> saveUser() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (isEditing) {
        await _updateUser();
      } else {
        await _createUser();
      }
      return true;
    } catch (e) {
      debugPrint('Error saving user form: $e');
      if (e.toString().contains('already been registered')) {
        _errorMessage = 'Este correo ya está registrado en el sistema.';
      } else {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
          _errorMessage = 'Sin conexión a internet.';
        } else {
          _errorMessage = 'Error inesperado al guardar el usuario.';
        }
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createUser() async {
    final response = await _supabase.functions.invoke(
      'crear-usuario-admin',
      body: {
        'email': emailCtrl.text.trim(),
        'password': passwordCtrl.text,
        'role': role,
        'name': nameCtrl.text.trim(),
        'phone':
            phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
        'document_type': docType,
        'document_number':
            docCtrl.text.trim().isNotEmpty ? docCtrl.text.trim() : null,
      },
    );

    if (response.status != 200) {
      throw Exception('Error al crear usuario: ${response.data}');
    }

    _successMessage = 'Usuario creado exitosamente';
  }

  Future<void> _updateUser() async {
    final profileId = existingUser!['id'];

    // 1. Actualizar perfil
    await _supabase
        .from('profiles')
        .update({
          'full_name': nameCtrl.text.trim(),
          'phone':
              phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          'document_type': docType,
          'document_number':
              docCtrl.text.trim().isNotEmpty ? docCtrl.text.trim() : null,
          'role': role,
          'is_active': isActive,
        })
        .eq('id', profileId);

    // 2. Si cambió la contraseña, actualizarla vía Edge Function
    if (passwordCtrl.text.trim().isNotEmpty) {
      final pwResponse = await _supabase.functions.invoke(
        'actualizar-password-admin',
        body: {
          'auth_user_id': existingUser!['auth_user_id'],
          'new_password': passwordCtrl.text,
        },
      );
      if (pwResponse.status != 200) {
        throw Exception(
          'Perfil guardado, pero error al cambiar contraseña: ${pwResponse.data}',
        );
      }
    }

    _successMessage = 'Usuario actualizado correctamente';
  }
}
