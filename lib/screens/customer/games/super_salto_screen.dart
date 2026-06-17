import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
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
  // Flutter Alignment va de -1.0 (arriba/izquierda) a 1.0 (abajo/derecha)
  double _charY = 1.0; // 1.0 es el suelo
  double _verticalVelocity = 0;

  // Posición del obstáculo (caja)
  double _obstacleX = 1.5; // Empieza fuera de la pantalla por la derecha

  // Posición de la moneda
  double _coinX = 2.0;
  double _coinY = 0.0; // Altura aleatoria para la moneda

  // --- VARIABLES DE VELOCIDAD Y DIFICULTAD ---
  double _gameSpeed = 0.03; // Velocidad inicial de los obstáculos

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
      _randomizeCoinY();
    });

    // El Game Loop: Se ejecuta ~50 veces por segundo (cada 20 milisegundos)
    _gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) return;
      _updatePhysics();
    });
  }

  void _jump() {
    // Solo puede saltar si está en el suelo (evita doble salto en el aire)
    if (!_isPlaying || _isGameOver || _isJumping) return;
    if (_charY >= 0.999) {
      _isJumping = true;
      _verticalVelocity = 0.085;
    }
  }

  void _updatePhysics() {
    setState(() {
      // 1. FÍSICA DEL SALTO (velocidad inicial + gravedad)
      if (_isJumping) {
        _charY -= _verticalVelocity;
        _verticalVelocity -= 0.0035;
      }

      // Evitamos que caiga más abajo del suelo
      if (_charY > 1.0) {
        _charY = 1.0;
        _verticalVelocity = 0;
        _isJumping = false;
      } else if (_charY < -0.95) {
        _charY = -0.95;
        _verticalVelocity = 0;
      }

      // 2. MOVIMIENTO DEL OBSTÁCULO Y LA MONEDA
      _obstacleX -= _gameSpeed;
      _coinX -= _gameSpeed;

      // 3. RECICLAR OBSTÁCULO (Si sale por la izquierda, vuelve a la derecha)
      if (_obstacleX < -1.5) {
        _obstacleX =
            1.5 +
            Random().nextDouble(); // Añade un poco de aleatoriedad al spawn
        // Incrementamos la dificultad lentamente
        if (_gameSpeed < 0.06) _gameSpeed += 0.001;
      }

      // 4. RECICLAR MONEDA
      if (_coinX < -1.5) {
        _coinX = 1.5 + Random().nextDouble() * 2;
        _randomizeCoinY();
      }

      // 5. DETECCIÓN DE COLISIONES (Hitboxes)
      _checkCollisions();
    });
  }

  void _randomizeCoinY() {
    // La moneda puede aparecer entre el suelo (1.0) y lo más alto de un salto (-0.5)
    _coinY = -0.5 + (Random().nextDouble() * 1.5);
  }

  void _checkCollisions() {
    // Hitbox del personaje está aprox en X = -0.5
    const double charX = -0.5;

    // --- CHOQUE CON LA CAJA (GAME OVER) ---
    // Si la caja está en el rango X del personaje Y el personaje está cerca del suelo
    if (_obstacleX < (charX + 0.15) && _obstacleX > (charX - 0.15)) {
      if (_charY > 0.8) {
        // 0.8 hacia 1.0 significa que está tocando la caja
        if (!kIsWeb) {
          Vibration.vibrate(duration: 200, amplitude: 255);
        }
        _endGame();
      }
    }

    // --- RECOGER MONEDA ---
    // Si la moneda está en el rango X del personaje Y en el rango Y del personaje
    if (_coinX < (charX + 0.15) && _coinX > (charX - 0.15)) {
      if ((_charY - _coinY).abs() < 0.2) {
        // Atrapó la moneda
        if (!kIsWeb) {
          Vibration.vibrate(duration: 30, amplitude: 64);
        }
        _score++;
        _coinX = 2.0; // Desaparece la moneda y la manda lejos para reciclar
        _randomizeCoinY();
      }
    }
  }

  Future<void> _endGame() async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
    });

    if (_score > 0) {
      try {
        await context.read<WalletProvider>().processGameReward(
          points: _score,
          movementType: 'MINI_GAME_JUMP',
          description: 'Super Salto: Ganó $_score monedas',
        );
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu recompensa. Intenta de nuevo.',
            type: SnackbarType.error,
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade100, // Color cielo
      body: SafeArea(
        child: GestureDetector(
          onTapDown:
              (_) =>
                  _jump(), // Detecta el toque en cualquier parte de la pantalla
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // --- FONDO (NUBES Y PAISAJE) ---
              const Align(
                alignment: Alignment(0, -0.8),
                child: Icon(Icons.cloud, color: Colors.white, size: 80),
              ),
              const Align(
                alignment: Alignment(0.8, -0.6),
                child: Icon(Icons.cloud, color: Colors.white, size: 60),
              ),

              // --- EL SUELO ---
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.15,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    border: Border(
                      top: BorderSide(color: Colors.lightGreenAccent, width: 4),
                    ),
                  ),
                ),
              ),

              // --- 1. ESTADO: JUGANDO ---
              if (_isPlaying || _isGameOver) ...[
                // MARCADOR DE PUNTAJE
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // LA MONEDA
                Container(
                  alignment: Alignment(_coinX, _coinY),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),

                // EL OBSTÁCULO (Caja)
                Container(
                  alignment: Alignment(_obstacleX, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.brown.shade400,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.brown.shade800,
                        width: 2,
                      ),
                    ),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.layers,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),

                // EL PERSONAJE (Carrito de compras)
                Container(
                  alignment: Alignment(-0.5, _charY),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 30,
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
    );
  }

  // ==========================================
  // VISTAS AUXILIARES
  // ==========================================

  Widget _buildIntroScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart, size: 80, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Super Salto',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toca la pantalla para saltar.\nAtrapa las monedas y esquiva las cajas.\n¡Cuidado, la velocidad aumenta!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            AppPrimaryButton(label: 'JUGAR AHORA', onPressed: _startGame),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_very_dissatisfied,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Auch! Chocaste',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lograste atrapar\n$_score monedas',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 32),
            if (_isSaving)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              AppPrimaryButton(
                label: 'Reclamar Monedas',
                onPressed: () => Navigator.pop(context, _score),
              ),
          ],
        ),
      ),
    );
  }
}
