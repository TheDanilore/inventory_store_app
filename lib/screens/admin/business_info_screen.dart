import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';

class BusinessInfoScreen extends StatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  // FocusNodes para cadena textInputAction y debounce del logo
  final _taxIdFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _logoUrlFocus = FocusNode();

  bool _isInitialized = false;
  bool _hasChanges = false;

  // Estado local para la preview reactiva (no depende del provider guardado)
  String _previewName = '';
  String _previewAddress = '';
  String _previewLogoUrl = '';

  @override
  void initState() {
    super.initState();
    // Actualiza la preview del logo solo al perder el foco (evita requests por cada tecla)
    _logoUrlFocus.addListener(() {
      if (!_logoUrlFocus.hasFocus) {
        setState(() => _previewLogoUrl = _logoUrlCtrl.text);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initControllers());
  }

  void _initControllers() {
    final config = context.read<AppConfigProvider>();
    if (config.businessName != 'Cargando...') {
      _loadValues(config);
    } else {
      config.addListener(_onConfigLoaded);
    }
  }

  void _loadValues(AppConfigProvider config) {
    _businessNameCtrl.text =
        config.businessName == 'Sin configurar' ? '' : config.businessName;
    _taxIdCtrl.text = config.businessTaxId;
    _addressCtrl.text = config.businessAddress;
    _phoneCtrl.text = config.businessPhone;
    _logoUrlCtrl.text = config.businessLogoUrl;
    setState(() {
      _isInitialized = true;
      _hasChanges = false;
      _previewName = _businessNameCtrl.text;
      _previewAddress = _addressCtrl.text;
      _previewLogoUrl = _logoUrlCtrl.text;
    });
  }

  void _onConfigLoaded() {
    final config = context.read<AppConfigProvider>();
    if (config.businessName != 'Cargando...') {
      config.removeListener(_onConfigLoaded);
      if (mounted) _loadValues(config);
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _logoUrlCtrl.dispose();
    _taxIdFocus.dispose();
    _addressFocus.dispose();
    _phoneFocus.dispose();
    _logoUrlFocus.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppConfigProvider>();
    final success = await provider.saveBusinessInfo(
      businessName: _businessNameCtrl.text,
      taxId: _taxIdCtrl.text,
      address: _addressCtrl.text,
      phone: _phoneCtrl.text,
      logoUrl: _logoUrlCtrl.text,
    );

    if (mounted) {
      if (success) {
        setState(() => _hasChanges = false);
        AppSnackbar.show(
          context,
          message: 'Información del negocio guardada.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar la información. Intente nuevamente.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return AdminLayout(
      title: 'Información del Negocio',
      showBackButton: true,
      // ── Botón sticky fuera del scroll, siempre visible ──────────────────────
      bottomNavigationBar:
          _isInitialized
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: AppPrimaryButton(
                      key: ValueKey(_hasChanges),
                      label: _hasChanges ? 'Guardar cambios' : 'Todo guardado',
                      // ── Fix bug: ahora sí pasa la prop loading correctamente ──
                      loading: config.isSavingBusinessInfo,
                      icon: Icon(
                        _hasChanges
                            ? Icons.save_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      backgroundColor:
                          _hasChanges ? null : Colors.grey.shade400,
                      onPressed:
                          (_hasChanges && !config.isSavingBusinessInfo)
                              ? _save
                              : null,
                    ),
                  ),
                ),
              )
              : null,
      body:
          !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : isTablet
              ? _buildTabletLayout()
              : _buildMobileLayout(),
    );
  }

  // ── Layout móvil: columna única ────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPreviewCard(),
          const SizedBox(height: 16),
          _buildFormCard(),
          const SizedBox(height: 12),
          _buildInfoNote(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Layout tablet: Master-Detail en 2 columnas ────────────────────────────
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: preview + nota
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildPreviewCard(),
                      const SizedBox(height: 16),
                      _buildInfoNote(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Columna derecha: formulario
                Expanded(flex: 6, child: _buildFormCard()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Preview card reactiva ──────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    return _BusinessPreviewCard(
      businessName: _previewName.isEmpty ? 'Nombre del negocio' : _previewName,
      businessLogoUrl: _previewLogoUrl,
      businessAddress:
          _previewAddress.isEmpty ? 'Dirección principal' : _previewAddress,
    );
  }

  // ── Formulario migrado a AppTextField ────────────────────────────────────
  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del negocio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              // ── Campo 1: Nombre ──────────────────────────────────────────
              AppTextField(
                controller: _businessNameCtrl,
                label: 'Nombre del negocio',
                icon: Icons.store_rounded,
                hintText: 'Mi Tienda',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty
                            ? 'El nombre del negocio es requerido'
                            : null,
                onChanged: (val) {
                  setState(() => _previewName = val);
                  _markChanged();
                },
              ),
              const SizedBox(height: 14),

              // ── Campo 2: RUC ────────────────────────────────────────────
              AppTextField(
                controller: _taxIdCtrl,
                label: 'RUC / Tax ID',
                icon: Icons.badge_outlined,
                hintText: '20123456789',
                keyboardType: TextInputType.number,
                focusNode: _taxIdFocus,
                textInputAction: TextInputAction.next,
                helperText: 'Se muestra en facturas y reportes',
                onChanged: (_) => _markChanged(),
              ),
              const SizedBox(height: 14),

              // ── Campo 3: Dirección ──────────────────────────────────────
              AppTextField(
                controller: _addressCtrl,
                label: 'Dirección',
                icon: Icons.location_on_outlined,
                hintText: 'Av. Principal 123',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                focusNode: _addressFocus,
                textInputAction: TextInputAction.next,
                onChanged: (val) {
                  setState(() => _previewAddress = val);
                  _markChanged();
                },
              ),
              const SizedBox(height: 14),

              // ── Campo 4: Teléfono ───────────────────────────────────────
              AppTextField(
                controller: _phoneCtrl,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                hintText: '+51 999 999 999',
                keyboardType: TextInputType.phone,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                helperText: 'Formato: +51 999 999 999',
                onChanged: (_) => _markChanged(),
              ),
              const SizedBox(height: 14),

              // ── Campo 5: URL Logo (preview se actualiza al perder foco) ─
              AppTextField(
                controller: _logoUrlCtrl,
                label: 'URL del logo',
                icon: Icons.image_outlined,
                hintText: 'https://...',
                keyboardType: TextInputType.url,
                focusNode: _logoUrlFocus,
                textInputAction: TextInputAction.done,
                helperText: 'URL pública de la imagen (jpg, png, webp)',
                onChanged: (_) => _markChanged(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nota informativa con ColorScheme (sin teal hardcoded) ─────────────────
  Widget _buildInfoNote() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta información se usa en toda la app: título global, menú lateral y vista cliente.',
              style: TextStyle(color: primary, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vista previa del negocio ────────────────────────────────────────────────

class _BusinessPreviewCard extends StatelessWidget {
  final String businessName;
  final String businessLogoUrl;
  final String businessAddress;

  const _BusinessPreviewCard({
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: título + badge "En tiempo real" ──────────────────
            Row(
              children: [
                Text(
                  'Vista previa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'En tiempo real',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Banner del negocio con gradiente ─────────────────────────
            Semantics(
              label:
                  'Vista previa del negocio: $businessName, $businessAddress',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F9D8F), Color(0xFF0C7C72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LogoBadge(logoUrl: businessLogoUrl),
                    const SizedBox(height: 14),

                    // Nombre con fade animado al cambiar
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder:
                          (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          businessName,
                          key: ValueKey(businessName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Dirección con fade animado al cambiar
                    // Fix WCAG: white70 (3.2:1) → white con alpha 0.9 (≈4.6:1)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder:
                          (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          businessAddress,
                          key: ValueKey(businessAddress),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo del negocio (ícono o imagen de red) ────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final String logoUrl;

  const _LogoBadge({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 38,
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        errorWidget:
            (context, url, error) => const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 34,
            ),
      ),
    );
  }
}
