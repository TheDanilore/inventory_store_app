import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/config/presentation/providers/app_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:vibration/vibration.dart';

// Clase auxiliar para definir los premios en el fondo de la máquina
class ClawPrize {
  final double x;
  final int points;
  final Color color;
  final IconData icon;
  bool isCaught;

  ClawPrize({
    required this.x,
    required this.points,
    required this.color,
    required this.icon,
    this.isCaught = false,
  });
}

class ClawMachineScreen extends StatefulWidget {
  final String profileId;

  const ClawMachineScreen({super.key, required this.profileId});

  @override
  State<ClawMachineScreen> createState() => _ClawMachineScreenState();
}

class _ClawMachineScreenState extends State<ClawMachineScreen> {
  // --- ESTADOS DE LA GARRA ---
  double _clawX = 0.0;
  double _clawY = -0.8; // Posición de reposo (Arriba)
  int _direction = 1; // 1 = Derecha, -1 = Izquierda
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  bool _isDropping = false; // Bloquea el botón cuando la garra está bajando

  Timer? _horizontalTimer;

  // --- PREMIOS ---
  List<ClawPrize> _prizes = [];
  ClawPrize? _caughtPrize;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializePrizes();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _horizontalTimer?.cancel();
    super.dispose();
  }

  void _initializePrizes() {
    final config = context.read<AppConfigProvider>();
    final p1 = config.getDouble('claw_prize_1', 5).toInt();
    final p2 = config.getDouble('claw_prize_2', 20).toInt();
    final p3 = config.getDouble('claw_prize_3', 50).toInt();
    final p4 = config.getDouble('claw_prize_4', 10).toInt();
    final p5 = config.getDouble('claw_prize_5', 5).toInt();

    // Generamos cápsulas con premios en la base de la máquina
    _prizes = [
      ClawPrize(
        x: -0.8,
        points: p1,
        color: Colors.blueAccent,
        icon: Icons.vpn_key_rounded,
      ),
      ClawPrize(
        x: -0.4,
        points: p2,
        color: Colors.amber,
        icon: Icons.stars_rounded,
      ),
      ClawPrize(
        x: 0.0,
        points: p3,
        color: Colors.redAccent,
        icon: Icons.redeem_rounded,
      ),
      ClawPrize(
        x: 0.4,
        points: p4,
        color: Colors.purpleAccent,
        icon: Icons.shopping_bag_rounded,
      ),
      ClawPrize(
        x: 0.8,
        points: p5,
        color: Colors.greenAccent,
        icon: Icons.vpn_key_rounded,
      ),
    ];
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isDropping = false;
      _clawY = -0.8;
      _clawX = 0.0;
      _caughtPrize = null;
      for (var p in _prizes) {
        p.isCaught = false;
      }
    });

    // Movimiento continuo de izquierda a derecha (Velocidad: cada 30ms)
    _horizontalTimer = Timer.periodic(const Duration(milliseconds: 30), (
      timer,
    ) {
      if (!mounted) return;
      setState(() {
        _clawX += 0.03 * _direction;
        if (_clawX > 0.9) {
          _direction = -1; // Rebota a la izquierda
        } else if (_clawX < -0.9) {
          _direction = 1; // Rebota a la derecha
        }
      });
    });
  }

  Future<void> _dropClaw() async {
    if (_isDropping) return;

    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }

    // 1. Detenemos el movimiento horizontal
    _horizontalTimer?.cancel();
    setState(() {
      _isDropping = true;
      _clawY = 0.65; // La garra baja hasta la zona de los premios
    });

    // 2. Esperamos a que termine la animación de bajada
    await Future.delayed(const Duration(milliseconds: 800));

    // 3. Verificamos colisión (El Hitbox)
    // Buscamos si la garra está a una distancia menor de 0.2 en el eje X de algún premio
    for (var prize in _prizes) {
      if ((prize.x - _clawX).abs() < 0.2) {
        setState(() {
          prize.isCaught = true;
          _caughtPrize = prize;
        });
        break; // Solo atrapa un premio
      }
    }

    // 4. La garra vuelve a subir
    setState(() {
      _clawY = -0.8;
    });

    // 5. Esperamos a que la garra llegue arriba
    await Future.delayed(const Duration(milliseconds: 800));

    // 6. Termina el juego
    _endGame();
  }

  Future<void> _endGame() async {
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
    });

    final int pointsEarned = _caughtPrize?.points ?? 0;

    if (pointsEarned > 0) {
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
          points: pointsEarned,
          movementType: 'MINI_GAME_CLAW',
          description: 'Máquina de Garra: Ganó $pointsEarned monedas',
        );
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu premio. Intenta de nuevo.',
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Máquina de Garra',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Espaciador
                ],
              ),
            ),

            // Contenedor principal de la Máquina
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                    bottom: Radius.circular(20),
                  ),
                  border: Border.all(color: AppColors.primary, width: 8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Fondo interior de la máquina (Cristal)
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.shade50.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                          bottom: Radius.circular(8),
                        ),
                      ),
                    ),

                    // Riel superior de la garra
                    Align(
                      alignment: const Alignment(0, -0.9),
                      child: Container(
                        height: 10,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        color: Colors.grey.shade800,
                      ),
                    ),

                    // PREMIOS EN EL FONDO
                    ..._prizes.map((prize) {
                      // Si el premio fue atrapado, su posición X e Y es la misma que la garra
                      final pX = prize.isCaught ? _clawX : prize.x;
                      final pY = prize.isCaught ? _clawY + 0.15 : 0.8;

                      return AnimatedAlign(
                        duration:
                            prize.isCaught
                                ? const Duration(milliseconds: 800)
                                : Duration.zero,
                        curve: Curves.easeInOut,
                        alignment: Alignment(pX, pY),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: prize.color.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            prize.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    }),

                    // LA GARRA
                    AnimatedAlign(
                      duration:
                          _isDropping
                              ? const Duration(milliseconds: 800)
                              : Duration.zero,
                      curve: Curves.easeInOut,
                      alignment: Alignment(_clawX, _clawY),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cable
                          Container(
                            width: 4,
                            height: 60,
                            color: Colors.grey.shade700,
                          ),
                          // Cabeza de la garra
                          Icon(
                            _isDropping
                                ? Icons.precision_manufacturing_rounded
                                : Icons.hardware_rounded,
                            size: 60,
                            color: Colors.grey.shade800,
                          ),
                        ],
                      ),
                    ),

                    // --- PANTALLAS SUPERPUESTAS ---
                    if (!_isPlaying && !_isGameOver)
                      _buildOverlay(
                        title: 'Atrápalo si puedes',
                        subtitle: 'Espera el momento exacto y baja la garra.',
                        buttonText: 'INSERTAR FICHA',
                        onPressed: _startGame,
                      ),

                    if (_isGameOver)
                      _buildOverlay(
                        title:
                            _caughtPrize != null ? '¡Ganaste!' : '¡Fallaste!',
                        subtitle:
                            _caughtPrize != null
                                ? 'Atrapaste el premio de ${_caughtPrize!.points} monedas.'
                                : 'La garra regresó vacía.',
                        buttonText: 'RECLAMAR',
                        isGameOverScreen: true,
                        onPressed:
                            () => Navigator.pop(
                              context,
                              _caughtPrize?.points ?? 0,
                            ),
                      ),
                  ],
                ),
              ),
            ),

            // Panel de Control (Botón Gigante)
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isDropping || !_isPlaying
                          ? Colors.grey
                          : Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: _isDropping || !_isPlaying ? 0 : 8,
                ),
                onPressed: (_isPlaying && !_isDropping) ? _dropClaw : null,
                child: const Text(
                  'BAJAR GARRA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vista de las ventanas semitransparentes (Inicio y Fin)
  Widget _buildOverlay({
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    bool isGameOverScreen = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color:
                    isGameOverScreen && _caughtPrize == null
                        ? Colors.redAccent
                        : Colors.amber,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_isSaving)
              const CircularProgressIndicator(color: Colors.amber)
            else
              AppPrimaryButton(
                label: buttonText,
                backgroundColor: AppColors.primary,
                onPressed: onPressed,
              ),
          ],
        ),
      ),
    );
  }
}
