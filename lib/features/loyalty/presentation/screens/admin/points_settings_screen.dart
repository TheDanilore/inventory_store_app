import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
// ignore: unused_import
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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
    final config = context.read<AppConfigCubit>();
    if (config.settingsState == ViewState.success) {
      _fillControllers(config);
      setState(() => _isInitialized = true);
    } else {
      config.loadConfig();
    }
  }

  void _fillControllers(AppConfigCubit config) {
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppConfigCubit, AppConfigState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.saveStatus != current.saveStatus,
      listener: (context, state) {
        // Poblar controladores cuando los datos lleguen por primera vez
        if (state.status == ViewState.success && !_isInitialized) {
          _fillControllers(context.read<AppConfigCubit>());
          setState(() => _isInitialized = true);
        }
        // Feedback del guardado
        if (state.saveStatus == ViewState.success) {
          AppSnackbar.show(
            context,
            message: 'Configuración guardada correctamente.',
            type: SnackbarType.success,
          );
        } else if (state.saveStatus == ViewState.error) {
          AppSnackbar.show(
            context,
            message: state.errorMessage ?? 'Error al guardar la configuración.',
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state.saveStatus == ViewState.loading;
        final isLoading =
            state.status == ViewState.initial ||
            state.status == ViewState.loading;
        final hasError = state.status == ViewState.error;

        return AdminLayout(
          title: 'Configuración de Juegos',
          showBackButton: true,
          body:
              isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                  : hasError
                  ? _buildErrorState()
                  : _buildContent(state, isSaving),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error al cargar la configuración.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<AppConfigCubit>().loadConfig(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppConfigState state, bool isSaving) {
    // Banner de advertencia cuando Lealtad está desactivada globalmente
    final isDisabled = !(state.businessInfo?.loyaltyGlobalEnabled ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDisabled)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El módulo de Lealtad está desactivado globalmente. '
                    'Estos ajustes no tendrán efecto hasta que lo actives en '
                    'Información del Negocio.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 800) {
                return _buildWideLayout(isSaving);
              }
              return _buildMobileLayout(isSaving);
            },
          ),
        ),
      ],
    );
  }

  // ── Vista Ancha (≥800px): NavigationRail + contenido ──────────
  Widget _buildWideLayout(bool isSaving) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Menú de navegación
              Expanded(flex: 25, child: _buildNavigationRail()),
              const SizedBox(width: 32),
              // Columna Derecha: Contenido del tab
              Expanded(
                flex: 75,
                child: Form(
                  key: _formsKeys[_selectedIndex],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Builder(
                        builder: (context) {
                          if (_selectedIndex == 0) return _buildSystemTab(isSaving);
                          if (_selectedIndex == 1) return _buildLimitsTab(isSaving);
                          return _buildPrizesTab(isSaving);
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSaveButton(isSaving),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista Móvil (<800px): TabBar fijo + TabBarView con scroll ─────────────
  Widget _buildMobileLayout(bool isSaving) {
    return Column(
      children: [
        Material(
          color: AppColors.surface,
          elevation: 0,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Sistema y Ratio'),
              Tab(text: 'Límites Diarios'),
              Tab(text: 'Premios'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabScrollView(0, isSaving),
              _buildTabScrollView(1, isSaving),
              _buildTabScrollView(2, isSaving),
            ],
          ),
        ),
      ],
    );
  }

  /// Cada tab en mobile es un SingleChildScrollView independiente con su Form
  Widget _buildTabScrollView(int index, bool isSaving) {
    return Form(
      key: _formsKeys[index],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (index == 0) _buildSystemTab(isSaving),
            if (index == 1) _buildLimitsTab(isSaving),
            if (index == 2) _buildPrizesTab(isSaving),
            const SizedBox(height: 32),
            _buildSaveButton(isSaving),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow(opacity: 0.04),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRailItem(0, Icons.settings_rounded, 'Sistema y Ratio'),
          _buildRailItem(1, Icons.sports_esports_rounded, 'Límites Diarios'),
          _buildRailItem(2, Icons.redeem_rounded, 'Premios y Juegos'),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemTab(bool isSaving) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              title: 'Sistema de Puntos y Canjes',
              subtitle: 'Define el valor monetario y la acumulación.',
              icon: Icons.currency_exchange_rounded,
              color: Colors.blue,
              children: [
                isWide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildField(
                            _earningRateKey,
                            disabled: isSaving,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildField(
                            _pointsRatioKey,
                            disabled: isSaving,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        _buildField(_earningRateKey, disabled: isSaving),
                        const SizedBox(height: 12),
                        _buildField(_pointsRatioKey, disabled: isSaving),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Check-in Diario',
              subtitle: 'Recompensas por rachas consecutivas.',
              icon: Icons.fact_check_rounded,
              color: Colors.green,
              children: [
                isWide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildField(
                            _checkinRewardKey,
                            disabled: isSaving,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildField(
                            _checkinStreakStepKey,
                            disabled: isSaving,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        _buildField(_checkinRewardKey, disabled: isSaving),
                        const SizedBox(height: 12),
                        _buildField(_checkinStreakStepKey, disabled: isSaving),
                      ],
                    ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLimitsTab(bool isSaving) {
    return _buildSectionCard(
      title: 'Límites de Juegos Diarios',
      subtitle:
          'Controla el máximo de veces que los usuarios pueden jugar cada día.',
      icon: Icons.sports_esports_rounded,
      color: Colors.orange,
      children: [
        _buildResponsiveGrid([
          _boxesDailyLimitKey,
          _memoramaDailyLimitKey,
          _catcherDailyLimitKey,
          _pinataDailyLimitKey,
          _jumpDailyLimitKey,
          _clawDailyLimitKey,
          _stackDailyLimitKey,
          _dodgeDailyLimitKey,
        ], isSaving: isSaving),
      ],
    );
  }

  Widget _buildPrizesTab(bool isSaving) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Cajitas Misteriosas',
          subtitle: 'Premios aleatorios de las cajas.',
          icon: Icons.inventory_2_rounded,
          color: Colors.purple,
          children: [
            _buildResponsiveGrid([
              _boxesPrize1Key,
              _boxesPrize2Key,
              _boxesPrize3Key,
            ], isSaving: isSaving),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'Piñata y Memorama',
          subtitle: 'Premios mayores, consolación y por pares.',
          icon: Icons.celebration_rounded,
          color: Colors.pink,
          children: [
            _buildResponsiveGrid([
              _pinataGrandPrizeKey,
              _pinataConsolationPrizeKey,
              _memoramaMatchRewardKey,
            ], isSaving: isSaving),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'Lluvia de Monedas',
          subtitle: 'Valor por atrapar elementos.',
          icon: Icons.cloud_download_rounded,
          color: Colors.lightBlue,
          children: [
            _buildResponsiveGrid(
              [
                _catcherCoinRewardKey,
                _catcherGiftRewardKey,
                _catcherBombPenaltyKey,
              ],
              isSaving: isSaving,
              allowNegativeKeys: {_catcherBombPenaltyKey},
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'Máquina de Garra',
          subtitle: 'Premios según la ranura donde cae el gancho (1 al 5).',
          icon: Icons.precision_manufacturing_rounded,
          color: Colors.amber,
          children: [
            _buildResponsiveGrid([
              _clawPrize1Key,
              _clawPrize2Key,
              _clawPrize3Key,
              _clawPrize4Key,
              _clawPrize5Key,
            ], isSaving: isSaving),
          ],
        ),
      ],
    );
  }

  /// Grid responsivo seguro: 2 columnas en ancho ≥ 560px, 1 columna en móvil estrecho.
  Widget _buildResponsiveGrid(
    List<String> keys, {
    required bool isSaving,
    Set<String> allowNegativeKeys = const {},
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;

        if (!isWide) {
          // En móvil, siempre 1 columna — nunca forzar 3 en 412px
          return Column(
            children: [
              for (int i = 0; i < keys.length; i++) ...[
                _buildField(
                  keys[i],
                  disabled: isSaving,
                  allowNegative: allowNegativeKeys.contains(keys[i]),
                ),
                if (i < keys.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        // Tablet/Desktop: 2 columnas
        final rows = <Widget>[];
        for (int i = 0; i < keys.length; i += 2) {
          final left = _buildField(
            keys[i],
            disabled: isSaving,
            allowNegative: allowNegativeKeys.contains(keys[i]),
          );
          Widget right;
          if (i + 1 < keys.length) {
            right = _buildField(
              keys[i + 1],
              disabled: isSaving,
              allowNegative: allowNegativeKeys.contains(keys[i + 1]),
            );
          } else {
            right = const SizedBox.shrink();
          }

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            ),
          );
          if (i + 2 < keys.length) rows.add(const SizedBox(height: 12));
        }

        return Column(children: rows);
      },
    );
  }

  List<String> _getKeysForTab(int tabIndex) {
    if (tabIndex == 0) {
      return [
        _earningRateKey,
        _pointsRatioKey,
        _checkinRewardKey,
        _checkinStreakStepKey,
      ];
    } else if (tabIndex == 1) {
      return [
        _boxesDailyLimitKey,
        _memoramaDailyLimitKey,
        _catcherDailyLimitKey,
        _pinataDailyLimitKey,
        _jumpDailyLimitKey,
        _clawDailyLimitKey,
        _stackDailyLimitKey,
        _dodgeDailyLimitKey,
      ];
    } else {
      return [
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
    }
  }

  Future<void> _saveSection(int tabIndex, List<String> keys) async {
    final formKey = _formsKeys[tabIndex];
    if (formKey == null || !formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Corrige los errores antes de guardar.',
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

    await context.read<AppConfigCubit>().saveMultipleValues(
      newValues,
      descriptions: descriptions,
    );
  }

  Widget _buildSaveButton(bool isSaving) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 220,
        child: AppPrimaryButton(
          label: isSaving ? 'Guardando...' : 'Guardar Cambios',
          loading: isSaving,
          icon: const Icon(Icons.save_rounded, size: 18),
          onPressed:
              isSaving
                  ? null
                  : () => _saveSection(
                    _selectedIndex,
                    _getKeysForTab(_selectedIndex),
                  ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    String key, {
    bool allowNegative = false,
    bool disabled = false,
  }) {
    final def = _settings[key]!;

    Widget? prefix;
    Widget? suffix;

    // Formateador estricto: solo dígitos, punto decimal y signo negativo si aplica
    final inputFormatters = [
      FilteringTextInputFormatter.allow(
        allowNegative ? RegExp(r'^-?\d*\.?\d*') : RegExp(r'\d*\.?\d*'),
      ),
    ];

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
      enabled: !disabled,
      keyboardType: kType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: disabled ? Colors.grey : null,
      ),
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
        fillColor: disabled ? Colors.grey.shade100 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        disabledBorder: OutlineInputBorder(
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
