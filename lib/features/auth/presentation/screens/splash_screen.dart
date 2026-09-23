import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';

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

  Future<void> _checkSession({bool force = false}) async {
    if (!mounted) return;
    LoggerService.d(
      'SplashScreen: ciclo _checkSession iniciado (force: $force)',
      tag: 'SplashScreen',
    );

    if (widget.onInitialize != null) {
      try {
        LoggerService.d(
          'SplashScreen: ejecutando onInitialize...',
          tag: 'SplashScreen',
        );
        await widget.onInitialize!(context);
        LoggerService.d(
          'SplashScreen: onInitialize finalizado con éxito',
          tag: 'SplashScreen',
        );
      } catch (e, st) {
        LoggerService.e(
          'Error o timeout cargando inicialización',
          tag: 'SplashScreen',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (!mounted) return;

    final authCubit = context.read<AuthCubit>();
    LoggerService.d(
      'SplashScreen: estado de AuthCubit -> ${authCubit.state.authStatus}',
      tag: 'SplashScreen',
    );
    if (force || authCubit.state.authStatus == AuthStatus.initial) {
      await authCubit.checkSession(force: force);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Previene asserts durante el micro-tick inicial del motor web/canvas (e.g., constraints <= 50px)
          if (constraints.maxHeight < 50 || constraints.maxWidth < 50) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: BlocBuilder<AuthCubit, AuthState>(
                      buildWhen: (prev, curr) =>
                          prev.authStatus != curr.authStatus ||
                          prev.errorMessage != curr.errorMessage,
                      builder: (context, state) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
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
                                  cacheWidth: 260,
                                  cacheHeight: 260,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                            Icons.storefront_rounded,
                                            size: 100,
                                            color: Colors.white,
                                          ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            if (state.authStatus == AuthStatus.error) ...[
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 340,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_off_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      state.errorMessage ??
                                          'Error de conexión con el servidor',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed:
                                          () => _checkSession(force: true),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Reintentar conexión'),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

