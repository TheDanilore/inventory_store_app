import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/providers/app_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:vibration/vibration.dart';

enum ItemType { coin, gift, bomb }

class FallingItem {
  double x;
  double y;
  ItemType type;
  double speed;

  FallingItem({
    required this.x,
    required this.y,
    required this.type,
    required this.speed,
  });
}

class CoinCatcherGameScreen extends StatefulWidget {
  final String profileId;

  const CoinCatcherGameScreen({super.key, required this.profileId});

  @override
  State<CoinCatcherGameScreen> createState() => _CoinCatcherGameScreenState();
}

class _CoinCatcherGameScreenState extends State<CoinCatcherGameScreen> {
  static const String _coinRewardKey = 'catcher_coin_reward';
  static const String _giftRewardKey = 'catcher_gift_reward';
  static const String _bombPenaltyKey = 'catcher_bomb_penalty';
  static const double _defaultCoinReward = 1;
  static const double _defaultGiftReward = 5;
  static const double _defaultBombPenalty = -3;

  // --- ESTADOS DEL JUEGO ---
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  int _score = 0;
  int _timeLeft = 15;

  // --- VARIABLES FÍSICAS ---
  double _basketX = 0;
  final double _basketWidth = 80;
  final double _basketHeight = 80;
  final double _itemSize = 40;

  final List<FallingItem> _items = [];

  // --- TIMERS ---
  Timer? _gameLoopTimer;
  Timer? _spawnTimer;
  Timer? _clockTimer;

