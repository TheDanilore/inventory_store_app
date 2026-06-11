import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/customer/customer_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // 1. Agregamos el controlador del nombre
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _nameController.dispose(); // No olvides liberar el controlador
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Session & Auth ───────────────────────────────────────────────────────

  Future<void> _checkSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null) _redirectUser(session.user);
  }

  String _authErrorMessage(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final message = e.message.toLowerCase();
    if (code.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (code.contains('email_not_confirmed') ||
        message.contains('email not confirmed')) {
      return 'Tu correo aún no está confirmado. Revisa tu bandeja.';
    }
    if (code.contains('user_already_exists') ||
        message.contains('already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (code.contains('weak_password') || message.contains('weak password')) {
      return 'Contraseña muy débil. Usa al menos 8 caracteres.';
    }
    if (code.contains('network') || message.contains('failed to fetch')) {
      return 'Sin conexión a internet. Intenta nuevamente.';
    }
    return 'No se pudo completar la autenticación. Intenta otra vez.';
  }

  void _showMessage(String text, {SnackbarType type = SnackbarType.error}) {
    if (!mounted) return;
    AppSnackbar.show(context, message: text, type: type);
  }

  // 2. Validación para el nombre
  String? _validateName(String? value) {
    if (_isLoginMode) return null; // Si es login, no validamos el nombre
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Ingresa tu nombre completo';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Ingresa tu correo';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = (value ?? '').trim();
    if (password.isEmpty) return 'Ingresa tu contraseña';
    if (!_isLoginMode && password.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  Future<void> _redirectUser(User user) async {
    try {
      // 1. Añadimos 'is_active' al select
      final data =
          await _supabase
              .from('profiles')
              .select('role, is_active')
              .eq('auth_user_id', user.id)
              .single();

      if (!mounted) return;

      // 2. Validamos si el usuario está desactivado
      if (data['is_active'] == false) {
        // Cerramos la sesión de Supabase inmediatamente
        await _supabase.auth.signOut();

        // Mostramos el mensaje de error y detenemos el flujo
        _showMessage(
          'Tu cuenta ha sido desactivada. Contacta al administrador.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. Si está activo, procedemos con la redirección normal
      final dest =
          data['role'] == AppRoles.admin
              ? const AdminCatalogScreen()
              : const CustomerMainScreen();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => dest,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // 4. Por seguridad, si falla la lectura del perfil, cerramos la sesión
      await _supabase.auth.signOut();
      _showMessage('Error al verificar el perfil. Intenta nuevamente.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage(
        'Revisa los campos obligatorios.',
        type: SnackbarType.warning,
      );
      return;
    }

    final name = _nameController.text.trim(); // Obtenemos el nombre
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_isLoginMode) {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // 3. Enviamos los datos en signUp (opcional, guarda en auth metadata)
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );

        if (response.user != null) {
          try {
            // 4. Agregamos el "full_name" a la creación de la tabla profiles
            await _supabase.from('profiles').upsert({
              'auth_user_id': response.user!.id,
              'full_name': name, // << CAMBIO CLAVE AQUÍ
              'role': AppRoles.customer,
              'is_active': true,
            }, onConflict: 'auth_user_id');
          } catch (e) {
            debugPrint('Error creando perfil mínimo: $e');
          }
        }
        if (mounted) {
          _showMessage(
            'Registro exitoso. Confirma tu correo si es necesario.',
            type: SnackbarType.success,
          );
        }
      }
      _checkSession();
    } on AuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (error) {
      _showMessage('Error inesperado: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      // Limpiamos los campos al cambiar de modo
      if (_isLoginMode) _nameController.clear();
    });
    _fadeCtrl.forward(from: 0);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative top blob ─────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onPressed:
                          () => Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) => const CustomerMainScreen(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          ),
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Logo + headline ───────────────────────
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            Color(0xFF0F3460),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.30,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      _isLoginMode
                                          ? 'Bienvenido de nuevo'
                                          : 'Crea tu cuenta',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.6,
                                        height: 1.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isLoginMode
                                          ? 'Ingresa para continuar comprando'
                                          : 'Completa tus datos para empezar',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // ── Form card ─────────────────────────────
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 5. Agregamos el campo Nombre (Solo en Registro)
                                    if (!_isLoginMode) ...[
                                      AppTextField(
                                        controller: _nameController,
                                        label: 'Nombre completo',
                                        icon: Icons.person_outline_rounded,
                                        keyboardType: TextInputType.name,
                                        validator: _validateName,
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // Email
                                    AppTextField(
                                      controller: _emailController,
                                      label: 'Correo electrónico',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateEmail,
                                    ),
                                    const SizedBox(height: 14),

                                    // Password
                                    AppTextField(
                                      controller: _passwordController,
                                      label: 'Contraseña',
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            ),
                                      ),
                                      obscureText: _obscurePassword,
                                      validator: _validatePassword,
                                    ),

                                    const SizedBox(height: 22),

                                    // CTA Button
                                    SizedBox(
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _authenticate,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child:
                                            _isLoading
                                                ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                )
                                                : Text(
                                                  _isLoginMode
                                                      ? 'Iniciar sesión'
                                                      : 'Crear cuenta',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Toggle mode ───────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isLoginMode
                                        ? '¿No tienes cuenta? '
                                        : '¿Ya tienes cuenta? ',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor:
                                        _isLoading
                                            ? SystemMouseCursors.basic
                                            : SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: _isLoading ? null : _toggleMode,
                                      child: Text(
                                        _isLoginMode
                                            ? 'Regístrate gratis'
                                            : 'Inicia sesión',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
