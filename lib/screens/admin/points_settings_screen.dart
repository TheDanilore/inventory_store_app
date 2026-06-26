import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

enum SettingFormat { number, percent, currency, integer }

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0; // For navigation rail

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

  final _formsKeys = {
    0: GlobalKey<FormState>(),
    1: GlobalKey<FormState>(),
    2: GlobalKey<FormState>(),
  };

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });

    // Sistema y Ratio
    _initSettingDef(
      _earningRateKey,
      0.03,
      'Tasa de acumulación',
      format: SettingFormat.percent,
    );
    _initSettingDef(
      _pointsRatioKey,
      0.01,
      'Valor por punto',
      format: SettingFormat.currency,
    );
    _initSettingDef(
      _checkinRewardKey,
      20,
      'Premio Check-in día 1',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _checkinStreakStepKey,
      10,
      'Bono por racha',
      format: SettingFormat.integer,
    );

    // Límites Diarios
    _initSettingDef(
      _boxesDailyLimitKey,
      1,
      'Cajitas Misteriosas',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _memoramaDailyLimitKey,
      1,
      'Memorama',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _catcherDailyLimitKey,
      1,
      'Lluvia de Monedas',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _pinataDailyLimitKey,
      1,
      'Piñata',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _jumpDailyLimitKey,
      1,
      'Salto',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _clawDailyLimitKey,
      1,
      'Máquina de Garra',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _stackDailyLimitKey,
      1,
      'Apilador',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _dodgeDailyLimitKey,
      1,
      'Esquiva',
      format: SettingFormat.integer,
    );

    // Premios
    _initSettingDef(
      _boxesPrize1Key,
      10,
      'Premio 1',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _boxesPrize2Key,
      20,
      'Premio 2',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _boxesPrize3Key,
      30,
      'Premio 3',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _pinataGrandPrizeKey,
      50,
      'Mayor (>= 50)',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _pinataConsolationPrizeKey,
      5,
      'Consolación',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _memoramaMatchRewardKey,
      5,
      'Pts por pareja',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _catcherCoinRewardKey,
      1,
      'Pts por moneda',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _catcherGiftRewardKey,
      5,
      'Pts por regalo',
      format: SettingFormat.integer,
    );
    _initSettingDef(
      _catcherBombPenaltyKey,
      -3,
      'Penalidad bomba',
      format: SettingFormat.integer,
      icon: Icons.warning_rounded,
    );

    _initSettingDef(
      _clawPrize1Key,
      5,
      'P1 (Izq)',
      format: SettingFormat.integer,
    );
    _initSettingDef(_clawPrize2Key, 20, 'P2', format: SettingFormat.integer);
    _initSettingDef(
      _clawPrize3Key,
      50,
      'P3 (Centro)',
      format: SettingFormat.integer,
    );
    _initSettingDef(_clawPrize4Key, 10, 'P4', format: SettingFormat.integer);
    _initSettingDef(
      _clawPrize5Key,
      5,
      'P5 (Der)',
      format: SettingFormat.integer,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _initSettingDef(
    String key,
    double fallback,
    String description, {
    SettingFormat format = SettingFormat.number,
    IconData? icon,
  }) {
    _settings[key] = _SettingDefinition(
      key: key,
      fallback: fallback,
      description: description,
      controller: TextEditingController(),
      format: format,
      icon: icon,
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
      double val = config.getDouble(def.key, def.fallback);
      if (def.format == SettingFormat.percent) {
        val = val * 100;
      }

      String text;
      if (def.format == SettingFormat.integer) {
        text = val.toInt().toString();
      } else {
        text = val.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
      }
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

  Future<void> _saveSection(int tabIndex, List<String> keys) async {
    final formKey = _formsKeys[tabIndex];
    if (formKey == null || !formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Corrige los errores en esta sección antes de guardar.',
        type: SnackbarType.error,
      );
      return;
    }

    final newValues = <String, double>{};
    final descriptions = <String, String>{};

    for (final key in keys) {
      final def = _settings[key]!;
      double parsed =
          double.tryParse(def.controller.text.trim()) ?? def.fallback;

      if (def.format == SettingFormat.percent) {
        parsed = parsed / 100.0;
      }

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
          message: 'Configuración guardada correctamente.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'Error al guardar la configuración.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Configuración de Juegos',
      showBackButton: true,
      body:
          !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNavigationRail(),
                        Container(width: 1, color: Colors.grey.shade200),
                        Expanded(
                          child: Container(
                            color: AppColors.background,
                            alignment: Alignment.topCenter,
                            child: _buildSelectedTabContent(_selectedIndex),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Sistema y Ratio'),
                          Tab(text: 'Límites Diarios'),
                          Tab(text: 'Premios'),
                        ],
                      ),
                      Expanded(
                        child: Container(
                          color: AppColors.background,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSelectedTabContent(0),
                              _buildSelectedTabContent(1),
                              _buildSelectedTabContent(2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildRailItem(0, Icons.settings_rounded, 'Sistema y Ratio'),
          _buildRailItem(1, Icons.sports_esports_rounded, 'Límites Diarios'),
          _buildRailItem(2, Icons.redeem_rounded, 'Premios y Juegos'),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(int index) {
    return Form(
      key: _formsKeys[index],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (index == 0) _buildSystemTab(),
          if (index == 1) _buildLimitsTab(),
          if (index == 2) _buildPrizesTab(),
        ],
      ),
    );
  }

  Widget _buildSystemTab() {
    final keys = [
      _earningRateKey,
      _pointsRatioKey,
      _checkinRewardKey,
      _checkinStreakStepKey,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Sistema de Puntos y Canjes',
          subtitle: 'Define el valor monetario y la acumulación.',
          icon: Icons.currency_exchange_rounded,
          color: Colors.blue,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildField(_earningRateKey)),
                const SizedBox(width: 16),
                Expanded(child: _buildField(_pointsRatioKey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Check-in Diario',
          subtitle: 'Recompensas por rachas consecutivas.',
          icon: Icons.fact_check_rounded,
          color: Colors.green,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildField(_checkinRewardKey)),
                const SizedBox(width: 16),
                Expanded(child: _buildField(_checkinStreakStepKey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(0, keys),
      ],
    );
  }

  Widget _buildLimitsTab() {
    final keys = [
      _boxesDailyLimitKey,
      _memoramaDailyLimitKey,
      _catcherDailyLimitKey,
      _pinataDailyLimitKey,
      _jumpDailyLimitKey,
      _clawDailyLimitKey,
      _stackDailyLimitKey,
      _dodgeDailyLimitKey,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Límites de Juegos Diarios',
          subtitle:
              'Controla el máximo de veces que los usuarios pueden jugar cada día.',
          icon: Icons.sports_esports_rounded,
          color: Colors.orange,
          children: [
            _buildGridLayout([
              _buildField(_boxesDailyLimitKey),
              _buildField(_memoramaDailyLimitKey),
              _buildField(_catcherDailyLimitKey),
              _buildField(_pinataDailyLimitKey),
              _buildField(_jumpDailyLimitKey),
              _buildField(_clawDailyLimitKey),
              _buildField(_stackDailyLimitKey),
              _buildField(_dodgeDailyLimitKey),
            ]),
          ],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(1, keys),
      ],
    );
  }

  Widget _buildPrizesTab() {
    final keys = [
      _boxesPrize1Key,
      _boxesPrize2Key,
      _boxesPrize3Key,
      _pinataGrandPrizeKey,
      _pinataConsolationPrizeKey,
      _catcherCoinRewardKey,
      _catcherGiftRewardKey,
      _catcherBombPenaltyKey,
      _memoramaMatchRewardKey,
      _clawPrize1Key,
      _clawPrize2Key,
      _clawPrize3Key,
      _clawPrize4Key,
      _clawPrize5Key,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Cajitas Misteriosas',
          subtitle: 'Premios aleatorios de las cajas.',
          icon: Icons.inventory_2_rounded,
          color: Colors.purple,
          children: [
            _buildGridLayout([
              _buildField(_boxesPrize1Key),
              _buildField(_boxesPrize2Key),
              _buildField(_boxesPrize3Key),
            ], crossAxisCount: 3),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Piñata y Memorama',
          subtitle: 'Premios mayores, consolación y por pares.',
          icon: Icons.celebration_rounded,
          color: Colors.pink,
          children: [
            _buildGridLayout([
              _buildField(_pinataGrandPrizeKey),
              _buildField(_pinataConsolationPrizeKey),
              _buildField(_memoramaMatchRewardKey),
            ], crossAxisCount: 3),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Lluvia de Monedas',
          subtitle: 'Valor por atrapar elementos.',
          icon: Icons.cloud_download_rounded,
          color: Colors.lightBlue,
          children: [
            _buildGridLayout([
              _buildField(_catcherCoinRewardKey),
              _buildField(_catcherGiftRewardKey),
              _buildField(_catcherBombPenaltyKey, allowNegative: true),
            ], crossAxisCount: 3),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Máquina de Garra',
          subtitle: 'Premios según la ranura donde cae el gancho (1 al 5).',
          icon: Icons.precision_manufacturing_rounded,
          color: Colors.amber,
          children: [
            _buildGridLayout([
              _buildField(_clawPrize1Key),
              _buildField(_clawPrize2Key),
              _buildField(_clawPrize3Key),
              _buildField(_clawPrize4Key),
              _buildField(_clawPrize5Key),
            ], crossAxisCount: 3),
          ],
        ),
        const SizedBox(height: 24),
        _buildSaveButton(2, keys),
      ],
    );
  }

  Widget _buildGridLayout(List<Widget> children, {int crossAxisCount = 2}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final actualCols = width < 400 ? 1 : crossAxisCount;

        List<Row> rows = [];
        for (var i = 0; i < children.length; i += actualCols) {
          List<Widget> rowChildren = [];
          for (var j = 0; j < actualCols; j++) {
            if (i + j < children.length) {
              rowChildren.add(Expanded(child: children[i + j]));
            } else {
              rowChildren.add(Expanded(child: const SizedBox()));
            }
            if (j < actualCols - 1) {
              rowChildren.add(const SizedBox(width: 16));
            }
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }

        return Column(
          children:
              rows
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: r,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildSaveButton(int tabIndex, List<String> keys) {
    final provider = context.watch<AppConfigProvider>();
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 250,
        child: AppPrimaryButton(
          label: provider.isSavingSettings ? 'Guardando...' : 'Guardar Cambios',
          onPressed:
              provider.isSavingSettings
                  ? null
                  : () => _saveSection(tabIndex, keys),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String key, {bool allowNegative = false}) {
    final def = _settings[key]!;

    Widget? prefix;
    Widget? suffix;
    TextInputType kType = const TextInputType.numberWithOptions(
      decimal: true,
      signed: false,
    );

    if (def.format == SettingFormat.percent) {
      suffix = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          '%',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    } else if (def.format == SettingFormat.currency) {
      prefix = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          'S/',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
      );
    } else if (def.format == SettingFormat.integer) {
      kType = TextInputType.numberWithOptions(
        decimal: false,
        signed: allowNegative,
      );
      prefix = Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(
          def.icon ?? Icons.monetization_on_rounded,
          color: Colors.amber,
          size: 20,
        ),
      );
    }

    return TextFormField(
      controller: def.controller,
      keyboardType: kType,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        labelText: def.description,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Requerido';
        final parsed = double.tryParse(text);
        if (parsed == null) return 'Número inválido';
        if (!allowNegative && parsed < 0) return 'Debe ser positivo';
        if (def.format == SettingFormat.integer && parsed != parsed.toInt()) {
          return 'Debe ser entero';
        }
        if (allowNegative && parsed > 0 && key == _catcherBombPenaltyKey) {
          return 'Debe ser negativo';
        }
        return null;
      },
    );
  }
}

class _SettingDefinition {
  final String key;
  final double fallback;
  final String description;
  final TextEditingController controller;
  final SettingFormat format;
  final IconData? icon;

  _SettingDefinition({
    required this.key,
    required this.fallback,
    required this.description,
    required this.controller,
    required this.format,
    this.icon,
  });
}