  final _random = Random();
  late AppConfigProvider _config;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _config = context.read<AppConfigProvider>();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _gameLoopTimer?.cancel();
    _spawnTimer?.cancel();
    _clockTimer?.cancel();
  }

  void _updateBasketFromTouch(double touchX, double screenWidth) {
    if (!_isPlaying) return;

    setState(() {
      _basketX = touchX - (_basketWidth / 2);
      if (_basketX < 0) _basketX = 0;
      if (_basketX > screenWidth - _basketWidth) {
        _basketX = screenWidth - _basketWidth;
      }
    });
  }

  void _startGame(double screenWidth) {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _timeLeft = 15;
      _items.clear();
      _basketX = (screenWidth / 2) - (_basketWidth / 2);
    });

    // 1. Reloj del juego (cuenta regresiva)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _endGame();
        }
      });
    });

    // 2. Generador de objetos (Caen cada 400ms)
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      _spawnItem(screenWidth);
    });

    // 3. Game Loop (Aprox 60 FPS)
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updatePhysics();
    });
  }

  void _spawnItem(double screenWidth) {
    // Probabilidades: 70% moneda, 15% regalo, 15% bomba
    final rand = _random.nextInt(100);
    ItemType type;
    if (rand < 70) {
      type = ItemType.coin;
    } else if (rand < 85) {
      type = ItemType.gift;
    } else {
      type = ItemType.bomb;
    }

    final startX = _random.nextDouble() * (screenWidth - _itemSize);
    final speed = 4.0 + _random.nextDouble() * 4.0; // Velocidad aleatoria

    _items.add(FallingItem(x: startX, y: -_itemSize, type: type, speed: speed));
  }

  void _updatePhysics() {
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final collisionY =
        screenHeight - _basketHeight - 40; // 40 es el padding inferior

    setState(() {
      for (int i = _items.length - 1; i >= 0; i--) {
        final item = _items[i];
        item.y += item.speed;

        // Detectar colisión con la canasta
        if (item.y + _itemSize >= collisionY &&
            item.y <= collisionY + _basketHeight) {
          if (item.x + _itemSize > _basketX &&
              item.x < _basketX + _basketWidth) {
            // ¡Atrapado!
            if (!kIsWeb) {
              Vibration.vibrate(duration: 30, amplitude: 64);
            }
            _handleCatch(item.type);
            _items.removeAt(i);
            continue;
          }
        }

        // Eliminar si sale de la pantalla
        if (item.y > screenHeight) {
          _items.removeAt(i);
        }
      }
    });
  }

  void _handleCatch(ItemType type) {
    final coinReward =
        _config.getDouble(_coinRewardKey, _defaultCoinReward).round();
    final giftReward =
        _config.getDouble(_giftRewardKey, _defaultGiftReward).round();
    final bombPenalty =
        _config.getDouble(_bombPenaltyKey, _defaultBombPenalty).round();

    switch (type) {
      case ItemType.coin:
        _score += coinReward;
        break;
      case ItemType.gift:
        _score += giftReward;
        break;
      case ItemType.bomb:
        _score += bombPenalty;
        if (_score < 0) _score = 0;
        break;
    }
  }

  Future<void> _endGame() async {
    _cancelTimers();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
    });

    if (_score > 0) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 200, amplitude: 255);
      }
      if (widget.profileId == 'offline') {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Modo sin conexión. Juegas por diversión.',
            type: SnackbarType.info,
          );
          setState(() => _isSaving = false);
        }
        return;
      }
      try {
        await context.read<WalletProvider>().processGameReward(
          points: _score,
          movementType: 'MINI_GAME_CATCHER',
          description: 'Lluvia de Monedas: Ganó $_score monedas',
        );
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al guardar tus puntos.',
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown:
                  (event) => _updateBasketFromTouch(
                    event.localPosition.dx,
                    constraints.maxWidth,
                  ),
              onPointerMove:
                  (event) => _updateBasketFromTouch(
                    event.localPosition.dx,
                    constraints.maxWidth,
                  ),
              child: Stack(
                children: [
                  // --- ÁREA DE JUEGO ---
                  if (_isPlaying || _isGameOver) ...[
                    // Elementos cayendo
                    ..._items.map((item) {
                      return Positioned(
                        left: item.x,
                        top: item.y,
                        child: _buildItem(item.type),
                      );
                    }),

                    // Canasta del jugador
                    Positioned(
                      bottom: 40,
                      left: _basketX,
                      child: Container(
                        width: _basketWidth,
                        height: _basketHeight,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(40),
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Icon(
                              Icons.shopping_basket_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // HUD (Puntuación y Tiempo)
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHudCard(
                            Icons.stars_rounded,
                            '$_score',
                            Colors.amber,
                          ),
                          _buildHudCard(
                            Icons.timer_rounded,
                            '00:$_timeLeft',
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // --- PANTALLA DE INICIO ---
                  if (!_isPlaying && !_isGameOver)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.catching_pokemon_rounded,
                              size: 80,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Lluvia de Monedas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Arrastra la canasta y atrapa tantas monedas y regalos como puedas en 15 segundos.\n¡Cuidado con las bombas!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 40),
                            AppPrimaryButton(
                              label: 'Comenzar Juego',
                              backgroundColor: Colors.amber,
                              foregroundColor: AppColors.primaryDark,
                              onPressed: () => _startGame(size.width),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Volver',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // --- PANTALLA DE FIN DE JUEGO ---
                  if (_isGameOver)
                    Container(
                      color: AppColors.primaryDark.withValues(alpha: 0.9),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '¡Tiempo agotado!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Atrapaste',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '$_score monedas',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 40),
                              if (_isSaving)
                                const CircularProgressIndicator(
                                  color: Colors.amber,
                                )
                              else
                                AppPrimaryButton(
                                  label: 'Reclamar y salir',
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                  onPressed:
                                      () => Navigator.pop(context, _score),
                                ),
                            ],
                          ),
                        ),
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

  Widget _buildItem(ItemType type) {
    IconData icon;
    Color color;

    switch (type) {
      case ItemType.coin:
        icon = Icons.monetization_on_rounded;
        color = Colors.amber;
        break;
      case ItemType.gift:
        icon = Icons.card_giftcard_rounded;
        color = Colors.purpleAccent;
        break;
      case ItemType.bomb:
        icon = Icons.coronavirus_rounded;
        color = Colors.redAccent;
        break;
    }

    return Container(
      width: _itemSize,
      height: _itemSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildHudCard(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
