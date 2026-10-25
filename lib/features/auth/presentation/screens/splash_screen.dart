import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF22223B), // Navy sutilmente iluminado
              Color(0xFF131322), // Deep Navy
              Color(0xFF090A10), // Midnight Slate oscuro
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: LayoutBuilder(
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
                        buildWhen:
                            (prev, curr) =>
                                prev.authStatus != curr.authStatus ||
                                prev.errorMessage != curr.errorMessage,
                        builder: (context, state) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Contenedor del Logo con Aura luminosa y Shimmer
                              Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.18),
                                          blurRadius: 36,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: Image.asset(
                                        'assets/logo_circle.png',
                                        width: 124,
                                        height: 124,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.storefront_rounded,
                                                  size: 100,
                                                  color: Colors.white,
                                                ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: 650.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .scale(
                                    begin: const Offset(0.85, 0.85),
                                    end: const Offset(1.0, 1.0),
                                    duration: 750.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .then()
                                  .shimmer(
                                    duration: 1600.ms,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                              const SizedBox(height: 22),
                              const Text(
                                    'Todo tu negocio en un solo lugar.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                      letterSpacing: 0.4,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 250.ms, duration: 500.ms)
                                  .slideY(
                                    begin: 0.25,
                                    end: 0,
                                    curve: Curves.easeOut,
                                  ),
                              const SizedBox(height: 28),
                              if (state.authStatus == AuthStatus.error) ...[
                                Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 340,
                                      ),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.25,
                                            ),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.cloud_off_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                          const SizedBox(height: 10),
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
                                              foregroundColor:
                                                  AppColors.primary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed:
                                                () =>
                                                    _checkSession(force: true),
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            label: const Text(
                                              'Reintentar conexión',
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 400.ms)
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                    ),
                              ] else ...[
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    strokeWidth: 2.8,
                                  ),
                                ).animate().fadeIn(
                                  delay: 400.ms,
                                  duration: 400.ms,
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
      ),
    );
  }
}
