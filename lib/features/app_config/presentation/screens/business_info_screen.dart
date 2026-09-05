import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
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
  bool _showManualUrlInput = false;

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
    _showManualUrlInput = info.logoUrl.isNotEmpty && !info.logoUrl.contains('supabase.co');
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

  void _discardChanges() {
    final cubit = context.read<AppConfigCubit>();
    if (cubit.state.businessInfo != null) {
      setState(() {
        _hasChanges = false;
        _populateFields(cubit.state.businessInfo!);
      });
      AppSnackbar.show(
        context,
        message: 'Cambios descartados.',
        type: SnackbarType.info,
      );
    }
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
          message: 'Logo subido correctamente.',
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
                message: 'Información del negocio guardada exitosamente.',
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

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
                if (_hasChanges && !isSaving) _save();
              },
              const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
                if (_hasChanges && !isSaving) _save();
              },
            },
            child: Focus(
              autofocus: true,
              child: AdminLayout(
                title: 'Información del Negocio',
                showBackButton: true,
                // El bottomNavigationBar monolítico ha sido erradicado en favor de un Floating Dock animado.
                bottomNavigationBar: null,
                body: isLoading
                    ? const _BusinessInfoSkeleton()
                    : hasError
                    ? _buildErrorState(context.read<AppConfigCubit>())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 900;
                          final isTablet = constraints.maxWidth >= 600 && !isDesktop;

                          return Stack(
                            children: [
                              // Contenido Principal Scrollable
                              Positioned.fill(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    isDesktop ? 32 : 16,
                                    16,
                                    isDesktop ? 32 : 16,
                                    // Padding extra inferior para que el floating dock no tape contenido
                                    _hasChanges ? 100 : 32,
                                  ),
                                  child: isDesktop
                                      ? _buildDesktopLayout(isSaving, supabaseUrl)
                                      : isTablet
                                          ? _buildTabletLayout(isSaving, supabaseUrl)
                                          : _buildMobileLayout(isSaving, supabaseUrl),
                                ),
                              ),

                              // ─── FLOATING UNSAVED CHANGES DOCK (LINEAR / SHOPIFY STYLE) ───
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedSlide(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    offset: _hasChanges ? Offset.zero : const Offset(0, 2),
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: _hasChanges ? 1.0 : 0.0,
                                      child: _buildFloatingDock(isSaving, isDesktop),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dock flotante elegante que emerge solo cuando hay cambios pendientes
  Widget _buildFloatingDock(bool isSaving, bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade600.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cambios sin guardar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isSaving ? null : _discardChanges,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Descartar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(
              isDesktop ? 'Guardar (Ctrl+S)' : 'Guardar',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppConfigCubit config) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar la información del negocio.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => config.loadBusinessInfo(force: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isSaving, String supabaseUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPreviewCard(),
        const SizedBox(height: 16),
        _buildFormCard(isSaving, supabaseUrl, isDesktop: false),
        const SizedBox(height: 16),
        _buildConnectionSection(supabaseUrl),
      ],
    );
  }

  Widget _buildTabletLayout(bool isSaving, String supabaseUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildPreviewCard(),
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
    );
  }

  Widget _buildDesktopLayout(bool isSaving, String supabaseUrl) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 40,
              child: Column(
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 20),
                  _buildConnectionSection(supabaseUrl),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 60,
              child: _buildFormCard(isSaving, supabaseUrl, isDesktop: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _BusinessPreviewCard(
      businessName: _previewName.isEmpty ? 'Nombre del negocio' : _previewName,
      businessLogoUrl: _logoUrl ?? '',
      businessAddress:
          _previewAddress.isEmpty ? 'Dirección no configurada' : _previewAddress,
      businessTaxId: _taxIdCtrl.text.isEmpty ? 'Sin RUC' : _taxIdCtrl.text,
      businessPhone: _phoneCtrl.text.isEmpty ? 'Sin teléfono' : _phoneCtrl.text,
      onUploadLogo: _pickLogoImage,
    );
  }

  Widget _buildFormCard(
    bool isSaving,
    String supabaseUrl, {
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del Formulario
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos del Negocio',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Esta información aparece en comprobantes, reportes y la vista del cliente.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),

            // Campos del Formulario
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _businessNameCtrl,
                      label: 'Nombre del negocio',
                      icon: Icons.store_rounded,
                      hintText: 'Ej. Mi Tienda',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'El nombre del negocio es requerido'
                          : null,
                      onChanged: (val) {
                        setState(() => _previewName = val);
                        _markChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppTextField(
                      controller: _taxIdCtrl,
                      label: 'RUC / Tax ID',
                      icon: Icons.badge_outlined,
                      hintText: 'Ej. 20123456789',
                      keyboardType: TextInputType.number,
                      focusNode: _taxIdFocus,
                      textInputAction: TextInputAction.next,
                      helperText: 'Identificador fiscal para comprobantes',
                      onChanged: (val) {
                        setState(() {});
                        _markChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _addressCtrl,
                      label: 'Dirección física',
                      icon: Icons.location_on_outlined,
                      hintText: 'Av. Principal 123, Lima',
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppTextField(
                      controller: _phoneCtrl,
                      label: 'Teléfono o WhatsApp',
                      icon: Icons.phone_outlined,
                      hintText: '+51 999 999 999',
                      keyboardType: TextInputType.phone,
                      focusNode: _phoneFocus,
                      textInputAction: TextInputAction.next,
                      helperText: 'Contacto comercial para clientes',
                      onChanged: (val) {
                        setState(() {});
                        _markChanged();
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              AppTextField(
                controller: _businessNameCtrl,
                label: 'Nombre del negocio',
                icon: Icons.store_rounded,
                hintText: 'Ej. Mi Tienda',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'El nombre del negocio es requerido'
                    : null,
                onChanged: (val) {
                  setState(() => _previewName = val);
                  _markChanged();
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _taxIdCtrl,
                label: 'RUC / Tax ID',
                icon: Icons.badge_outlined,
                hintText: 'Ej. 20123456789',
                keyboardType: TextInputType.number,
                focusNode: _taxIdFocus,
                textInputAction: TextInputAction.next,
                helperText: 'Identificador fiscal para comprobantes',
                onChanged: (val) {
                  setState(() {});
                  _markChanged();
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _addressCtrl,
                label: 'Dirección física',
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
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Teléfono o WhatsApp',
                icon: Icons.phone_outlined,
                hintText: '+51 999 999 999',
                keyboardType: TextInputType.phone,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                helperText: 'Contacto comercial para clientes',
                onChanged: (val) {
                  setState(() {});
                  _markChanged();
                },
              ),
            ],

            const SizedBox(height: 24),

            // ─── SELECTOR VISUAL DE LOGO DE MARCA ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar del logo actual
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _logoUrl != null && _logoUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _logoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(
                                Icons.storefront_rounded,
                                color: Colors.grey,
                                size: 30,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Logo Comercial',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recomendado: PNG o WebP cuadrado con fondo transparente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : _pickLogoImage,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Subir Logo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      setState(() => _showManualUrlInput = !_showManualUrlInput);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showManualUrlInput
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          Text(
                            _showManualUrlInput
                                ? 'Ocultar URL manual'
                                : 'Ingresar URL pública manualmente',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showManualUrlInput) ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _logoUrlCtrl,
                      label: 'URL pública del logo',
                      icon: Icons.link_rounded,
                      hintText: 'https://...',
                      keyboardType: TextInputType.url,
                      focusNode: _logoUrlFocus,
                      textInputAction: TextInputAction.done,
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
                      onChanged: (val) {
                        setState(() => _logoUrl = val);
                        _markChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 24),

            // ─── MÓDULO DE LEALTAD Y MONEDAS (FEATURE TOGGLES) ───
            _LoyaltySection(
              globalEnabled: _loyaltyGlobalEnabled,
              customerVisible: _loyaltyCustomerVisible,
              onGlobalChanged: (val) {
                setState(() {
                  _loyaltyGlobalEnabled = val;
                  if (!val) _loyaltyCustomerVisible = false;
                  _markChanged();
                });
              },
              onCustomerVisibleChanged: _loyaltyGlobalEnabled
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
                'Conexión actualizada. Reinicia la aplicación para aplicar los cambios.',
            type: SnackbarType.info,
          );
        }
      },
    );
  }
}

// ─── TARJETA DE PREVISUALIZACIÓN DE MARCA (BRAND HERO STUDIO) ─────────────────
class _BusinessPreviewCard extends StatelessWidget {
  final String businessName;
  final String businessLogoUrl;
  final String businessAddress;
  final String businessTaxId;
  final String businessPhone;
  final VoidCallback onUploadLogo;

  const _BusinessPreviewCard({
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessAddress,
    required this.businessTaxId,
    required this.businessPhone,
    required this.onUploadLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titular de la vista previa
          Row(
            children: [
              const Text(
                'Identidad de Marca',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFA7F3D0),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 12,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'En vivo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjeta corporativa simulada (Membrete / Header de App)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Logo + Botón Editar
                Row(
                  children: [
                    InkWell(
                      onTap: onUploadLogo,
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          _LogoBadge(logoUrl: businessLogoUrl),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        businessTaxId,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nombre del Negocio
                Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Dirección
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        businessAddress,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Teléfono
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      businessPhone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Nota informativa de branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se sincroniza automáticamente en tickets PDF, reportes y catálogo web.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LOGO BADGE CON CACHED NETWORK IMAGE ──────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final String logoUrl;

  const _LogoBadge({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: 28,
        ),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// ─── SECCIÓN DE INFRAESTRUCTURA (SUPABASE MULTI-TENANT) ───────────────────────
class _ConnectionSection extends StatelessWidget {
  final String supabaseUrl;
  final VoidCallback onResetPressed;

  const _ConnectionSection({
    required this.supabaseUrl,
    required this.onResetPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = supabaseUrl.isNotEmpty && supabaseUrl != 'Desconocida';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Infraestructura',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFFECFDF5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Conectado' : 'Por defecto',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isConnected
                            ? const Color(0xFF065F46)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Servidor de Base de Datos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            supabaseUrl,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetPressed,
              icon: const Icon(Icons.sync_alt_rounded, size: 16),
              label: const Text('Cambiar Servidor (Multi-Tenant)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECCIÓN DE FIDELIDAD (FEATURE TOGGLES) ───────────────────────────────────
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.stars_rounded,
                color: Colors.amber.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Módulo de Fidelidad y Monedas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configuración del sistema de recompensas por compras.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Feature Card 1: Habilitación Global
        _FeatureToggleCard(
          icon: Icons.power_settings_new_rounded,
          iconColor: Colors.amber.shade700,
          iconBackground: Colors.amber.shade50,
          title: 'Habilitar Sistema Globalmente',
          description:
              'Si se apaga, el sistema de monedas y saldo desaparece para toda la aplicación.',
          value: globalEnabled,
          onChanged: onGlobalChanged,
        ),
        const SizedBox(height: 12),

        // Feature Card 2: Visibilidad en Cliente
        _FeatureToggleCard(
          icon: Icons.visibility_outlined,
          iconColor: Colors.indigo.shade600,
          iconBackground: Colors.indigo.shade50,
          title: 'Visible para Clientes',
          description:
              'Permite a los clientes ver su saldo de puntos en el catálogo y perfil.',
          value: customerVisible,
          isEnabled: globalEnabled,
          onChanged: onCustomerVisibleChanged,
        ),
      ],
    );
  }
}

class _FeatureToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final bool value;
  final bool isEnabled;
  final ValueChanged<bool>? onChanged;

  const _FeatureToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.value,
    this.isEnabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isEnabled ? Colors.white : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (value && isEnabled)
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled ? iconBackground : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isEnabled ? iconColor : Colors.grey.shade400,
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isEnabled ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: isEnabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

// ─── SKELETON SHIMMER LOADING PLACEHOLDER ─────────────────────────────────────
class _BusinessInfoSkeleton extends StatelessWidget {
  const _BusinessInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildBox(height: 240),
                const SizedBox(height: 16),
                _buildBox(height: 140),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: _buildBox(height: 480),
          ),
        ],
      ),
    );
  }

  Widget _buildBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
    );
  }
}
