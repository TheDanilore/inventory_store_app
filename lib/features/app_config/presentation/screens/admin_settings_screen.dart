import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/change_connection_dialog.dart';
import 'package:inventory_store_app/core/services/barcode_scanner_hardware_service.dart';
import 'package:inventory_store_app/core/services/pos_printer_settings_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/currencies_settings_tab.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/account_form_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/scanner_settings_hub_tab.dart';

/// Pantalla completa de Configuración del ERP (Linear / Apple HIG Style)
/// Totalmente configurable e interactiva (Vibración, Sonido, Impresora POS, Puntos, Monedas, Empresa).
class AdminSettingsScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminSettingsScreen({super.key, this.initialTabIndex = 0});

  static void open(BuildContext context, {int tabIndex = 0}) {
    context.go('/settings?tab=$tabIndex');
  }

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _printerFooterCtrl = TextEditingController();
  bool _isPrintingTestTicket = false;
  bool _isSavingLoyalty = false;

  // ── Controladores de la Empresa ──────────────────────────────────────────
  final TextEditingController _businessNameCtrl = TextEditingController();
  final TextEditingController _taxIdCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _logoUrlCtrl = TextEditingController();

  bool _hasBusinessChanges = false;
  bool _isUploadingLogo = false;
  bool _isSavingBusiness = false;
  bool _showManualLogoUrl = false;
  bool _isBusinessPopulated = false;

  static const _tabs = [
    _TabSpec(
      title: 'Empresa',
      subtitle: 'Datos comerciales',
      icon: Icons.storefront_rounded,
    ),
    _TabSpec(
      title: 'Monedas',
      subtitle: 'Divisas y tipo de cambio',
      icon: Icons.currency_exchange_rounded,
    ),
    _TabSpec(
      title: 'Apariencia',
      subtitle: 'Tema e interacción',
      icon: Icons.palette_outlined,
    ),
    _TabSpec(
      title: 'Cuentas',
      subtitle: 'Cajas y bancos',
      icon: Icons.account_balance_rounded,
    ),
    _TabSpec(
      title: 'Puntos',
      subtitle: 'Fidelización',
      icon: Icons.card_giftcard_rounded,
    ),
    _TabSpec(
      title: 'Impresora POS',
      subtitle: 'Tickets térmicos',
      icon: Icons.print_rounded,
    ),
    _TabSpec(
      title: 'Lectores y Escáneres',
      subtitle: 'Pistolas USB / BT',
      icon: Icons.qr_code_scanner_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Inicializar servicios de hardware y preferencias
    BarcodeScannerHardwareService.init();
    PosPrinterSettingsService.init().then((_) {
      if (mounted) {
        _printerFooterCtrl.text =
            PosPrinterSettingsService.footerMessageNotifier.value;
      }
    });

    final cubit = context.read<AppConfigCubit>();
    if (cubit.state.businessInfo == null) {
      cubit.loadBusinessInfo();
    } else {
      _populateBusinessFields(cubit.state.businessInfo!);
    }
    if (cubit.state.connectionUrl == null) {
      cubit.loadConnectionUrl();
    }
  }

  void _populateBusinessFields(BusinessInfoEntity info) {
    if (_hasBusinessChanges) return;
    _businessNameCtrl.text =
        info.businessName == 'Sin configurar' ? '' : info.businessName;
    _taxIdCtrl.text = info.taxId;
    _addressCtrl.text = info.address;
    _phoneCtrl.text = info.phone;
    _logoUrlCtrl.text = info.logoUrl;
    _isBusinessPopulated = true;
  }

  Future<void> _pickLogoImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() => _isUploadingLogo = true);
      final bytes = await pickedFile.readAsBytes();

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 500,
        minHeight: 500,
        quality: 85,
        format: CompressFormat.webp,
      );

      if (!mounted) return;
      final cubit = context.read<AppConfigCubit>();
      final url = await cubit.uploadBusinessLogo(compressed);
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);

      if (url != null) {
        setState(() {
          _logoUrlCtrl.text = url;
          _hasBusinessChanges = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Logotipo cargado. Recuerda presionar "Guardar Cambios".',
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir el logotipo a la nube.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo procesar la imagen seleccionada.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _saveBusinessInfo() async {
    final name = _businessNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de la empresa no puede estar vacío.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSavingBusiness = true);
    final cubit = context.read<AppConfigCubit>();
    final current = cubit.state.businessInfo;

    final success = await cubit.saveBusinessInfo(
      businessName: name,
      taxId: _taxIdCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      loyaltyGlobalEnabled: current?.loyaltyGlobalEnabled ?? false,
      loyaltyCustomerVisible: current?.loyaltyCustomerVisible ?? false,
    );

    if (!mounted) return;
    setState(() {
      _isSavingBusiness = false;
      if (success) _hasBusinessChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Información de la empresa guardada exitosamente.'
              : 'Error al guardar los datos de la empresa.',
        ),
        backgroundColor: success ? const Color(0xFF10B981) : AppColors.danger,
      ),
    );
  }

  void _discardBusinessChanges(BusinessInfoEntity? info) {
    if (info != null) {
      setState(() {
        _hasBusinessChanges = false;
        _populateBusinessFields(info);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios descartados.'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant AdminSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final target = widget.initialTabIndex.clamp(0, _tabs.length - 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _printerFooterCtrl.dispose();
    _businessNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminLayout(
      title: 'Configuraciones',
      breadcrumb: 'Configuración > Sistema',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Container(
            color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero Banner Header ──────────────────────────────
                    _buildHeroHeader(context, isDark, isDesktop),

                    // ── Segmented Navigation Bar ────────────────────────
                    _buildSegmentedTabBar(context, isDark),

                    // ── Content Area ────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBusinessView(context, isDark),
                          CurrenciesSettingsTab(isDark: isDark),
                          _buildAppearanceView(context, isDark),
                          _buildFinancialAccountsView(context, isDark),
                          _buildLoyaltyPointsView(context, isDark),
                          _buildPrinterView(context, isDark),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: ScannerSettingsHubTab(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Hero Header ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configuraciones del Sistema',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Parámetros operacionales, identidad corporativa, apariencia y hardware de venta',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11.5,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ERP Operativo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Segmented Tab Bar ─────────────────────────────────────────────────────
  Widget _buildSegmentedTabBar(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs:
            _tabs.map((tab) {
              return Tab(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 17),
                      const SizedBox(width: 8),
                      Text(tab.title),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // ── Tab 0: Empresa & Negocio (Totalmente Configurable) ────────────────────
  Widget _buildBusinessView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (blocCtx, state) {
        final info = state.businessInfo;
        if (!_isBusinessPopulated && info != null) {
          _populateBusinessFields(info);
        }

        final logoUrl = _logoUrlCtrl.text.trim();
        final supabaseUrl = state.connectionUrl ?? 'https://*.supabase.co';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Card 1: Identidad de Marca y Logotipo Comercial ─────────────
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.storefront_rounded,
              title: 'Identidad de Marca & Logotipo Comercial',
              subtitle:
                  'Logotipo oficial impreso en tickets POS, comprobantes electrónicos y catálogo',
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Preview del Logotipo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              logoUrl.isNotEmpty
                                  ? Image.network(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (c, e, s) => const Icon(
                                          Icons.broken_image_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 28,
                                        ),
                                  )
                                  : const Icon(
                                    Icons.business_rounded,
                                    color: Color(0xFF3B82F6),
                                    size: 32,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Textos y Acciones
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Logotipo Oficial de la Empresa',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Formato recomendado: PNG o WebP con fondo transparente.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                FilledButton.tonalIcon(
                                  icon:
                                      _isUploadingLogo
                                          ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.upload_rounded,
                                            size: 16,
                                          ),
                                  label: Text(
                                    _isUploadingLogo
                                        ? 'Subiendo...'
                                        : 'Subir Nuevo Logo',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed:
                                      _isUploadingLogo ? null : _pickLogoImage,
                                ),
                                TextButton.icon(
                                  icon: Icon(
                                    _showManualLogoUrl
                                        ? Icons.expand_less_rounded
                                        : Icons.link_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _showManualLogoUrl
                                        ? 'Ocultar URL'
                                        : 'URL pública manual',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _showManualLogoUrl =
                                              !_showManualLogoUrl,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showManualLogoUrl) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _logoUrlCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              hintText: 'https://ejemplo.com/logo.png',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() => _hasBusinessChanges = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Previsualizar',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Card 2: Datos Comerciales y Fiscales ─────────────────────────
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.business_center_rounded,
              title: 'Datos Fiscales y Comerciales del Negocio',
              subtitle:
                  'Información oficial para boletas, facturas electrónicas, tickets y catálogo',
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 650;

                    if (isDesktop) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'Nombre Comercial / Razón Social',
                                  hint: 'Ej: DANILORE STORE',
                                  icon: Icons.storefront_rounded,
                                  controller: _businessNameCtrl,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'RUC / Identificador Fiscal (Tax ID)',
                                  hint: 'Ej: 10751565149 (11 dígitos)',
                                  icon: Icons.badge_outlined,
                                  controller: _taxIdCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label:
                                      'Dirección Comercial / Almacén Central',
                                  hint: 'Ej: Av. Principal 123, Lima',
                                  icon: Icons.location_on_outlined,
                                  controller: _addressCtrl,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'Teléfono o WhatsApp Comercial',
                                  hint: 'Ej: 936081881',
                                  icon: Icons.phone_outlined,
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    // Mobile Single Column
                    return Column(
                      children: [
                        _buildBusinessInputField(
                          context: context,
                          isDark: isDark,
                          label: 'Nombre Comercial / Razón Social',
                          hint: 'Ej: DANILORE STORE',
                          icon: Icons.storefront_rounded,
                          controller: _businessNameCtrl,
                        ),
                        const SizedBox(height: 12),
                        _buildBusinessInputField(
                          context: context,
                          isDark: isDark,
                          label: 'RUC / Identificador Fiscal (Tax ID)',
                          hint: 'Ej: 10751565149 (11 dígitos)',
                          icon: Icons.badge_outlined,
                          controller: _taxIdCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBusinessInputField(
                          context: context,
                          isDark: isDark,
                          label: 'Dirección Comercial / Almacén Central',
                          hint: 'Ej: Av. Principal 123, Lima',
                          icon: Icons.location_on_outlined,
                          controller: _addressCtrl,
                        ),
                        const SizedBox(height: 12),
                        _buildBusinessInputField(
                          context: context,
                          isDark: isDark,
                          label: 'Teléfono o WhatsApp Comercial',
                          hint: 'Ej: 936081881',
                          icon: Icons.phone_outlined,
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Barra de Guardado y Estado de Cambios
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        _hasBusinessChanges
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                            : (isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _hasBusinessChanges
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                              : (isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasBusinessChanges
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color:
                            _hasBusinessChanges
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasBusinessChanges
                              ? 'Tienes modificaciones pendientes sin guardar.'
                              : 'Datos fiscales sincronizados correctamente con Supabase.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                _hasBusinessChanges
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                _hasBusinessChanges
                                    ? (isDark
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFFB45309))
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_hasBusinessChanges) ...[
                        TextButton(
                          onPressed: () => _discardBusinessChanges(info),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Descartar'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        icon:
                            _isSavingBusiness
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.save_rounded, size: 16),
                        label: Text(
                          _isSavingBusiness
                              ? 'Guardando...'
                              : 'Guardar Cambios',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSavingBusiness ? null : _saveBusinessInfo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Card 3: Infraestructura Cloud & Multi-Tenant ────────────────
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.cloud_done_rounded,
              title: 'Infraestructura de Datos & Nube',
              subtitle: 'Conexión activa con el backend Supabase Multi-Tenant',
              action: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Cambiar Servidor (Multi-Tenant)'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  ChangeConnectionDialog.show(context, supabaseUrl);
                },
              ),
              children: [
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.cloud_done_rounded,
                  title: 'Base de Datos Cloud',
                  value: 'Supabase PostgreSQL con RLS Activo ($supabaseUrl)',
                  badge: 'Conectado',
                  badgeColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessInputField({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onChanged: (_) {
            if (!_hasBusinessChanges) {
              setState(() => _hasBusinessChanges = true);
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              icon,
              size: 19,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color:
                    isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Apariencia & Interacción ───────────────────────────────────────
  Widget _buildAppearanceView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Tema visual ──
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.palette_outlined,
          title: 'Tema y Paleta Visual',
          subtitle:
              'Personaliza la interfaz de usuario en toda la plataforma ERP',
          children: [
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, currentMode) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;

                    final options = [
                      _ThemeOptionItem(
                        mode: ThemeMode.light,
                        title: 'Claro Ejecutivo',
                        subtitle: 'Estilo Apple / Linear HIG',
                        icon: Icons.light_mode_rounded,
                        isSelected: currentMode == ThemeMode.light,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.dark,
                        title: 'Oscuro Midnight',
                        subtitle: 'Slate Navy (#0B0F19)',
                        icon: Icons.dark_mode_rounded,
                        isSelected: currentMode == ThemeMode.dark,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.system,
                        title: 'Automático',
                        subtitle: 'Sincronizado con el SO',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: currentMode == ThemeMode.system,
                      ),
                    ];

                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      children:
                          options.map((opt) {
                            final card = InkWell(
                              onTap: () {
                                context.read<ThemeCubit>().setThemeMode(
                                  opt.mode,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      opt.isSelected
                                          ? (isDark
                                              ? const Color(
                                                0xFF1E3A8A,
                                              ).withValues(alpha: 0.35)
                                              : const Color(0xFFEFF6FF))
                                          : (isDark
                                              ? const Color(0xFF111827)
                                              : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        opt.isSelected
                                            ? const Color(0xFF3B82F6)
                                            : (isDark
                                                ? AppColors.darkBorderSubtle
                                                : const Color(0xFFE2E8F0)),
                                    width: opt.isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      opt.icon,
                                      size: 22,
                                      color:
                                          opt.isSelected
                                              ? const Color(0xFF3B82F6)
                                              : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  opt.isSelected
                                                      ? (isDark
                                                          ? const Color(
                                                            0xFF93C5FD,
                                                          )
                                                          : const Color(
                                                            0xFF1E40AF,
                                                          ))
                                                      : (isDark
                                                          ? AppColors
                                                              .darkTextPrimary
                                                          : const Color(
                                                            0xFF0F172A,
                                                          )),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            opt.subtitle,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  isDark
                                                      ? AppColors.darkTextMuted
                                                      : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (opt.isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: Color(0xFF3B82F6),
                                      ),
                                  ],
                                ),
                              ),
                            );

                            if (isWide) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: card,
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: card,
                            );
                          }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Preferencias de Interacción (Vibración y Sonido interactivos) ──
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Preferencias de Interacción y Hardware',
          subtitle:
              'Configura y prueba la vibración, sonidos de confirmación y atajos de teclado',
          children: [
            // Switch 1: Vibración / Feedback Háptico
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.hapticNotifier,
              builder: (context, isHapticEnabled, _) {
                return _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.vibration_rounded,
                  title: 'Feedback Háptico (Vibración)',
                  subtitle:
                      'Vibración táctil al escanear productos, presionar botones clave y cobrar.',
                  value: isHapticEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setHapticFeedback(val);
                    if (val) {
                      HapticFeedback.mediumImpact();
                    }
                  },
                  trailingAction:
                      isHapticEnabled
                          ? TextButton.icon(
                            icon: const Icon(Icons.touch_app_rounded, size: 14),
                            label: const Text(
                              'Probar',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF2563EB),
                            ),
                            onPressed: () => HapticFeedback.heavyImpact(),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Switch 2: Sonido / Bip de Escaneo y Ventas
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.soundBeepNotifier,
              builder: (context, isSoundEnabled, _) {
                return _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.volume_up_rounded,
                  title: 'Sonido y Bip de Confirmación',
                  subtitle:
                      'Emite un sonido auditivo al leer códigos de barras o registrar ventas con éxito.',
                  value: isSoundEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setSoundBeep(val);
                    if (val) {
                      SystemSound.play(SystemSoundType.click);
                    }
                  },
                  trailingAction:
                      isSoundEnabled
                          ? TextButton.icon(
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Probar Sonido',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF10B981),
                            ),
                            onPressed:
                                () => SystemSound.play(SystemSoundType.click),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Item 3: Atajos de Teclado con Modal Informativo
            _buildInteractiveActionTile(
              context,
              isDark: isDark,
              icon: Icons.keyboard_rounded,
              title: 'Atajos Globales de Teclado',
              subtitle:
                  '⌘K / Ctrl+K búsqueda rápida · F2 Cobro POS · Alt+B Guardar borrador',
              actionLabel: 'Ver todos los atajos',
              onActionPressed: () => _showKeyboardShortcutsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 3: Cuentas Financieras ────────────────────────────────────────────
  // ── Tab 3: Cuentas Financieras (Conectada a Datos Reales) ────────────────
  Widget _buildFinancialAccountsView(BuildContext context, bool isDark) {
    return BlocProvider(
      create: (_) => sl<FinancialAccountsCubit>()..fetchAccounts(),
      child: Builder(
        builder: (fContext) {
          return BlocConsumer<FinancialAccountsCubit, FinancialAccountsState>(
            listener: (context, state) {
              if (state is FinancialAccountSaveError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.danger,
                  ),
                );
              } else if (state is FinancialAccountSaved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta financiera guardada correctamente.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            builder: (context, state) {
              List<FinancialAccountEntity> accounts = [];
              bool isLoading = state is FinancialAccountsLoading;

              if (state is FinancialAccountsLoaded) {
                accounts = state.accounts;
              } else if (state is FinancialAccountSaving) {
                accounts = state.previousAccounts;
              } else if (state is FinancialAccountSaved) {
                accounts = state.accounts;
              } else if (state is FinancialAccountSaveError) {
                accounts = state.previousAccounts;
              }

              final activeAccounts = accounts.where((a) => a.isActive).toList();
              final totalPenBalance = activeAccounts
                  .where((a) => a.currencyCode.toUpperCase() == 'PEN')
                  .fold<double>(0.0, (sum, a) => sum + a.balance);
              final totalUsdBalance = activeAccounts
                  .where((a) => a.currencyCode.toUpperCase() == 'USD')
                  .fold<double>(0.0, (sum, a) => sum + a.balance);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Sección 1: Cuentas y Cajas Registradas ────────────────
                  _buildSectionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Cuentas Financieras & Cajas Receptoras',
                    subtitle:
                        'Administra las cuentas bancarias, billeteras móviles y cajas de cobro para el POS y compras',
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go('/financial-accounts'),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: const Text('Ver Tesorería'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                            side: BorderSide(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFCBD5E1),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final saved = await AccountFormSheet.show(context);
                            if (saved == true && context.mounted) {
                              context
                                  .read<FinancialAccountsCubit>()
                                  .fetchAccounts();
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('Nueva Cuenta'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Bento KPIs de Tesorería
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoKpiCard(
                              context,
                              isDark: isDark,
                              label: 'Cuentas Activas',
                              value:
                                  '${activeAccounts.length} / ${accounts.length}',
                              icon: Icons.account_balance_rounded,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildBentoKpiCard(
                              context,
                              isDark: isDark,
                              label: 'Saldo Total Soles',
                              value:
                                  'S/ ${NumberFormat('#,##0.00', 'es_PE').format(totalPenBalance)}',
                              icon: Icons.monetization_on_rounded,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          if (totalUsdBalance > 0) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildBentoKpiCard(
                                context,
                                isDark: isDark,
                                label: 'Saldo Total Dólares',
                                value:
                                    '\$ ${NumberFormat('#,##0.00', 'en_US').format(totalUsdBalance)}',
                                icon: Icons.currency_exchange_rounded,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lista de Cuentas Reales
                      if (isLoading && accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        )
                      else if (accounts.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkSurfaceElevated
                                    : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.darkBorderSubtle
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 40,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay cuentas financieras configuradas',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? AppColors.darkTextPrimary
                                            : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Crea tu primera caja física, cuenta bancaria (BCP, BBVA) o billetera móvil (Yape/Plin).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () async {
                                    final saved = await AccountFormSheet.show(
                                      context,
                                    );
                                    if (saved == true && context.mounted) {
                                      context
                                          .read<FinancialAccountsCubit>()
                                          .fetchAccounts();
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Crear Primera Cuenta'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (int i = 0; i < accounts.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _buildFinancialAccountRowItem(
                                context,
                                account: accounts[i],
                                isDark: isDark,
                                onEdit: () async {
                                  final saved = await AccountFormSheet.show(
                                    context,
                                    account: accounts[i],
                                  );
                                  if (saved == true && context.mounted) {
                                    context
                                        .read<FinancialAccountsCubit>()
                                        .fetchAccounts();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Sección 2: Configuración de Moneda y Parámetros Contables ─
                  _buildSectionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.currency_exchange_rounded,
                    title: 'Parámetros Operacionales & Métodos de Pago',
                    subtitle:
                        'Directrices de cobro para el Punto de Venta (POS) y conciliación contable',
                    children: [
                      _buildInfoTile(
                        context,
                        isDark: isDark,
                        icon: Icons.payments_rounded,
                        title: 'Métodos de Pago Habilitados en Caja',
                        value:
                            accounts.isEmpty
                                ? 'Pendiente de registrar cuentas'
                                : accounts
                                        .map((a) => a.name)
                                        .take(5)
                                        .join(' · ') +
                                    (accounts.length > 5 ? ' y más...' : ''),
                        badge: '${accounts.length} Cuentas',
                        badgeColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoTile(
                        context,
                        isDark: isDark,
                        icon: Icons.monetization_on_outlined,
                        title: 'Moneda Base Predeterminada',
                        value:
                            'Soles Peruanos (PEN - S/) con soporte Multimoneda',
                        badge: 'PEN',
                        badgeColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoTile(
                        context,
                        isDark: isDark,
                        icon: Icons.point_of_sale_rounded,
                        title: 'Control de Turnos de Caja (Shifts)',
                        value:
                            'Apertura con saldo inicial, registro de ingresos/egresos y arqueo ciego al cierre.',
                        badge: 'Activo',
                        badgeColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFinancialAccountRowItem(
    BuildContext context, {
    required FinancialAccountEntity account,
    required bool isDark,
    required VoidCallback onEdit,
  }) {
    final currencySymbol = FinancialBrandHelper.formatCurrencySymbol(
      account.currencyCode,
    );
    final isPen = account.currencyCode.toUpperCase() == 'PEN';
    final formattedBalance =
        '$currencySymbol ${NumberFormat('#,##0.00', isPen ? 'es_PE' : 'en_US').format(account.balance)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo / Avatar de la marca financiera
          FinancialBrandHelper.buildBrandBadge(
            name: account.name,
            type: account.type,
            size: 38,
          ),
          const SizedBox(width: 14),

          // Detalles de la cuenta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        account.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Moneda: ${account.currencyCode}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('·', style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            account.isActive
                                ? const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.12)
                                : const Color(
                                  0xFF64748B,
                                ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account.isActive ? 'ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color:
                              account.isActive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Saldo de la Cuenta
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedBalance,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Saldo Contable',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Botón Editar
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Editar cuenta',
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildBentoKpiCard(
    BuildContext context, {
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Puntos & Fidelización (Totalmente Configurable) ─────────────────
  Widget _buildLoyaltyPointsView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (blocCtx, state) {
        final isGlobalEnabled =
            state.businessInfo?.loyaltyGlobalEnabled ?? false;
        final isCustomerVisible =
            state.businessInfo?.loyaltyCustomerVisible ?? false;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.card_giftcard_rounded,
              title: 'Programa de Fidelización y Puntos',
              subtitle:
                  'Activa o desactiva la acumulación de puntos por compras y su visualización para clientes',
              action: FilledButton.icon(
                onPressed:
                    isGlobalEnabled
                        ? () => context.go('/points-settings')
                        : null,
                icon: const Icon(Icons.stars_rounded, size: 16),
                label: const Text('Reglas Avanzadas de Puntos'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isGlobalEnabled
                          ? const Color(0xFF2563EB)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                  disabledForegroundColor:
                      isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              children: [
                // Callout Banner de Estado de Puntos
                if (!isGlobalEnabled)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF2D2010)
                              : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF78350F)
                                : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo de Puntos Desactivado',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Para acceder a la vista de reglas avanzadas, acumulación y juegos interactivos, primero debes activar el interruptor principal abajo.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF062A1B)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF047857)
                                : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo de Fidelización Activo en ERP y POS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'La vista de reglas avanzadas está habilitada para configurar tasas de canje, acumulación por compras y juegos.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => context.go('/points-settings'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFF047857),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Abrir Reglas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Switch 1: Habilitar Globalmente
                _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.power_settings_new_rounded,
                  title: 'Habilitar Sistema de Puntos Globalmente',
                  subtitle:
                      'Permite acumular y canjear puntos en ventas del POS. Si se apaga, desaparece de toda la app y se desactiva el acceso a las reglas de puntos.',
                  value: isGlobalEnabled,
                  isLoading: _isSavingLoyalty,
                  badgeText: isGlobalEnabled ? 'ACTIVO' : 'DESACTIVADO',
                  badgeColor:
                      isGlobalEnabled
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                  onChanged: (val) async {
                    setState(() => _isSavingLoyalty = true);
                    final success = await context
                        .read<AppConfigCubit>()
                        .updateLoyaltySettings(
                          loyaltyGlobalEnabled: val,
                          loyaltyCustomerVisible:
                              val ? isCustomerVisible : false,
                        );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (val
                                  ? 'Módulo de Puntos activado. Ya puedes acceder a las reglas avanzadas.'
                                  : 'Módulo de Puntos desactivado globalmente.')
                              : 'Error al actualizar el estado de puntos',
                        ),
                        backgroundColor:
                            success
                                ? const Color(0xFF10B981)
                                : AppColors.danger,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Switch 2: Visibilidad para Clientes
                _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.visibility_outlined,
                  title: 'Visible para Clientes en el Catálogo Web/Móvil',
                  subtitle:
                      'Muestra a los clientes su saldo de puntos y equivalencia en soles en su perfil y catálogo.',
                  value: isCustomerVisible,
                  isEnabled: isGlobalEnabled,
                  badgeText: isCustomerVisible ? 'VISIBLE' : 'OCULTO',
                  badgeColor:
                      isCustomerVisible
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                  onChanged: (val) async {
                    if (!isGlobalEnabled) return;
                    setState(() => _isSavingLoyalty = true);
                    final success = await context
                        .read<AppConfigCubit>()
                        .updateLoyaltySettings(
                          loyaltyGlobalEnabled: true,
                          loyaltyCustomerVisible: val,
                        );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (val
                                  ? 'Saldo de puntos ahora visible para clientes'
                                  : 'Saldo de puntos oculto para clientes')
                              : 'Error al guardar la visibilidad de puntos',
                        ),
                        backgroundColor:
                            success
                                ? const Color(0xFF10B981)
                                : AppColors.danger,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Resumen de Regla
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isGlobalEnabled
                              ? 'El sistema está otorgando 1 Punto por cada S/ 10 de compra. 100 Puntos equivalen a S/ 1.00 de descuento en caja.'
                              : 'El módulo está actualmente apagado. No se generan ni descuentan puntos durante las operaciones de venta, y la vista de reglas se encuentra bloqueada.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Tab 5: Impresora POS (Totalmente Configurable) ─────────────────────────
  Widget _buildPrinterView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final businessName = info?.businessName ?? 'DANILORE ONE ERP';
        final taxId = info?.taxId ?? '10751565149';
        final address = info?.address ?? 'Virtual';
        final phone = info?.phone ?? '';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.print_rounded,
              title: 'Configuración de Impresión Térmica POS',
              subtitle:
                  'Ajusta el ancho de papel, disparo automático de tickets y realiza pruebas de corte y texto',
              children: [
                // 1. Selector de Ancho de Papel
                ValueListenableBuilder<String>(
                  valueListenable: PosPrinterSettingsService.paperWidthNotifier,
                  builder: (context, currentWidth, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ancho del Rollo de Papel Térmico',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentWidth,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaperWidthOption(
                                  width: '80mm',
                                  label: '80 mm (Estándar POS)',
                                  desc:
                                      'Ticketeras fijas USB/Red (Epson, Bixolon, Xprinter)',
                                  isSelected: currentWidth == '80mm',
                                  isDark: isDark,
                                  onTap:
                                      () =>
                                          PosPrinterSettingsService.setPaperWidth(
                                            '80mm',
                                          ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildPaperWidthOption(
                                  width: '58mm',
                                  label: '58 mm (Compacto)',
                                  desc:
                                      'Ticketeras móviles Bluetooth y terminales portátiles',
                                  isSelected: currentWidth == '58mm',
                                  isDark: isDark,
                                  onTap:
                                      () =>
                                          PosPrinterSettingsService.setPaperWidth(
                                            '58mm',
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Impresión Automática al Cobrar
                ValueListenableBuilder<bool>(
                  valueListenable: PosPrinterSettingsService.autoPrintNotifier,
                  builder: (context, autoPrint, _) {
                    return _buildInteractiveSwitchTile(
                      context,
                      isDark: isDark,
                      icon: Icons.auto_mode_rounded,
                      title: 'Impresión Automática al Cobrar',
                      subtitle:
                          'Abre el cuadro de diálogo de impresión automáticamente al completar una venta en el POS.',
                      value: autoPrint,
                      onChanged: (val) {
                        PosPrinterSettingsService.setAutoPrint(val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Cantidad de Copias
                ValueListenableBuilder<int>(
                  valueListenable: PosPrinterSettingsService.copiesNotifier,
                  builder: (context, copies, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copias del Comprobante',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '1 copia para el cliente, o 2 para control interno de almacén/cocina',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 Copia')),
                              ButtonSegment(value: 2, label: Text('2 Copias')),
                            ],
                            selected: {copies},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) {
                                PosPrinterSettingsService.setCopies(set.first);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Mensaje del Pie de Página del Ticket
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.short_text_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mensaje al Pie del Ticket',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _printerFooterCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Ej: ¡Gracias por su compra! Conserve su ticket para cualquier garantía.',
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Guardar Mensaje'),
                          onPressed: () async {
                            await PosPrinterSettingsService.setFooterMessage(
                              _printerFooterCtrl.text.trim(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pie de ticket actualizado correctamente',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Laboratorio de Calibración / Impresión de Prueba
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.print_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laboratorio de Calibración Térmica',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Envía un ticket de prueba para validar alineación, corte y nitidez.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon:
                            _isPrintingTestTicket
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          _isPrintingTestTicket
                              ? 'Enviando...'
                              : 'Imprimir Prueba',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed:
                            _isPrintingTestTicket
                                ? null
                                : () async {
                                  setState(() => _isPrintingTestTicket = true);
                                  final success =
                                      await PosPrinterSettingsService.printTestTicket(
                                        businessName: businessName,
                                        taxId: taxId,
                                        address: address,
                                        phone: phone,
                                      );
                                  if (!mounted) return;
                                  setState(() => _isPrintingTestTicket = false);
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Ticket de prueba enviado a la cola de impresión'
                                            : 'No se pudo generar el ticket de prueba',
                                      ),
                                      backgroundColor:
                                          success
                                              ? const Color(0xFF10B981)
                                              : AppColors.danger,
                                    ),
                                  );
                                },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaperWidthOption({
    required String width,
    required String label,
    required String desc,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color:
                      isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color:
                        isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets Responsive ─────────────────────────────────────────────
  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isNarrow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (action != null) ...[const SizedBox(width: 12), action],
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (action != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: action),
                ],
              ],
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color:
                    isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveSwitchTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isEnabled = true,
    bool isLoading = false,
    String? badgeText,
    Color? badgeColor,
    Widget? trailingAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                value && isEnabled
                    ? const Color(0xFF2563EB)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B)),
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isEnabled
                                  ? (isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A))
                                  : AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFF2563EB))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor ?? const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isEnabled
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B))
                            : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailingAction != null) ...[
            trailingAction,
            const SizedBox(width: 8),
          ],
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Switch.adaptive(
              value: value,
              activeTrackColor: const Color(0xFF2563EB),
              onChanged: isEnabled ? onChanged : null,
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveActionTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onActionPressed,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    required String badge,
    Color? badgeColor,
  }) {
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            size: 19,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: effectiveBadgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: effectiveBadgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: effectiveBadgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkSurfaceElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.keyboard_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text(
                  'Atajos Globales de Teclado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShortcutRow('⌘K / Ctrl+K', 'Búsqueda instantánea ERP'),
                  _buildShortcutRow(
                    'F2',
                    'Abrir cobro de venta en el POS (Checkout)',
                  ),
                  _buildShortcutRow(
                    'Alt + B',
                    'Guardar venta actual como borrador',
                  ),
                  _buildShortcutRow('⌘P / Ctrl+P', 'Reimprimir último ticket'),
                  _buildShortcutRow(
                    'F4',
                    'Enfocar buscador de productos con código de barras',
                  ),
                  _buildShortcutRow('Esc', 'Cerrar modales o cancelar diálogo'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Widget _buildShortcutRow(String keys, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TabSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _ThemeOptionItem {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _ThemeOptionItem({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });
}
