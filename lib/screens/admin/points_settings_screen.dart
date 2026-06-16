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

class _PointsSettingsScreenState extends State<PointsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Claves de la base de datos
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

  // Controladores y definiciones
  final Map<String, _SettingDefinition> _settings = {};

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Inicializar mapa de configuraciones
    _initSettingDef(
      _earningRateKey,
      0.03,
      'Tasa de acumulación (ej: 0.03 = 3%)',
    );
    _initSettingDef(
      _pointsRatioKey,
      0.01,
      'Valor en soles (ej: 0.01 = S/ 0.01)',
    );
    _initSettingDef(_checkinRewardKey, 20, 'Monedas por check-in día 1');
    _initSettingDef(_checkinStreakStepKey, 10, 'Monedas extra por racha');

    _initSettingDef(_boxesDailyLimitKey, 1, 'Límite diario: Cajitas');
    _initSettingDef(_memoramaDailyLimitKey, 1, 'Límite diario: Memorama');
    _initSettingDef(_catcherDailyLimitKey, 1, 'Límite diario: Lluvia');
    _initSettingDef(_pinataDailyLimitKey, 1, 'Límite diario: Piñata');
    _initSettingDef(_jumpDailyLimitKey, 1, 'Límite diario: Salto');
    _initSettingDef(_clawDailyLimitKey, 1, 'Límite diario: Garra');
    _initSettingDef(_stackDailyLimitKey, 1, 'Límite diario: Cajas');
    _initSettingDef(_dodgeDailyLimitKey, 1, 'Límite diario: Esquiva');

    _initSettingDef(_boxesPrize1Key, 10, 'Cajitas: Premio 1');
    _initSettingDef(_boxesPrize2Key, 20, 'Cajitas: Premio 2');
    _initSettingDef(_boxesPrize3Key, 30, 'Cajitas: Premio 3');
    _initSettingDef(_pinataGrandPrizeKey, 50, 'Piñata: Mayor (>= 50 toques)');
    _initSettingDef(_pinataConsolationPrizeKey, 5, 'Piñata: Consolación');
    _initSettingDef(_memoramaMatchRewardKey, 5, 'Memorama: Puntos por pareja');
    _initSettingDef(_catcherCoinRewardKey, 1, 'Lluvia: Puntos por moneda');
    _initSettingDef(_catcherGiftRewardKey, 5, 'Lluvia: Puntos por regalo');
    _initSettingDef(
      _catcherBombPenaltyKey,
      -3,
      'Lluvia: Penalidad por bomba (negativo)',
    );

    _initSettingDef(_clawPrize1Key, 5, 'Garra: P1 (Izquierda)');
    _initSettingDef(_clawPrize2Key, 20, 'Garra: P2');
    _initSettingDef(_clawPrize3Key, 50, 'Garra: P3 (Centro)');
    _initSettingDef(_clawPrize4Key, 10, 'Garra: P4');
    _initSettingDef(_clawPrize5Key, 5, 'Garra: P5 (Derecha)');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _initSettingDef(String key, double fallback, String description) {
    _settings[key] = _SettingDefinition(
      key: key,
      fallback: fallback,
      description: description,
      controller: TextEditingController(),
    );
  }

  void _loadData() {
    final config = context.read<AppConfigProvider>();
    if (config.isLoaded) {
      _fillControllers(config);
      setState(() => _isInitialized = true);
    } else {
      config.addListener(_onConfigLoaded);
    }
  }

  void _onConfigLoaded() {
    final config = context.read<AppConfigProvider>();
    if (config.isLoaded) {
      config.removeListener(_onConfigLoaded);
      if (mounted) {
        _fillControllers(config);
        setState(() => _isInitialized = true);
      }
    }
  }

  void _fillControllers(AppConfigProvider config) {
    for (final def in _settings.values) {
      final val = config.getDouble(def.key, def.fallback);
      final text = val.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
      def.controller.text = text;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final def in _settings.values) {
      def.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Por favor, corrige los errores en los campos.',
        type: SnackbarType.error,
      );
      return;
    }

    final newValues = <String, double>{};
    final descriptions = <String, String>{};

    for (final def in _settings.values) {
      final parsed =
          double.tryParse(def.controller.text.trim()) ?? def.fallback;
      newValues[def.key] = parsed;
      descriptions[def.key] = def.description;
    }

    final provider = context.read<AppConfigProvider>();
    final success = await provider.saveMultipleValues(
      newValues,
      descriptions: descriptions,
    );

    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message: 'Configuración de monedas guardada.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar la configuración.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppConfigProvider>();

    return AdminLayout(
      title: 'Configuración de Monedas',
      showBackButton: true,
      body:
          !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Sistema y Ratio'),
                      Tab(text: 'Límites Diarios'),
                      Tab(text: 'Premios y Juegos'),
                    ],
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSystemTab(),
                          _buildLimitsTab(),
                          _buildPrizesTab(),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppPrimaryButton(
                      label:
                          provider.isSavingSettings
                              ? 'Guardando...'
                              : 'Guardar toda la configuración',
                      onPressed: provider.isSavingSettings ? null : _saveAll,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSystemTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Sistema de Puntos y Canjes',
          subtitle: 'Define el valor y las tasas de obtención generales.',
          children: [
            _buildField(_earningRateKey, allowZero: false),
            _buildField(_pointsRatioKey, allowZero: false),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Check-in Diario',
          subtitle: 'Recompensas por rachas consecutivas.',
          children: [
            _buildField(_checkinRewardKey, allowZero: false),
            _buildField(_checkinStreakStepKey, allowZero: false),
          ],
        ),
      ],
    );
  }

  Widget _buildLimitsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Límites de Juegos Diarios',
          subtitle:
              'Controla el máximo de veces que los usuarios pueden jugar cada día.',
          children: [
            _buildField(_boxesDailyLimitKey, allowZero: false),
            _buildField(_memoramaDailyLimitKey, allowZero: false),
            _buildField(_catcherDailyLimitKey, allowZero: false),
            _buildField(_pinataDailyLimitKey, allowZero: false),
            _buildField(_jumpDailyLimitKey, allowZero: false),
            _buildField(_clawDailyLimitKey, allowZero: false),
            _buildField(_stackDailyLimitKey, allowZero: false),
            _buildField(_dodgeDailyLimitKey, allowZero: false),
          ],
        ),
      ],
    );
  }

  Widget _buildPrizesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Cajitas Misteriosas',
          subtitle: 'Tres premios aleatorios que se esconden en las cajas.',
          children: [
            Row(
              children: [
                Expanded(child: _buildField(_boxesPrize1Key)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_boxesPrize2Key)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_boxesPrize3Key)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Piñata',
          subtitle: 'Premio mayor para 50+ toques y premio consolación.',
          children: [
            Row(
              children: [
                Expanded(child: _buildField(_pinataGrandPrizeKey)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_pinataConsolationPrizeKey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Lluvia de Monedas',
          subtitle:
              'Valor por atrapar monedas, regalos o penalidad por bombas.',
          children: [
            _buildField(_catcherCoinRewardKey),
            _buildField(_catcherGiftRewardKey),
            _buildField(_catcherBombPenaltyKey, allowNegative: true),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Memorama',
          subtitle: 'Puntos por acertar un par.',
          children: [_buildField(_memoramaMatchRewardKey)],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Máquina de Garra',
          subtitle: 'Premios de la ranura 1 a la 5 (Izquierda a Derecha).',
          children: [
            Row(
              children: [
                Expanded(child: _buildField(_clawPrize1Key)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_clawPrize2Key)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_clawPrize3Key)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildField(_clawPrize4Key)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(_clawPrize5Key)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
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
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String key, {
    bool allowZero = true,
    bool allowNegative = false,
  }) {
    final def = _settings[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: def.controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: allowNegative,
        ),
        decoration: InputDecoration(
          labelText: def.description,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Requerido';
          final parsed = double.tryParse(text);
          if (parsed == null) return 'Inválido';
          if (!allowNegative && parsed < 0) return 'Debe ser positivo';
          if (!allowZero && parsed == 0) return 'Debe ser mayor a 0';
          if (allowNegative && parsed > 0 && key == _catcherBombPenaltyKey) {
            return 'Debe ser negativo';
          }
          return null;
        },
      ),
    );
  }
}

class _SettingDefinition {
  final String key;
  final double fallback;
  final String description;
  final TextEditingController controller;

  _SettingDefinition({
    required this.key,
    required this.fallback,
    required this.description,
    required this.controller,
  });
}
