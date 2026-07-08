import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:vibration/vibration.dart';

class PinataGameScreen extends StatefulWidget {
  final String profileId;

  const PinataGameScreen({super.key, required this.profileId});

  @override
  State<PinataGameScreen> createState() => _PinataGameScreenState();
}

class _PinataGameScreenState extends State<PinataGameScreen>
    with SingleTickerProviderStateMixin {
  // --- ESTADOS DEL JUEGO ---
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;

  int _timeLeft = 10;
  int _tapCount = 0;
  int _pointsEarned = 0;

  Timer? _timer;

  // --- ANIMACIÓN DE VIBRACIÓN ---
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    // Configuramos un controlador súper rápido para el temblor
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    // Animación de rotación oscilante (de izquierda a derecha)
    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _timeLeft = 10;
      _tapCount = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _endGame();
        }
      });
    });
  }

  void _onPinataTap() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      _tapCount++;
    });

    if (!kIsWeb) {
      Vibration.vibrate(duration: 30, amplitude: 64);
    }

    // Disparar la animación de temblor
    _shakeController.forward(from: 0.0).then((_) {
      _shakeController.reverse();
    });
  }

  Future<void> _endGame() async {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
    });

    // Leer valores dinámicos desde AppConfigCubit
    final config = context.read<AppConfigCubit>();
    final grandPrize = config.getDouble('pinata_grand_prize', 50).toInt();
    final consolationPrize =
        config.getDouble('pinata_consolation_prize', 5).toInt();

    // Lógica de premios: Si llega a 50 toques, gana el premio mayor.
    _pointsEarned = _tapCount >= 50 ? grandPrize : consolationPrize;

    if (_pointsEarned > 0) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 300, amplitude: 255);
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
          points: _pointsEarned,
          movementType: 'MINI_GAME_PINATA',
          description:
              'Rompe la Piñata: $_tapCount toques. Ganó $_pointsEarned monedas',
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

  // Cambiamos el color de la piñata conforme recibe más golpes (se va poniendo "caliente")
  Color _getPinataColor() {
    if (_tapCount >= 50) return Colors.redAccent;
    if (_tapCount >= 40) return Colors.deepOrangeAccent;
    if (_tapCount >= 30) return Colors.orange;
    if (_tapCount >= 20) return Colors.amber;
    if (_tapCount >= 10) return Colors.yellow;
    return Colors.greenAccent;
  }

  // La piñata crece ligeramente a medida que recibe daño
  double _getPinataScale() {
    final scale = 1.0 + (_tapCount * 0.005);
    return scale > 1.3 ? 1.3 : scale; // Límite de crecimiento al 30%
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Stack(
          children: [
            // --- ESTADO 1: INICIO ---
            if (!_isPlaying && !_isGameOver) _buildIntroScreen(),

            // --- ESTADO 2: JUGANDO ---
            if (_isPlaying) _buildPlayingScreen(),

            // --- ESTADO 3: FIN DEL JUEGO ---
            if (_isGameOver) _buildGameOverScreen(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VISTAS DEL JUEGO
  // ==========================================

  Widget _buildIntroScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 100,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            const Text(
              'Frenesí de Piñata',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '¡Tienes 10 segundos!\nToca la piñata lo más rápido que puedas. Si logras 50 toques, te llevas el Premio Mayor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 48),
            AppPrimaryButton(
              label: '¡A ROMPERLA!',
              backgroundColor: Colors.amber,
              foregroundColor: AppColors.primaryDark,
              onPressed: _startGame,
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
    );
  }

  Widget _buildPlayingScreen() {
    return Column(
      children: [
        // HUD Superior
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHudChip(
                Icons.touch_app_rounded,
                'Toques: $_tapCount',
                Colors.amber,
              ),
              _buildHudChip(
                Icons.timer_rounded,
                '00:${_timeLeft.toString().padLeft(2, '0')}',
                Colors.white,
              ),
            ],
          ),
        ),
        // Área Central Interactiva
        Expanded(
          child: Center(
            child: GestureDetector(
              onTapDown: (_) => _onPinataTap(),
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _shakeAnimation.value * pi,
                    child: Transform.scale(
                      scale: _getPinataScale(),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: _getPinataColor().withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: _getPinataColor(), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _getPinataColor().withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: _tapCount.toDouble(), // El brillo aumenta
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.redeem_rounded, // Ícono de regalo / caja fuerte
                    size: 80,
                    color: _getPinataColor(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Mensaje de motivación
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Text(
            _tapCount < 10
                ? '¡TOCA MÁS RÁPIDO!'
                : _tapCount < 30
                ? '¡ESO ES! ¡SÍGUELE!'
                : _tapCount < 50
                ? '¡YA CASI SE ROMPE!'
                : '¡PIÑATA ROTA!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    final bool wonGrandPrize = _tapCount >= 50;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¡Tiempo Agotado!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_tapCount toques',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              wonGrandPrize
                  ? Icons.emoji_events_rounded
                  : Icons.thumb_up_alt_rounded,
              size: 80,
              color: wonGrandPrize ? Colors.amber : Colors.blueAccent,
            ),
            const SizedBox(height: 24),
            Text(
              wonGrandPrize ? '¡Rompiste la piñata!' : '¡Buen esfuerzo!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Has ganado $_pointsEarned monedas.',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            if (_isSaving)
              const CircularProgressIndicator(color: Colors.amber)
            else
              AppPrimaryButton(
                label: 'Reclamar Premio',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                onPressed: () => Navigator.pop(context, _pointsEarned),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
