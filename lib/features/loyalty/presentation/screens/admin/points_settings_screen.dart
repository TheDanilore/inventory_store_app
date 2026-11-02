import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_disabled_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_limits_tab.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_prizes_tab.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_system_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 0;

  final Map<String, TextEditingController> _controllers = {};
  final Map<int, GlobalKey<FormState>> _formsKeys = {
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
      if (!_tabController.indexIsChanging &&
          _selectedIndex != _tabController.index) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });

    for (final def in LoyaltySettingsKeys.allDefinitions) {
      _controllers[def.key] = TextEditingController();
    }

    // Zero-Shimmer / Frame-0: Población síncrona si ya existe caché L1 en memoria
    final config = context.read<AppConfigCubit>();
    if (config.state.businessInfo == null) {
      config.loadBusinessInfo();
    }
    if (config.state.values.isNotEmpty) {
      _fillControllers(config);
      _isInitialized = true;
    } else {
      config.loadConfig();
    }
  }

  void _fillControllers(AppConfigCubit config) {
    for (final def in LoyaltySettingsKeys.allDefinitions) {
      double val = config.getDouble(def.key, def.fallback);
      if (def.format == SettingFormat.percent) {
        val = val * 100;
      }

      final String text =
          def.format == SettingFormat.integer
              ? val.toInt().toString()
              : val.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');

      _controllers[def.key]?.text = text;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
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
    final configs = {
      for (var c in LoyaltySettingsKeys.allDefinitions) c.key: c,
    };

    for (final key in keys) {
      final def = configs[key]!;
      final text = _controllers[key]?.text.trim() ?? '';
      double parsed = double.tryParse(text) ?? def.fallback;
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

  List<String> _getKeysForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return LoyaltySettingsKeys.systemKeys;
      case 1:
        return LoyaltySettingsKeys.limitsKeys;
      default:
        return LoyaltySettingsKeys.prizesKeys;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppConfigCubit, AppConfigState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.saveStatus != current.saveStatus,
      listener: (context, state) {
        if (state.status == ViewState.success && !_isInitialized) {
          _fillControllers(context.read<AppConfigCubit>());
          setState(() => _isInitialized = true);
        }
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
      buildWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.saveStatus != current.saveStatus ||
              previous.values != current.values ||
              previous.businessInfo?.loyaltyGlobalEnabled !=
                  current.businessInfo?.loyaltyGlobalEnabled,
      builder: (context, state) {
        final isSaving = state.saveStatus == ViewState.loading;
        final isColdLoading =
            (state.status == ViewState.initial ||
                state.status == ViewState.loading) &&
            state.values.isEmpty;
        final hasError =
            state.status == ViewState.error && state.values.isEmpty;
        final isLoyaltyEnabled =
            state.businessInfo?.loyaltyGlobalEnabled ?? true;

        if (state.businessInfo != null && !isLoyaltyEnabled) {
          return const AdminLayout(
            title: 'Reglas de Puntos y Juegos',
            showBackButton: true,
            body: PointsDisabledFullscreenState(),
          );
        }

        return AdminLayout(
          title: 'Configuración de Juegos',
          showBackButton: true,
          body:
              isColdLoading
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
        mainAxisSize: MainAxisSize.min,
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
    final isDisabled = !(state.businessInfo?.loyaltyGlobalEnabled ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDisabled) const PointsDisabledWarningBanner(),
        Expanded(
          child: AbsorbPointer(
            absorbing: isDisabled,
            child: Opacity(
              opacity: isDisabled ? 0.6 : 1.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    return _buildWideLayout(isSaving, isDisabled: isDisabled);
                  }
                  return _buildMobileLayout(isSaving, isDisabled: isDisabled);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(bool isSaving, {bool isDisabled = false}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 25, child: _buildNavigationRail()),
              const SizedBox(width: 32),
              Expanded(
                flex: 75,
                child: Form(
                  key: _formsKeys[_selectedIndex],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Builder(
                        builder: (_) {
                          final disabled = isSaving || isDisabled;
                          if (_selectedIndex == 0) {
                            return PointsSystemTab(
                              controllers: _controllers,
                              disabled: disabled,
                            );
                          }
                          if (_selectedIndex == 1) {
                            return PointsLimitsTab(
                              controllers: _controllers,
                              disabled: disabled,
                            );
                          }
                          return PointsPrizesTab(
                            controllers: _controllers,
                            disabled: disabled,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSaveButton(
                        isSaving,
                        isDisabled: isDisabled,
                        tabIndex: _selectedIndex,
                      ),
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

  Widget _buildMobileLayout(bool isSaving, {bool isDisabled = false}) {
    final disabled = isSaving || isDisabled;
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
              _buildTabScrollView(
                0,
                PointsSystemTab(controllers: _controllers, disabled: disabled),
                isSaving,
                isDisabled: isDisabled,
              ),
              _buildTabScrollView(
                1,
                PointsLimitsTab(controllers: _controllers, disabled: disabled),
                isSaving,
                isDisabled: isDisabled,
              ),
              _buildTabScrollView(
                2,
                PointsPrizesTab(controllers: _controllers, disabled: disabled),
                isSaving,
                isDisabled: isDisabled,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabScrollView(
    int index,
    Widget child,
    bool isSaving, {
    bool isDisabled = false,
  }) {
    return Form(
      key: _formsKeys[index],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            child,
            const SizedBox(height: 32),
            _buildSaveButton(isSaving, isDisabled: isDisabled, tabIndex: index),
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
        onTap: () => setState(() => _selectedIndex = index),
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

  Widget _buildSaveButton(
    bool isSaving, {
    bool isDisabled = false,
    required int tabIndex,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 220,
        child: AppPrimaryButton(
          label: isSaving ? 'Guardando...' : 'Guardar Cambios',
          loading: isSaving,
          icon: const Icon(Icons.save_rounded, size: 18),
          onPressed:
              (isSaving || isDisabled)
                  ? null
                  : () => _saveSection(tabIndex, _getKeysForTab(tabIndex)),
        ),
      ),
    );
  }
}
