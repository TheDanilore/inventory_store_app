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

// --- ENUMS Y MODELOS ---
enum ItemType { coin, obstacle }

class FallingItem {
  final String id;
  double y; // Posición vertical (-1.2 arriba, 1.2 abajo)
  final int lane; // 0: Izquierda, 1: Centro, 2: Derecha
  final ItemType type;
  bool isCollected;

  FallingItem({
    required this.id,
    required this.y,
    required this.lane,
    required this.type,
    this.isCollected = false,
  });
}

class DodgeGameScreen extends StatefulWidget {
  final String profileId;

  const DodgeGameScreen({super.key, required this.profileId});

  @override
  State<DodgeGameScreen> createState() => _DodgeGameScreenState();
}

class _DodgeGameScreenState extends State<DodgeGameScreen> {
  // --- ESTADOS DEL JUEGO ---
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  int _score = 0;

  // --- VARIABLES FÍSICAS Y TABLERO ---
  Timer? _gameTimer;
  int _playerLane = 1; // Empieza en el carril del centro (1)
  double _gameSpeed = 0.011; // Velocidad de caída
  double _spawnTimer = 0.0; // Controla cuándo aparece una nueva fila
  int _patternIndex = 0;

  final List<FallingItem> _activeItems = [];
  final Random _random = Random();

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _playerLane = 1;
      _gameSpeed = 0.011;
      _activeItems.clear();
      _spawnTimer = 0.0;
      _patternIndex = 0;
    });

    // Game Loop a ~60 FPS (16 milisegundos)
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      _updatePhysics();
    });
  }

  void _updatePhysics() {
    setState(() {
      // 1. Mover los objetos hacia abajo
      for (var item in _activeItems) {
        item.y += _gameSpeed;
      }

      // 2. Comprobar colisiones
      _checkCollisions();

      // 3. Limpiar objetos que salieron de la pantalla (y > 1.2)
      _activeItems.removeWhere((item) => item.y > 1.2 || item.isCollected);

      // 4. Generar nuevos objetos
      _spawnTimer += _gameSpeed;
      if (_spawnTimer > 0.5) {
        // Distancia/Tiempo entre cada fila de objetos
        _spawnRow();
        _spawnTimer = 0.0;

        // Aumentamos la dificultad muy poco a poco (límite de velocidad: 0.032)
        if (_gameSpeed < 0.032) {
          _gameSpeed += 0.00012;
        }
      }
    });
  }

  void _spawnRow() {
    // Mantiene variedad sin volverlo injusto: alterna patrones simples de obstáculos
    final lanes = [0, 1, 2]..shuffle(_random);
    final pattern = _patternIndex % 4;
    _patternIndex++;

    final obstacleLanes = <int>[];
    final coinLanes = <int>[];

    if (pattern == 0) {
      obstacleLanes.add(lanes.removeLast());
      coinLanes.add(lanes.removeLast());
    } else if (pattern == 1) {
      obstacleLanes.addAll([lanes.removeLast(), lanes.removeLast()]);
      if (lanes.isNotEmpty) coinLanes.add(lanes.removeLast());
    } else if (pattern == 2) {
      obstacleLanes.add(lanes.removeLast());
      if (_random.nextDouble() > 0.35 && lanes.isNotEmpty) {
        coinLanes.add(lanes.removeLast());
      }
    } else {
      obstacleLanes.addAll([lanes.removeLast(), lanes.removeLast()]);
      // En este patrón la moneda aparece solo si queda un carril libre.
      if (lanes.isNotEmpty && _random.nextDouble() > 0.55) {
        coinLanes.add(lanes.removeLast());
      }
    }

    for (int i = 0; i < obstacleLanes.length; i++) {
      final lane = obstacleLanes[i];
      _activeItems.add(
        FallingItem(
          id: '${DateTime.now().microsecondsSinceEpoch}o$i',
          y: -1.2,
          lane: lane,
          type: ItemType.obstacle,
        ),
      );
    }

    for (int i = 0; i < coinLanes.length; i++) {
      final lane = coinLanes[i];
      _activeItems.add(
        FallingItem(
          id: '${DateTime.now().microsecondsSinceEpoch}c$i',
          y: -1.2,
          lane: lane,
          type: ItemType.coin,
        ),
      );
    }
  }

  void _moveLeft() {
    if (!_isPlaying || _isGameOver) return;
    if (_playerLane > 0) {
      setState(() => _playerLane--);
    }
  }

  void _moveRight() {
    if (!_isPlaying || _isGameOver) return;
    if (_playerLane < 2) {
      setState(() => _playerLane++);
    }
  }

  void _handleTapDown(TapDownDetails details, double width) {
    if (!_isPlaying || _isGameOver) return;

    final dx = details.localPosition.dx;
    if (dx < width / 3) {
      _moveLeft();
    } else if (dx > width * 2 / 3) {
      _moveRight();
    } else {
      final center = width / 2;
      if (dx < center - 20) {
        _moveLeft();
      } else if (dx > center + 20) {
        _moveRight();
      }
    }
  }

  void _checkCollisions() {
    // La posición "Y" del jugador en la pantalla (cerca de la parte inferior)
    const double playerY = 0.8;
    const double hitboxSize = 0.15; // Tamaño del área de colisión

    for (var item in _activeItems) {
      if (item.isCollected) continue;

      // Si están en el mismo carril y se cruzan en el eje Y
      if (item.lane == _playerLane && (item.y - playerY).abs() < hitboxSize) {
        if (item.type == ItemType.obstacle) {
          if (!kIsWeb) {
            Vibration.vibrate(duration: 200, amplitude: 255);
          }
          _gameOver();
          return; // Detiene el bucle inmediatamente
        } else if (item.type == ItemType.coin) {
          if (!kIsWeb) {
            Vibration.vibrate(duration: 30, amplitude: 64);
          }
          item.isCollected = true;
          _score++; // ¡Gana una moneda!
        }
      }
    }
  }

  // --- CONTROLES DE DESLIZAMIENTO (SWIPE) ---
  void _onSwipe(DragEndDetails details) {
    if (!_isPlaying || _isGameOver) return;

    // Detectamos la dirección del deslizamiento horizontal
    final velocity = details.primaryVelocity ?? 0;

    setState(() {
      if (velocity < -100 && _playerLane > 0) {
        // Deslizó hacia la izquierda
        _playerLane--;
      } else if (velocity > 100 && _playerLane < 2) {
        // Deslizó hacia la derecha
        _playerLane++;
      }
    });
  }

  Future<void> _gameOver() async {
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
          movementType: 'MINI_GAME_DODGE',
          description: 'Esquiva y Atrapa: Ganó $_score monedas',
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

  // Helper para convertir el carril (0,1,2) a coordenadas Alignment (-0.8, 0.0, 0.8)
  double _getAlignmentXForLane(int lane) {
    if (lane == 0) return -0.8;
    if (lane == 1) return 0.0;
    return 0.8;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapDown:
                  (details) => _handleTapDown(details, constraints.maxWidth),
              onHorizontalDragEnd: _onSwipe,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // --- FONDO (Los 3 carriles) ---
                  Row(
                    children: [
                      _buildLaneBackground(),
                      _buildLaneBackground(isCenter: true),
                      _buildLaneBackground(),
                    ],
                  ),

                  // --- MARCADOR ---
                  if (_isPlaying || _isGameOver)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
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

                  // --- LOS OBJETOS CAYENDO ---
                  if (_isPlaying)
                    ..._activeItems.map((item) {
                      return Align(
                        alignment: Alignment(
                          _getAlignmentXForLane(item.lane),
                          item.y,
                        ),
                        child:
                            item.type == ItemType.obstacle
                                ? _buildObstacleWidget()
                                : _buildCoinWidget(),
                      );
                    }),

                  // --- EL JUGADOR (Carrito de Compras) ---
                  if (_isPlaying || _isGameOver)
                    AnimatedAlign(
                      duration: const Duration(
                        milliseconds: 150,
                      ), // Movimiento suave entre carriles
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(
                        _getAlignmentXForLane(_playerLane),
                        0.8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              _isGameOver
                                  ? Colors.redAccent
                                  : AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isGameOver
                                      ? Colors.red
                                      : AppColors.primary)
                                  .withValues(alpha: 0.5),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),

                  // --- PANTALLAS DE OVERLAY ---
                  if (!_isPlaying && !_isGameOver)
                    _buildOverlay(
                      title: 'Esquiva y Atrapa',
                      subtitle:
                          'Desliza tu dedo a la izquierda o derecha para cambiar de carril.\nAtrapa las monedas y ¡cuidado con las cajas!',
                      buttonLabel: '¡A CORRER!',
                      onPressed: _startGame,
                      icon: Icons.swipe_rounded,
                      iconColor: Colors.blueAccent,
                    ),

                  if (_isGameOver)
                    _buildOverlay(
                      title: '¡Chocaste!',
                      subtitle:
                          'Lograste esquivar y recolectaste $_score monedas.\n¡Bien jugado!',
                      buttonLabel: 'RECLAMAR RECOMPENSA',
                      onPressed: () => Navigator.pop(context, _score),
                      icon: Icons.warning_rounded,
                      iconColor: Colors.redAccent,
                      isGameOver: true,
                    ),

                  if (_isPlaying)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Row(
                        children: [
                          Expanded(
                            child: AppPrimaryButton(
                              label: 'Izquierda',
                              onPressed: _moveLeft,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.35,
                              ),
                              foregroundColor: Colors.white,
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppPrimaryButton(
                              label: 'Derecha',
                              onPressed: _moveRight,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.35,
                              ),
                              foregroundColor: Colors.white,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES PARA DIBUJAR ---

  Widget _buildLaneBackground({bool isCenter = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color:
              isCenter
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObstacleWidget() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.brown.shade600,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.shade800, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.inventory_2, color: Colors.white54, size: 30),
    );
  }

  Widget _buildCoinWidget() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.yellowAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.6),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.attach_money_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildOverlay({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    required IconData icon,
    required Color iconColor,
    bool isGameOver = false,
  }) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade800,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (_isSaving)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                AppPrimaryButton(
                  label: buttonLabel,
                  backgroundColor: AppColors.primary,
                  onPressed: onPressed,
                ),
              if (!isGameOver && !_isSaving) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Volver atrás',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
