import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:vibration/vibration.dart';

// --- MODELO PARA LAS CAJAS ---
class StackBox {
  double left;
  double width;
  Color color;
  StackBox({required this.left, required this.width, required this.color});
}

class StackGameScreen extends StatefulWidget {
  final String profileId;

  const StackGameScreen({super.key, required this.profileId});

  @override
  State<StackGameScreen> createState() => _StackGameScreenState();
}

class _StackGameScreenState extends State<StackGameScreen> {
  // --- CONFIGURACIÓN DEL TABLERO ---
  final double _boardWidth = 300.0;
  final double _boxHeight = 35.0;
  final double _initialWidth = 200.0;
  final double _perfectTolerance =
      18.0; // Píxeles de tolerancia para un "Perfecto"
  final double _minSafeWidth = 36.0;

  // --- ESTADOS DEL JUEGO ---
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  int _score = 0; // Monedas ganadas
  int _comboPerfecto = 0; // Para efectos visuales futuros

  Timer? _gameTimer;

  // Lista de cajas ya apiladas
  List<StackBox> _stackedBoxes = [];

  // La caja que se está moviendo actualmente
  StackBox? _movingBox;

  // Físicas
  double _speed = 1.4;
  int _direction = 1; // 1 = derecha, -1 = izquierda

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
      _comboPerfecto = 0;
      _speed = 1.4;
      _direction = 1;

      // Reiniciamos la torre
      _stackedBoxes = [
        StackBox(
          left: (_boardWidth - _initialWidth) / 2,
          width: _initialWidth,
          color: _getColorForScore(0),
        ),
      ];

