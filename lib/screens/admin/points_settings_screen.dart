import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen> {
  static const String _earningRateKey = 'points_earning_rate';
  static const String _pointsRatioKey = 'points_to_soles_ratio';
  static const String _checkinRewardKey = 'checkin_reward';
  static const String _checkinStreakStepKey = 'checkin_streak_step';
  static const String _boxesDailyLimitKey = 'boxes_daily_limit';
  static const String _memoramaDailyLimitKey = 'memorama_daily_limit';
  static const String _catcherDailyLimitKey = 'catcher_daily_limit';
  static const String _pinataDailyLimitKey = 'pinata_daily_limit';
  static const String _jumpDailyLimitKey = 'jump_daily_limit';
  static const String _clawDailyLimitKey = 'claw_daily_limit';
  static const String _stackDailyLimitKey = 'stack_daily_limit';
  static const String _dodgeDailyLimitKey = 'dodge_daily_limit';
  static const String _boxesPrize1Key = 'boxes_prize_1';
  static const String _boxesPrize2Key = 'boxes_prize_2';
  static const String _boxesPrize3Key = 'boxes_prize_3';
  static const String _pinataGrandPrizeKey = 'pinata_grand_prize';
  static const String _pinataConsolationPrizeKey = 'pinata_consolation_prize';
  static const String _memoramaMatchRewardKey = 'memorama_match_reward';
  static const String _catcherCoinRewardKey = 'catcher_coin_reward';
  static const String _catcherGiftRewardKey = 'catcher_gift_reward';
  static const String _catcherBombPenaltyKey = 'catcher_bomb_penalty';
  static const String _clawPrize1Key = 'claw_prize_1';
  static const String _clawPrize2Key = 'claw_prize_2';
  static const String _clawPrize3Key = 'claw_prize_3';
  static const String _clawPrize4Key = 'claw_prize_4';
  static const String _clawPrize5Key = 'claw_prize_5';
  static const double _defaultEarningRate = 0.03;
  static const double _defaultPointsRatio = 0.01;
  static const double _defaultCheckinReward = 20;
  static const double _defaultCheckinStreakStep = 10;
  static const double _defaultBoxesDailyLimit = 1;
  static const double _defaultMemoramaDailyLimit = 1;
  static const double _defaultCatcherDailyLimit = 1;
  static const double _defaultPinataDailyLimit = 1;
  static const double _defaultJumpDailyLimit = 1;
  static const double _defaultClawDailyLimit = 1;
  static const double _defaultStackDailyLimit = 1;
  static const double _defaultDodgeDailyLimit = 1;
  static const double _defaultBoxesPrize1 = 10;
  static const double _defaultBoxesPrize2 = 20;
  static const double _defaultBoxesPrize3 = 30;
  static const double _defaultPinataGrandPrize = 50;
  static const double _defaultPinataConsolationPrize = 5;
  static const double _defaultMemoramaMatchReward = 5;
  static const double _defaultCatcherCoinReward = 1;
  static const double _defaultCatcherGiftReward = 5;
  static const double _defaultCatcherBombPenalty = -3;
  static const double _defaultClawPrize1 = 5;
  static const double _defaultClawPrize2 = 20;
  static const double _defaultClawPrize3 = 50;
  static const double _defaultClawPrize4 = 10;
  static const double _defaultClawPrize5 = 5;

  final _earningRateCtrl = TextEditingController();
  final _pointsRatioCtrl = TextEditingController();
  final _checkinRewardCtrl = TextEditingController();
  final _checkinStreakStepCtrl = TextEditingController();
  final _boxesDailyLimitCtrl = TextEditingController();
  final _memoramaDailyLimitCtrl = TextEditingController();
  final _catcherDailyLimitCtrl = TextEditingController();
  final _pinataDailyLimitCtrl = TextEditingController();
  final _jumpDailyLimitCtrl = TextEditingController();
  final _clawDailyLimitCtrl = TextEditingController();
  final _stackDailyLimitCtrl = TextEditingController();
  final _dodgeDailyLimitCtrl = TextEditingController();
  final _boxesPrize1Ctrl = TextEditingController();
  final _boxesPrize2Ctrl = TextEditingController();
  final _boxesPrize3Ctrl = TextEditingController();
  final _pinataGrandPrizeCtrl = TextEditingController();
  final _pinataConsolationPrizeCtrl = TextEditingController();
  final _memoramaMatchRewardCtrl = TextEditingController();
  final _catcherCoinRewardCtrl = TextEditingController();
  final _catcherGiftRewardCtrl = TextEditingController();
  final _catcherBombPenaltyCtrl = TextEditingController();
  final _clawPrize1Ctrl = TextEditingController();
  final _clawPrize2Ctrl = TextEditingController();
  final _clawPrize3Ctrl = TextEditingController();
  final _clawPrize4Ctrl = TextEditingController();
  final _clawPrize5Ctrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _didLoadInitialValues = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialValues) return;

    final config = context.read<AppConfigProvider>();
    _earningRateCtrl.text = _formatRate(
      config.getDouble(_earningRateKey, _defaultEarningRate),
    );
    _pointsRatioCtrl.text = _formatRate(
      config.getDouble(_pointsRatioKey, _defaultPointsRatio),
    );
    _checkinRewardCtrl.text = _formatRate(
      config.getDouble(_checkinRewardKey, _defaultCheckinReward),
    );
    _checkinStreakStepCtrl.text = _formatRate(
      config.getDouble(_checkinStreakStepKey, _defaultCheckinStreakStep),
    );
    _boxesDailyLimitCtrl.text = _formatRate(
      config.getDouble(_boxesDailyLimitKey, _defaultBoxesDailyLimit),
    );
    _memoramaDailyLimitCtrl.text = _formatRate(
      config.getDouble(_memoramaDailyLimitKey, _defaultMemoramaDailyLimit),
    );
    _catcherDailyLimitCtrl.text = _formatRate(
      config.getDouble(_catcherDailyLimitKey, _defaultCatcherDailyLimit),
    );
    _pinataDailyLimitCtrl.text = _formatRate(
      config.getDouble(_pinataDailyLimitKey, _defaultPinataDailyLimit),
    );
    _jumpDailyLimitCtrl.text = _formatRate(
      config.getDouble(_jumpDailyLimitKey, _defaultJumpDailyLimit),
    );
    _clawDailyLimitCtrl.text = _formatRate(
      config.getDouble(_clawDailyLimitKey, _defaultClawDailyLimit),
    );
    _stackDailyLimitCtrl.text = _formatRate(
      config.getDouble(_stackDailyLimitKey, _defaultStackDailyLimit),
    );
    _dodgeDailyLimitCtrl.text = _formatRate(
      config.getDouble(_dodgeDailyLimitKey, _defaultDodgeDailyLimit),
    );
    _boxesPrize1Ctrl.text = _formatRate(
      config.getDouble(_boxesPrize1Key, _defaultBoxesPrize1),
    );
    _boxesPrize2Ctrl.text = _formatRate(
      config.getDouble(_boxesPrize2Key, _defaultBoxesPrize2),
    );
    _boxesPrize3Ctrl.text = _formatRate(
      config.getDouble(_boxesPrize3Key, _defaultBoxesPrize3),
    );
    _pinataGrandPrizeCtrl.text = _formatRate(
      config.getDouble(_pinataGrandPrizeKey, _defaultPinataGrandPrize),
    );
    _pinataConsolationPrizeCtrl.text = _formatRate(
      config.getDouble(
        _pinataConsolationPrizeKey,
        _defaultPinataConsolationPrize,
      ),
    );
    _memoramaMatchRewardCtrl.text = _formatRate(
      config.getDouble(_memoramaMatchRewardKey, _defaultMemoramaMatchReward),
    );
    _catcherCoinRewardCtrl.text = _formatRate(
      config.getDouble(_catcherCoinRewardKey, _defaultCatcherCoinReward),
    );
    _catcherGiftRewardCtrl.text = _formatRate(
      config.getDouble(_catcherGiftRewardKey, _defaultCatcherGiftReward),
    );
    _catcherBombPenaltyCtrl.text = _formatRate(
      config.getDouble(_catcherBombPenaltyKey, _defaultCatcherBombPenalty),
    );
    _clawPrize1Ctrl.text = _formatRate(
      config.getDouble(_clawPrize1Key, _defaultClawPrize1),
    );
    _clawPrize2Ctrl.text = _formatRate(
      config.getDouble(_clawPrize2Key, _defaultClawPrize2),
    );
    _clawPrize3Ctrl.text = _formatRate(
      config.getDouble(_clawPrize3Key, _defaultClawPrize3),
    );
    _clawPrize4Ctrl.text = _formatRate(
      config.getDouble(_clawPrize4Key, _defaultClawPrize4),
    );
    _clawPrize5Ctrl.text = _formatRate(
      config.getDouble(_clawPrize5Key, _defaultClawPrize5),
    );

    _didLoadInitialValues = true;
    _isLoading = false;
  }

  @override
  void dispose() {
    _earningRateCtrl.dispose();
    _pointsRatioCtrl.dispose();
    _checkinRewardCtrl.dispose();
    _checkinStreakStepCtrl.dispose();
    _boxesDailyLimitCtrl.dispose();
    _memoramaDailyLimitCtrl.dispose();
    _catcherDailyLimitCtrl.dispose();
    _pinataDailyLimitCtrl.dispose();
    _jumpDailyLimitCtrl.dispose();
    _clawDailyLimitCtrl.dispose();
    _stackDailyLimitCtrl.dispose();
    _dodgeDailyLimitCtrl.dispose();
    _boxesPrize1Ctrl.dispose();
    _boxesPrize2Ctrl.dispose();
    _boxesPrize3Ctrl.dispose();
    _pinataGrandPrizeCtrl.dispose();
    _pinataConsolationPrizeCtrl.dispose();
    _memoramaMatchRewardCtrl.dispose();
    _catcherCoinRewardCtrl.dispose();
    _catcherGiftRewardCtrl.dispose();
    _catcherBombPenaltyCtrl.dispose();
    _clawPrize1Ctrl.dispose();
    _clawPrize2Ctrl.dispose();
    _clawPrize3Ctrl.dispose();
    _clawPrize4Ctrl.dispose();
    _clawPrize5Ctrl.dispose();
    super.dispose();
  }

  String _formatRate(double rate) {
    final text = rate.toStringAsFixed(4);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double _parseRate(String value, double fallback) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }

  Future<void> _saveSetting() async {
    final earningRate = _parseRate(_earningRateCtrl.text, _defaultEarningRate);
    final pointsRatio = _parseRate(_pointsRatioCtrl.text, _defaultPointsRatio);
    final checkinReward = _parseRate(
      _checkinRewardCtrl.text,
      _defaultCheckinReward,
    );
    final checkinStreakStep = _parseRate(
      _checkinStreakStepCtrl.text,
      _defaultCheckinStreakStep,
    );
    final boxesDailyLimit = _parseRate(
      _boxesDailyLimitCtrl.text,
      _defaultBoxesDailyLimit,
    );
    final memoramaDailyLimit = _parseRate(
      _memoramaDailyLimitCtrl.text,
      _defaultMemoramaDailyLimit,
    );
    final catcherDailyLimit = _parseRate(
      _catcherDailyLimitCtrl.text,
      _defaultCatcherDailyLimit,
    );
    final pinataDailyLimit = _parseRate(
      _pinataDailyLimitCtrl.text,
      _defaultPinataDailyLimit,
    );
    final jumpDailyLimit = _parseRate(
      _jumpDailyLimitCtrl.text,
      _defaultJumpDailyLimit,
    );
    final clawDailyLimit = _parseRate(
      _clawDailyLimitCtrl.text,
      _defaultClawDailyLimit,
    );
    final stackDailyLimit = _parseRate(
      _stackDailyLimitCtrl.text,
      _defaultStackDailyLimit,
    );
    final dodgeDailyLimit = _parseRate(
      _dodgeDailyLimitCtrl.text,
      _defaultDodgeDailyLimit,
    );
    final boxesPrize1 = _parseRate(_boxesPrize1Ctrl.text, _defaultBoxesPrize1);
    final boxesPrize2 = _parseRate(_boxesPrize2Ctrl.text, _defaultBoxesPrize2);
    final boxesPrize3 = _parseRate(_boxesPrize3Ctrl.text, _defaultBoxesPrize3);
    final pinataGrandPrize = _parseRate(
      _pinataGrandPrizeCtrl.text,
      _defaultPinataGrandPrize,
    );
    final pinataConsolationPrize = _parseRate(
      _pinataConsolationPrizeCtrl.text,
      _defaultPinataConsolationPrize,
    );
    final memoramaMatchReward = _parseRate(
      _memoramaMatchRewardCtrl.text,
      _defaultMemoramaMatchReward,
    );
    final catcherCoinReward = _parseRate(
      _catcherCoinRewardCtrl.text,
      _defaultCatcherCoinReward,
    );
    final catcherGiftReward = _parseRate(
      _catcherGiftRewardCtrl.text,
      _defaultCatcherGiftReward,
    );
    final catcherBombPenalty =
        double.tryParse(_catcherBombPenaltyCtrl.text.trim()) ??
        _defaultCatcherBombPenalty;
    final clawPrize1 = _parseRate(_clawPrize1Ctrl.text, _defaultClawPrize1);
    final clawPrize2 = _parseRate(_clawPrize2Ctrl.text, _defaultClawPrize2);
    final clawPrize3 = _parseRate(_clawPrize3Ctrl.text, _defaultClawPrize3);
    final clawPrize4 = _parseRate(_clawPrize4Ctrl.text, _defaultClawPrize4);
    final clawPrize5 = _parseRate(_clawPrize5Ctrl.text, _defaultClawPrize5);

    if (earningRate <= 0 ||
        pointsRatio <= 0 ||
        checkinReward <= 0 ||
        checkinStreakStep <= 0 ||
        boxesDailyLimit <= 0 ||
        memoramaDailyLimit <= 0 ||
        catcherDailyLimit <= 0 ||
        pinataDailyLimit <= 0 ||
        jumpDailyLimit <= 0 ||
        clawDailyLimit <= 0 ||
        stackDailyLimit <= 0 ||
        dodgeDailyLimit <= 0 ||
        boxesPrize1 <= 0 ||
        boxesPrize2 <= 0 ||
        boxesPrize3 <= 0 ||
        pinataGrandPrize <= 0 ||
        pinataConsolationPrize <= 0 ||
        memoramaMatchReward <= 0 ||
        catcherCoinReward <= 0 ||
        catcherGiftReward <= 0 ||
        clawPrize1 <= 0 ||
        clawPrize2 <= 0 ||
        clawPrize3 <= 0 ||
        clawPrize4 <= 0 ||
        clawPrize5 <= 0 ||
        catcherBombPenalty >= 0) {
      AppSnackbar.show(
        context,
        message:
            'Ingresa valores válidos. La penalización de bomba debe ser menor a 0.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final config = context.read<AppConfigProvider>();
      await Future.wait([
        config.saveValue(
          _earningRateKey,
          earningRate,
          description: 'Tasa de acumulación de monedas. Ej: 0.03 = 3%',
        ),
        config.saveValue(
          _pointsRatioKey,
          pointsRatio,
          description:
              'Valor de canje de cada moneda en soles. Ej: 0.01 = S/ 0.01',
        ),
        config.saveValue(
          _checkinRewardKey,
          checkinReward,
          description:
              'Cantidad de monedas que gana el usuario por check-in diario',
        ),
        config.saveValue(
          _checkinStreakStepKey,
          checkinStreakStep,
          description:
              'Incremento de monedas por cada día consecutivo de racha',
        ),
        config.saveValue(
          _boxesDailyLimitKey,
          boxesDailyLimit,
          description:
              'Límite de veces que se puede jugar a las cajitas al día',
        ),
        config.saveValue(
          _memoramaDailyLimitKey,
          memoramaDailyLimit,
          description: 'Límite de veces que se puede jugar al memorama al día',
        ),
        config.saveValue(
          _catcherDailyLimitKey,
          catcherDailyLimit,
          description:
              'Límite de veces que se puede jugar a la lluvia de monedas al día',
        ),
        config.saveValue(
          _pinataDailyLimitKey,
          pinataDailyLimit,
          description: 'Límite de veces que se puede jugar a la piñata al día',
        ),
        config.saveValue(
          _jumpDailyLimitKey,
          jumpDailyLimit,
          description:
              'Límite de veces que se puede jugar a Super Salto al día',
        ),
        config.saveValue(
          _clawDailyLimitKey,
          clawDailyLimit,
          description:
              'Límite de veces que se puede jugar a la máquina de garra al día',
        ),
        config.saveValue(
          _stackDailyLimitKey,
          stackDailyLimit,
          description:
              'Límite de veces que se puede jugar a la torre de cajas al día',
        ),
        config.saveValue(
          _dodgeDailyLimitKey,
          dodgeDailyLimit,
          description:
              'Límite de veces que se puede jugar a Esquiva y Atrapa al día',
        ),
        config.saveValue(
          _boxesPrize1Key,
          boxesPrize1,
          description: 'Premio 1 de las cajitas al azar',
        ),
        config.saveValue(
          _boxesPrize2Key,
          boxesPrize2,
          description: 'Premio 2 de las cajitas al azar',
        ),
        config.saveValue(
          _boxesPrize3Key,
          boxesPrize3,
          description: 'Premio 3 de las cajitas al azar',
        ),
        config.saveValue(
          _pinataGrandPrizeKey,
          pinataGrandPrize,
          description: 'Premio por lograr 50 o más toques en la piñata',
        ),
        config.saveValue(
          _pinataConsolationPrizeKey,
          pinataConsolationPrize,
          description:
              'Premio de consolación por menos de 50 toques en la piñata',
        ),
        config.saveValue(
          _memoramaMatchRewardKey,
          memoramaMatchReward,
          description:
              'Puntos ganados por cada pareja encontrada en el Memorama',
        ),
        config.saveValue(
          _catcherCoinRewardKey,
          catcherCoinReward,
          description:
              'Puntos ganados por cada moneda atrapada en Lluvia de Monedas',
        ),
        config.saveValue(
          _catcherGiftRewardKey,
          catcherGiftReward,
          description:
              'Puntos ganados por cada regalo atrapado en Lluvia de Monedas',
        ),
        config.saveValue(
          _catcherBombPenaltyKey,
          catcherBombPenalty,
          description:
              'Penalización por cada bomba atrapada en Lluvia de Monedas',
        ),
        config.saveValue(
          _clawPrize1Key,
          clawPrize1,
          description: 'Premio 1 (Izquierda) Máquina de Garra',
        ),
        config.saveValue(
          _clawPrize2Key,
          clawPrize2,
          description: 'Premio 2 Máquina de Garra',
        ),
        config.saveValue(
          _clawPrize3Key,
          clawPrize3,
          description: 'Premio 3 (Centro/Mayor) Máquina de Garra',
        ),
        config.saveValue(
          _clawPrize4Key,
          clawPrize4,
          description: 'Premio 4 Máquina de Garra',
        ),
        config.saveValue(
          _clawPrize5Key,
          clawPrize5,
          description: 'Premio 5 (Derecha) Máquina de Garra',
        ),
      ]);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Configuración guardada.',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Configuración de Monedas',
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Acumulación de monedas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define la tasa usada para calcular las monedas ganadas al completar una compra.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _earningRateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Tasa de acumulación',
                                hintText: '0.03',
                                helperText: 'Ejemplo: 0.03 = 3%',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Piñata',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define el premio grande para 50 o más toques y el premio de consolación cuando no se llegue a la meta.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _pinataGrandPrizeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Premio mayor de la piñata',
                                hintText: '50',
                                helperText:
                                    'Se entrega al lograr 50 o más toques',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinataConsolationPrizeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Premio de consolación',
                                hintText: '5',
                                helperText:
                                    'Se entrega si no llega a 50 toques',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Premios de cajitas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Estos tres valores se mezclan en cada ronda para que el usuario no sepa qué premio saldrá.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _boxesPrize1Ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Premio 1',
                                hintText: '10',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _boxesPrize2Ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Premio 2',
                                hintText: '20',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _boxesPrize3Ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Premio 3',
                                hintText: '30',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Premios Máquina de Garra',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define los valores de las 5 cápsulas en el fondo de la máquina (de izquierda a derecha).',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _clawPrize1Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P1',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _clawPrize2Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P2',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _clawPrize3Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P3',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _clawPrize4Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P4',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _clawPrize5Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P5',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Límites diarios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define cuántas veces se puede jugar cada mini juego por día.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _boxesDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite cajitas por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _memoramaDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite memorama por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _catcherDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite lluvia por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinataDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite piñata por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _jumpDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite Super Salto por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _clawDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite máquina de garra por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _stackDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite torre de cajas por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _dodgeDailyLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Límite esquiva y atrapa por día',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Memorama',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Puntos ganados por cada pareja encontrada en el Memorama.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _memoramaMatchRewardCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Puntos por pareja',
                                hintText: '5',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lluvia de Monedas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Configura los puntos por moneda, regalo y la penalización por bomba.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _catcherCoinRewardCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Puntos por moneda',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _catcherGiftRewardCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Puntos por regalo',
                                hintText: '5',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _catcherBombPenaltyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Penalización por bomba',
                                hintText: '-3',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Check-in diario',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define las monedas base del día 1 de la racha diaria. El día 2 suma 10 monedas más y así sucesivamente.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _checkinRewardCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Monedas por check-in',
                                hintText: '20',
                                helperText: 'Ejemplo: 20 monedas en el día 1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Incremento de racha',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cuánto sube la recompensa por cada día consecutivo. Ejemplo: 10, 20, 30...',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _checkinStreakStepCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Monedas extra por día',
                                hintText: '10',
                                helperText:
                                    'Ejemplo: +10 por cada día de racha',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valor de canje',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Define cuánto vale cada punto al descontarlo en una venta.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _pointsRatioCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Valor de 1 punto en soles',
                                hintText: '0.01',
                                helperText: 'Ejemplo: 0.01 = S/ 0.01 por punto',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.teal.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.teal.shade100),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Uso profesional: la app carga estos valores al iniciar y los reutiliza en admin y cliente. Cuando guardes cambios, el proveedor global se actualiza sin recargar la pantalla.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label:
                          _isSaving ? 'Guardando...' : 'Guardar configuración',
                      onPressed: _isSaving ? null : _saveSetting,
                    ),
                  ],
                ),
              ),
    );
  }
}
