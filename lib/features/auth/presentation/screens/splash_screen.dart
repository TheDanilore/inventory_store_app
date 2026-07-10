import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> Function(BuildContext context)? onInitialize;

  const SplashScreen({super.key, this.onInitialize});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (!mounted) return;

    if (widget.onInitialize != null) {
      try {
        await widget.onInitialize!(context);
      } catch (e) {
        debugPrint('Error o timeout cargando inicialización: $e');
      }
    }

    if (!mounted) return;

    // Llamamos al Cubit para que verifique la sesin. 
    // GoRouter reaccionarǭ automǭticamente al cambio de estado gracias a GoRouterRefreshStream
    await context.read<AuthCubit>().checkSession();
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
