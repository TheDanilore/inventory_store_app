import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/config/presentation/providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para garantizar que el árbol de providers
    // ya está montado antes de llamar a context.read()
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (!mounted) return;

    // 1. OBLIGAMOS a que espere la configuración ANTES de entrar a la app
    final configProvider = context.read<AppConfigProvider>();
    try {
      await Future.wait([
        configProvider.loadConfig(),
        configProvider.loadBusinessInfo(),
      ]).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error o timeout cargando configuración inicial: $e');
    }

    if (!mounted) return;

    if (!mounted) return;

    // 2. AHORA SÍ, notificamos al AuthProvider para que maneje la sesión y GoRouter redirija
    final authProvider = context.read<AuthProvider>();
    
    final session = Supabase.instance.client.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();

    if (session == null || session.isExpired) {
      authProvider.initializeSession(null);
      return;
    }

    final cachedRole = prefs.getString('cached_user_role');
    if (cachedRole != null) {
      authProvider.initializeSession(cachedRole);
      _updateRoleInBackground(session.user.id, prefs);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('auth_user_id', session.user.id)
          .single()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      final role = data['role'] as String;
      await prefs.setString('cached_user_role', role);
      authProvider.initializeSession(role);
    } catch (e) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      authProvider.initializeSession(null);
    }
  }

  Future<void> _updateRoleInBackground(
    String userId,
    SharedPreferences prefs,
  ) async {
    try {
      final data =
          await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('auth_user_id', userId)
              .single();
      await prefs.setString('cached_user_role', data['role'] as String);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const Icon(
                        Icons.storefront_rounded,
                        size: 100,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper para fire-and-forget sin warning de unawaited future
void unawaited(Future<void> future) {}
