import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:vibration/vibration.dart';

class SuperSaltoScreen extends StatefulWidget {
  final String profileId;

  const SuperSaltoScreen({super.key, required this.profileId});

  @override
  State<SuperSaltoScreen> createState() => _SuperSaltoScreenState();
}

class _SuperSaltoScreenState extends State<SuperSaltoScreen> {
  // --- ESTADOS DEL JUEGO ---
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  bool _isJumping = false;
  int _score = 0; // Monedas atrapadas
  Timer? _gameTimer;

  // --- FÍSICAS Y POSICIONES ---
  double _charY = 1.0; // 1.0 es el suelo
  double _verticalVelocity = 0;

  double _obstacleX = 1.5;

  double _coinX = 2.0;
  double _coinY = 0.0;

  // --- PARALLAX NUBES ---
  double _cloud1X = -0.5;
  double _cloud2X = 0.5;
  double _cloud3X = 1.5;

  // --- EFECTO MONEDA (+1) ---
  bool _showPlusOne = false;
  double _plusOneX = 0.0;
  double _plusOneY = 0.0;
  int _plusOneTimer = 0;

  double _gameSpeed = 0.03;

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isSaving = false;
      _isJumping = false;
      _score = 0;
      _charY = 1.0;
      _verticalVelocity = 0;
      _obstacleX = 1.5;
      _coinX = 2.0;
      _gameSpeed = 0.03;
      _showPlusOne = false;
      _randomizeCoinY();
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) return;
      _updatePhysics();
    });
  }

  void _jump() {
    if (!_isPlaying || _isGameOver || _isJumping) return;
    if (_charY >= 0.999) {
      if (!kIsWeb) Vibration.vibrate(duration: 15, amplitude: 64);
      _isJumping = true;
      _verticalVelocity = 0.085;
    }
  }

  void _updatePhysics() {
    setState(() {
      // 1. FÍSICA DEL SALTO
      if (_isJumping) {
        _charY -= _verticalVelocity;
        _verticalVelocity -= 0.0035;
      }

      if (_charY > 1.0) {
        _charY = 1.0;
        _verticalVelocity = 0;
        _isJumping = false;
      } else if (_charY < -0.95) {
        _charY = -0.95;
        _verticalVelocity = 0;
      }

      // 2. MOVIMIENTO (PARALLAX Y OBJETOS)
      _obstacleX -= _gameSpeed;
      _coinX -= _gameSpeed;

      _cloud1X -= _gameSpeed * 0.2;
      _cloud2X -= _gameSpeed * 0.3;
      _cloud3X -= _gameSpeed * 0.15;

      // 3. RECICLAR NUBES
      if (_cloud1X < -1.5) _cloud1X = 1.5;
      if (_cloud2X < -1.5) _cloud2X = 1.5;
      if (_cloud3X < -1.5) _cloud3X = 1.5;

      // 4. RECICLAR OBSTÁCULO
      if (_obstacleX < -1.5) {
        _obstacleX = 1.5 + Random().nextDouble();
        if (_gameSpeed < 0.06) _gameSpeed += 0.001;
      }

      // 5. RECICLAR MONEDA
      if (_coinX < -1.5) {
        _coinX = 1.5 + Random().nextDouble() * 2;
        _randomizeCoinY();
      }

      // 6. ANIMACIÓN DEL +1
      if (_showPlusOne) {
        _plusOneY -= 0.02; // Sube lentamente
        _plusOneTimer++;
        if (_plusOneTimer > 25) {
          // Medio segundo aprox
          _showPlusOne = false;
        }
      }

      // 7. DETECCIÓN DE COLISIONES
      _checkCollisions();
    });
  }

  void _randomizeCoinY() {
    _coinY = -0.5 + (Random().nextDouble() * 1.5);
  }

  void _checkCollisions() {
    const double charX = -0.5;

    // CHOQUE CON LA CAJA (GAME OVER)
    if (_obstacleX < (charX + 0.15) && _obstacleX > (charX - 0.15)) {
      if (_charY > 0.8) {
        if (!kIsWeb) Vibration.vibrate(duration: 200, amplitude: 255);
        _gameOver();
      }
    }

    // RECOGER MONEDA
    if (_coinX < (charX + 0.15) && _coinX > (charX - 0.15)) {
      if ((_charY - _coinY).abs() < 0.2) {
        if (!kIsWeb) Vibration.vibrate(duration: 30, amplitude: 128);
        _score++;

        // Trigger +1 particle
        _showPlusOne = true;
        _plusOneX = charX;
        _plusOneY = _charY;
        _plusOneTimer = 0;

        _coinX = 2.0;
        _randomizeCoinY();
      }
    }
  }

  void _gameOver() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
  }

  Future<void> _claimRewardAndExit() async {
    setState(() => _isSaving = true);
    if (_score > 0) {
      if (widget.profileId == 'offline') {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Modo sin conexión. Juegas por diversión.',
            type: SnackbarType.info,
          );
          Navigator.pop(context, _score);
        }
        return;
      }
      try {
        await context.read<PointsCubit>().recordMiniGameResult(
          'MINI_GAME_JUMP',
          _score,
          'Super Salto: Ganó $_score monedas',
        );
        if (mounted) Navigator.pop(context, _score);
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu recompensa. Intenta de nuevo.',
            type: SnackbarType.error,
          );
          setState(() => _isSaving = false);
        }
      }
    } else {
      if (mounted) Navigator.pop(context, 0);
    }
  }

  Future<void> _claimAndRestart() async {
    setState(() => _isSaving = true);
    if (_score > 0) {
      if (widget.profileId == 'offline') {
        _startGame();
        return;
      }
      try {
        await context.read<PointsCubit>().recordMiniGameResult(
          'MINI_GAME_JUMP',
          _score,
          'Super Salto: Ganó $_score monedas',
        );
        if (mounted) _startGame();
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu recompensa.',
            type: SnackbarType.error,
          );
          setState(() => _isSaving = false);
        }
      }
    } else {
      _startGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue.shade300,
              Colors.lightBlue.shade100,
              Colors.white,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTapDown: (_) => _jump(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // --- PARALLAX NUBES ---
                Align(
                  alignment: Alignment(_cloud1X, -0.8),
                  child: const Text('☁️', style: TextStyle(fontSize: 80)),
                ),
                Align(
                  alignment: Alignment(_cloud2X, -0.6),
                  child: const Text('⛅', style: TextStyle(fontSize: 60)),
                ),
                Align(
                  alignment: Alignment(_cloud3X, -0.4),
                  child: const Text('☁️', style: TextStyle(fontSize: 50)),
                ),

                // --- EL SUELO ---
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.15,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.green.shade400, Colors.green.shade700],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: const [
                        // Pasto decorativo estático
                        Positioned(
                          top: -10,
                          left: 20,
                          child: Text('🌱', style: TextStyle(fontSize: 24)),
                        ),
                        Positioned(
                          top: -5,
                          left: 100,
                          child: Text('🌿', style: TextStyle(fontSize: 20)),
                        ),
                        Positioned(
                          top: -12,
                          right: 50,
                          child: Text('🌱', style: TextStyle(fontSize: 28)),
                        ),
                        Positioned(
                          top: 5,
                          right: 150,
                          child: Text('🍄', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- 1. ESTADO: JUGANDO ---
                if (_isPlaying || _isGameOver) ...[
                  // LA MONEDA
                  Container(
                    alignment: Alignment(_coinX, _coinY),
                    child: const Text('🪙', style: TextStyle(fontSize: 40)),
                  ),

                  // EFECTO +1
                  if (_showPlusOne)
                    Container(
                      alignment: Alignment(_plusOneX, _plusOneY),
                      child: AnimatedOpacity(
                        opacity: _plusOneTimer > 15 ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Text(
                          '+1',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // EL OBSTÁCULO (Caja)
                  Container(
                    alignment: Alignment(_obstacleX, 1.0),
                    child: const Text('📦', style: TextStyle(fontSize: 50)),
                  ),

                  // EL PERSONAJE
                  Container(
                    alignment: Alignment(-0.5, _charY),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Text('🛒', style: TextStyle(fontSize: 46)),
                    ),
                  ),

                  // MARCADOR DE PUNTAJE (Glassmorphism)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                '$_score',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // --- 2. ESTADO: PANTALLA DE INICIO ---
                if (!_isPlaying && !_isGameOver) _buildIntroScreen(),

                // --- 3. ESTADO: GAME OVER ---
                if (_isGameOver) _buildGameOverScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🛒', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                const Text(
                  'Super Salto',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Toca la pantalla para saltar.\nAtrapa monedas 🪙 y esquiva cajas 📦.\n¡Cuidado, la velocidad aumenta!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                AppPrimaryButton(label: 'JUGAR AHORA', onPressed: _startGame),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'Volver',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💥', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                const Text(
                  '¡Auch! Chocaste',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                if (_score > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          '+$_score obtenidas',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'No atrapaste ninguna moneda 😢',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 32),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  Builder(
                    builder: (context) {
                      final limit =
                          context
                              .read<AppConfigCubit>()
                              .getDouble('jump_daily_limit', 1)
                              .round();
                      final played =
                          context
                              .read<PointsCubit>()
                              .state
                              .superSaltoPlaysToday;
                      final canPlayAgain =
                          widget.profileId == 'offline' ||
                          (limit - (played + 1) > 0);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_score > 0) ...[
                            if (canPlayAgain) ...[
                              AppPrimaryButton(
                                label: 'Reclamar y Jugar de Nuevo',
                                onPressed: _claimAndRestart,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _claimRewardAndExit,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reclamar y Salir',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              AppPrimaryButton(
                                label: 'Reclamar y Salir',
                                onPressed: _claimRewardAndExit,
                              ),
                            ],
                          ] else ...[
                            if (canPlayAgain) ...[
                              AppPrimaryButton(
                                label: 'Volver a Intentar',
                                onPressed: _startGame,
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, 0),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.textSecondary,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Salir',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