      _spawnNewBox();
    });

    // Game Loop (Aproximadamente 60 FPS)
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _movingBox == null) return;

      setState(() {
        _movingBox!.left += _speed * _direction;

        // Rebote en las paredes
        if (_movingBox!.left + _movingBox!.width >= _boardWidth) {
          _movingBox!.left = _boardWidth - _movingBox!.width;
          _direction = -1;
        } else if (_movingBox!.left <= 0) {
          _movingBox!.left = 0;
          _direction = 1;
        }
      });
    });
  }

  void _spawnNewBox() {
    final lastBox = _stackedBoxes.last;
    _movingBox = StackBox(
      left: _direction == 1 ? 0 : _boardWidth - lastBox.width,
      width: lastBox.width,
      color: _getColorForScore(_score + 1),
    );
  }

  // Genera un gradiente de colores infinito basado en el puntaje
  Color _getColorForScore(int score) {
    final hue = (score * 8.0) % 360.0;
    return HSLColor.fromAHSL(1.0, hue, 0.8, 0.5).toColor();
  }

  void _handleTap() {
    if (!_isPlaying || _movingBox == null) return;

    final lastBox = _stackedBoxes.last;
    final movingCenter = _movingBox!.left + (_movingBox!.width / 2);
    final lastCenter = lastBox.left + (lastBox.width / 2);
    final centerDifference = (movingCenter - lastCenter).abs();

    // 1. Verificar si hubo un "Perfecto" (Imán)
    if (centerDifference <= _perfectTolerance) {
      // LO LOGRÓ PERFECTO
      if (!kIsWeb) {
        Vibration.vibrate(duration: 80, amplitude: 128);
      }
      _movingBox!.left = lastBox.left;
      _movingBox!.width = lastBox.width;
      _comboPerfecto++;
    } else {
      // 2. CORTE DE LA CAJA
      if (!kIsWeb) {
        Vibration.vibrate(duration: 30, amplitude: 64);
      }
      _comboPerfecto = 0;

      final overlapLeft = max(_movingBox!.left, lastBox.left);
      final overlapRight = min(
        _movingBox!.left + _movingBox!.width,
        lastBox.left + lastBox.width,
      );
      final overlapWidth = overlapRight - overlapLeft;

      if (overlapWidth <= 0) {
        // Falló por completo. La caja cae al vacío.
        _gameOver();
        return;
      }

      final centeredLeft =
          movingCenter < lastCenter
              ? lastBox.left
              : lastBox.left + (lastBox.width - overlapWidth);

      final newLeft =
          centeredLeft
              .clamp(lastBox.left, lastBox.left + lastBox.width - overlapWidth)
              .toDouble();
      final newWidth = max(overlapWidth, _minSafeWidth);

      // Aplicamos el corte
      _movingBox!.left = newLeft;
      _movingBox!.width = newWidth;
    }

    setState(() {
      // Guardamos la caja en la torre
      _stackedBoxes.add(_movingBox!);
      _score++;

      // Aumentamos la dificultad de forma más suave
      if (_speed < 3.2) _speed += 0.03;

      _spawnNewBox();
    });
  }

  Future<void> _gameOver() async {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
      _movingBox = null; // Desaparece la caja en movimiento
    });

    // Guardar las monedas si hizo al menos 1 punto
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
        await context.read<PointsCubit>().recordMiniGameResult('MINI_GAME_STACK', _score, 'Torre de Cajas: $_score cajas apiladas. Ganó $_score monedas');
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
    // Calculamos el desplazamiento de la cámara para que la torre no se salga de la pantalla
    final cameraOffset =
        _stackedBoxes.length > 8
            ? (_stackedBoxes.length - 8) * _boxHeight
            : 0.0;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => _handleTap(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // --- EL TABLERO Y LA TORRE ---
              Center(
                child: SizedBox(
                  width: _boardWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Dibujamos las cajas ya apiladas
                      ..._stackedBoxes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final box = entry.value;
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          bottom:
                              (index * _boxHeight) -
                              cameraOffset +
                              100, // +100 para separarlo del piso
                          left: box.left,
                          child: _buildBoxWidget(box),
                        );
                      }),

                      // Dibujamos la caja que se está moviendo
                      if (_movingBox != null)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          bottom:
                              (_stackedBoxes.length * _boxHeight) -
                              cameraOffset +
                              100,
                          left: _movingBox!.left,
                          child: _buildBoxWidget(_movingBox!),
                        ),
                    ],
                  ),
                ),
              ),

              // --- HUD (PUNTUACIÓN) ---
              if (_isPlaying || _isGameOver)
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      if (_comboPerfecto >= 3)
                        Text(
                          '¡PERFECTO X$_comboPerfecto!',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

              // --- PANTALLAS DE INICIO Y FIN ---
              if (!_isPlaying && !_isGameOver)
                _buildOverlay(
                  title: 'Torre de Cajas',
                  subtitle:
                      'Toca la pantalla para apilar las cajas.\nSi no calculas bien, la caja se cortará.\n¡Cada caja apilada es 1 moneda!',
                  buttonLabel: 'INICIAR JUEGO',
                  onPressed: _startGame,
                  icon: Icons.layers_rounded,
                  iconColor: Colors.amber,
                ),

              if (_isGameOver)
                _buildOverlay(
                  title: '¡Se cayó la torre!',
                  subtitle:
                      'Lograste apilar $_score cajas.\nHas ganado $_score monedas.',
                  buttonLabel: 'RECLAMAR MONEDAS',
                  onPressed: () => Navigator.pop(context, _score),
                  icon: Icons.block_flipped,
                  iconColor: Colors.redAccent,
                  isGameOver: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Diseño individual de cada caja
  Widget _buildBoxWidget(StackBox box) {
    return Container(
      width: box.width,
      height: _boxHeight,
      decoration: BoxDecoration(
        color: box.color,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: box.color.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Patrón sutil para que parezca una caja de inventario
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Colors.white.withValues(alpha: 0.2),
          size: 20,
        ),
      ),
    );
  }

  // Vista de las ventanas semitransparentes (Inicio y Fin)
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

