import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/change_connection_dialog.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

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

  final _taxIdFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _logoUrlFocus = FocusNode();

  bool _hasChanges = false;

  bool _loyaltyGlobalEnabled = true;
  bool _loyaltyCustomerVisible = true;

  String _previewName = '';
  String _previewAddress = '';
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AppConfigCubit>();
    cubit.loadBusinessInfo();
    if (cubit.state.connectionUrl == null) {
      cubit.loadConnectionUrl();
    }
    _logoUrlFocus.addListener(_onLogoFocusChange);

    if (cubit.state.businessInfo != null) {
      _populateFields(cubit.state.businessInfo!);
    }
  }

  void _onLogoFocusChange() {
    if (!_logoUrlFocus.hasFocus) {
      setState(() => _logoUrl = _logoUrlCtrl.text);
    }
  }

  void _populateFields(BusinessInfoEntity info) {
    if (_hasChanges) return;
    _businessNameCtrl.text =
        info.businessName == 'Sin configurar' ? '' : info.businessName;
    _taxIdCtrl.text = info.taxId;
    _addressCtrl.text = info.address;
    _phoneCtrl.text = info.phone;
    _logoUrlCtrl.text = info.logoUrl;
    _loyaltyGlobalEnabled = info.loyaltyGlobalEnabled;
    _loyaltyCustomerVisible = info.loyaltyCustomerVisible;

    _previewName = _businessNameCtrl.text;
    _previewAddress = _addressCtrl.text;
    _logoUrl = _logoUrlCtrl.text;
  }

  @override
  void dispose() {
    _logoUrlFocus.removeListener(_onLogoFocusChange);
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

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (!mounted) return;
    final cubit = context.read<AppConfigCubit>();
    final bytes = await pickedFile.readAsBytes();

    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 500,
      minHeight: 500,
      quality: 85,
    );

    final url = await cubit.uploadBusinessLogo(compressed);
    if (url != null) {
      setState(() {
        _logoUrlCtrl.text = url;
        _logoUrl = url;
        _markChanged();
      });
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Logo subido y URL generada correctamente.',
          type: SnackbarType.success,
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al subir el logo. Intenta nuevamente.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<AppConfigCubit>();
    await cubit.saveBusinessInfo(
      businessName: _businessNameCtrl.text,
      taxId: _taxIdCtrl.text,
      address: _addressCtrl.text,
      phone: _phoneCtrl.text,
      loyaltyGlobalEnabled: _loyaltyGlobalEnabled,
      loyaltyCustomerVisible: _loyaltyCustomerVisible,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AppConfigCubit, AppConfigState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == ViewState.success &&
                state.businessInfo != null) {
              setState(() => _populateFields(state.businessInfo!));
            }
          },
        ),
        BlocListener<AppConfigCubit, AppConfigState>(
          listenWhen:
              (previous, current) => previous.saveStatus != current.saveStatus,
          listener: (context, state) {
            if (state.saveStatus == ViewState.success) {
              setState(() => _hasChanges = false);
              AppSnackbar.show(
                context,
                message: 'Información del negocio guardada.',
                type: SnackbarType.success,
              );
            } else if (state.saveStatus == ViewState.error) {
              AppSnackbar.show(
                context,
                message:
                    state.errorMessage ??
                    'No se pudo guardar la información. Intente nuevamente.',
                type: SnackbarType.error,
              );
            }
          },
        ),
      ],
      child: BlocBuilder<AppConfigCubit, AppConfigState>(
        builder: (context, state) {
          final isSaving = state.saveStatus == ViewState.loading;
          final isLoading =
              state.status == ViewState.initial ||
              state.status == ViewState.loading;
          final hasError = state.status == ViewState.error;
          final supabaseUrl = state.connectionUrl ?? 'Desconocida';

          return AdminLayout(
            title: 'Información del Negocio',
            showBackButton: true,
            bottomNavigationBar:
                (!isLoading && !hasError)
                    ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: AppPrimaryButton(
                            key: ValueKey(_hasChanges),
                            label:
                                _hasChanges
                                    ? 'Guardar cambios'
                                    : 'Todo guardado',
                            loading: isSaving,
                            icon: Icon(
                              _hasChanges
                                  ? Icons.save_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            backgroundColor:
                                _hasChanges ? null : Colors.grey.shade400,
                            onPressed:
                                (_hasChanges && !isSaving) ? _save : null,
                          ),
                        ),
                      ),
                    )
                    : null,
            body:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : hasError
                    ? _buildErrorState(context.read<AppConfigCubit>())
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 900) {
                          return _buildDesktopLayout(isSaving, supabaseUrl);
                        } else if (constraints.maxWidth >= 600) {
                          return _buildTabletLayout(isSaving, supabaseUrl);
                        }
                        return _buildMobileLayout(isSaving, supabaseUrl);
                      },
                    ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(AppConfigCubit config) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error al cargar la información del negocio.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => config.loadBusinessInfo(force: true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isSaving, String supabaseUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPreviewCard(),
          const SizedBox(height: 16),
          _buildFormCard(isSaving, supabaseUrl, isDesktop: false),
          const SizedBox(height: 12),
          const _InfoNote(),
          const SizedBox(height: 16),
          _buildConnectionSection(supabaseUrl),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(bool isSaving, String supabaseUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildPreviewCard(),
                const SizedBox(height: 16),
                const _InfoNote(),
                const SizedBox(height: 16),
                _buildConnectionSection(supabaseUrl),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: _buildFormCard(isSaving, supabaseUrl, isDesktop: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(bool isSaving, String supabaseUrl) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 40,
                child: Column(
                  children: [
                    _buildPreviewCard(),
                    const SizedBox(height: 16),
                    const _InfoNote(),
                    const SizedBox(height: 16),
                    _buildConnectionSection(supabaseUrl),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 60,
                child: _buildFormCard(isSaving, supabaseUrl, isDesktop: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _BusinessPreviewCard(
      businessName: _previewName.isEmpty ? 'Nombre del negocio' : _previewName,
      businessLogoUrl: _logoUrl ?? '',
      businessAddress:
          _previewAddress.isEmpty ? 'Dirección principal' : _previewAddress,
    );
  }

  Widget _buildFormCard(
    bool isSaving,
    String supabaseUrl, {
    required bool isDesktop,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.05),
      ),
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
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
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
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
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
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
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
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
                  ),
                ],
              ),
            ] else ...[
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
            ],

            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _logoUrlCtrl,
                    label: 'URL del logo',
                    icon: Icons.image_outlined,
                    hintText: 'https://...',
                    keyboardType: TextInputType.url,
                    focusNode: _logoUrlFocus,
                    textInputAction: TextInputAction.done,
                    helperText: 'URL pública de la imagen (jpg, png, webp)',
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final uri = Uri.tryParse(val.trim());
                        if (uri == null ||
                            !uri.hasAbsolutePath ||
                            !uri.scheme.startsWith('http')) {
                          return 'Ingresa una URL válida (ej. https://...)';
                        }
                      }
                      return null;
                    },
                    onChanged: (_) => _markChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _pickLogoImage,
                    icon:
                        isSaving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.upload_file_rounded, size: 20),
                    label: const Text('Subir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            _LoyaltySection(
              globalEnabled: _loyaltyGlobalEnabled,
              customerVisible: _loyaltyCustomerVisible,
              onGlobalChanged: (val) {
                setState(() {
                  _loyaltyGlobalEnabled = val;
                  if (!val) {
                    _loyaltyCustomerVisible = false;
                  }
                  _markChanged();
                });
              },
              onCustomerVisibleChanged:
                  _loyaltyGlobalEnabled
                      ? (val) {
                        setState(() {
                          _loyaltyCustomerVisible = val;
                          _markChanged();
                        });
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(String supabaseUrl) {
    return _ConnectionSection(
      supabaseUrl: supabaseUrl,
      onResetPressed: () async {
        final updated = await ChangeConnectionDialog.show(context, supabaseUrl);
        if (updated == true && mounted) {
          context.read<AppConfigCubit>().loadConnectionUrl();
          AppSnackbar.show(
            context,
            message:
                'Conexión actualizada. Reinicia la app para aplicar los cambios.',
            type: SnackbarType.info,
          );
        }
      },
    );
  }
}

class _LoyaltySection extends StatelessWidget {
  final bool globalEnabled;
  final bool customerVisible;
  final ValueChanged<bool> onGlobalChanged;
  final ValueChanged<bool>? onCustomerVisibleChanged;

  const _LoyaltySection({
    required this.globalEnabled,
    required this.customerVisible,
    required this.onGlobalChanged,
    required this.onCustomerVisibleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Módulo de Monedas y Lealtad',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Habilitar Sistema Globalmente',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Si se apaga, el sistema desaparece para todos (clientes y admins).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          value: globalEnabled,
          activeColor: AppColors.primary,
          onChanged: onGlobalChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Visible para Clientes',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Si se apaga, los clientes no lo ven, pero los administradores sí.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          value: customerVisible,
          activeColor: AppColors.primary,
          onChanged: onCustomerVisibleChanged,
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta información se usa en toda la app: título global, menú lateral y vista cliente.',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vista previa',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'En tiempo real',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Vista previa del negocio: $businessName, $businessAddress',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0F3460)],
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
    );
  }
}

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

class _ConnectionSection extends StatelessWidget {
  final String supabaseUrl;
  final VoidCallback onResetPressed;

  const _ConnectionSection({
    required this.supabaseUrl,
    required this.onResetPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Servidor de Base de Datos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Supabase URL conectada',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                supabaseUrl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetPressed,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Cambiar Servidor (Multi-Tenant)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
