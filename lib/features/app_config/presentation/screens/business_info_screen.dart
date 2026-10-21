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
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/business_info_skeleton.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/business_preview_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/change_connection_dialog.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/connection_section.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/loyalty_section.dart';
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

  bool _loyaltyGlobalEnabled = false;
  bool _loyaltyCustomerVisible = false;

  final _logoNotifier = ValueNotifier<String>('');

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
      _logoNotifier.value = _logoUrlCtrl.text.trim();
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
    _logoNotifier.value = info.logoUrl;
    _loyaltyGlobalEnabled = info.loyaltyGlobalEnabled;
    _loyaltyCustomerVisible = info.loyaltyCustomerVisible;
    _showManualUrlInput =
        info.logoUrl.isNotEmpty && !info.logoUrl.contains('supabase.co');
  }

  @override
  void dispose() {
    _logoUrlFocus.removeListener(_onLogoFocusChange);
    _logoNotifier.dispose();
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
    try {
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
        format:
            CompressFormat
                .webp, // Preserva canal alfa transparente de logos PNG/WebP
      );

      final url = await cubit.uploadBusinessLogo(compressed);
      if (url != null && mounted) {
        _logoUrlCtrl.text = url;
        _logoNotifier.value = url;
        _markChanged();
        AppSnackbar.show(
          context,
          message: 'Logo subido correctamente.',
          type: SnackbarType.success,
        );
      } else if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al subir el logo. Intenta nuevamente.',
          type: SnackbarType.error,
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al seleccionar o comprimir el logo comercial',
        tag: 'BusinessInfoScreen',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo procesar la imagen seleccionada.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<AppConfigCubit>();
    await cubit.saveBusinessInfo(
      businessName: _businessNameCtrl.text.trim(),
      taxId: _taxIdCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
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
        buildWhen:
            (previous, current) =>
                previous.status != current.status ||
                previous.connectionUrl != current.connectionUrl ||
                previous.saveStatus != current.saveStatus,
        builder: (context, state) {
          final isSaving = state.saveStatus == ViewState.loading;
          final isLoading =
              state.status == ViewState.initial ||
              state.status == ViewState.loading;
          final hasError = state.status == ViewState.error;
          final supabaseUrl = state.connectionUrl ?? 'Desconocida';

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
              ): () {
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
                // El bottomNavigationBar monolítico ha sido erradicado en favor de un Floating Dock animado.
                bottomNavigationBar: null,
                body:
                    isLoading
                        ? const BusinessInfoSkeleton()
                        : hasError
                        ? _buildErrorState(context.read<AppConfigCubit>())
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 900;
                            final isTablet =
                                constraints.maxWidth >= 600 && !isDesktop;

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
                                    child:
                                        isDesktop
                                            ? _buildDesktopLayout(
                                              isSaving,
                                              supabaseUrl,
                                            )
                                            : isTablet
                                            ? _buildTabletLayout(
                                              isSaving,
                                              supabaseUrl,
                                            )
                                            : _buildMobileLayout(
                                              isSaving,
                                              supabaseUrl,
                                            ),
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
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      offset:
                                          _hasChanges
                                              ? Offset.zero
                                              : const Offset(0, 2),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        opacity: _hasChanges ? 1.0 : 0.0,
                                        child: _buildFloatingDock(
                                          isSaving,
                                          isDesktop,
                                        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow:
            isDark
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
                : [
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
                color: isDark ? const Color(0xFFF8FAFC) : Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isSaving ? null : _discardChanges,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
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
            icon:
                isSaving
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        _businessNameCtrl,
        _taxIdCtrl,
        _addressCtrl,
        _phoneCtrl,
        _logoNotifier,
      ]),
      builder: (context, _) {
        final name = _businessNameCtrl.text.trim();
        final address = _addressCtrl.text.trim();
        final taxId = _taxIdCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        final logo = _logoNotifier.value.trim();

        return BusinessPreviewCard(
          businessName: name.isEmpty ? 'Nombre del negocio' : name,
          businessLogoUrl: logo,
          businessAddress:
              address.isEmpty ? 'Dirección no configurada' : address,
          businessTaxId: taxId.isEmpty ? 'Sin RUC' : taxId,
          businessPhone: phone.isEmpty ? 'Sin teléfono' : phone,
          onUploadLogo: _pickLogoImage,
        );
      },
    );
  }

  Widget _buildFormCard(
    bool isSaving,
    String supabaseUrl, {
    required bool isDesktop,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow:
            isDark
                ? []
                : [
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
                      Text(
                        'Datos del Negocio',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color:
                              isDark
                                  ? const Color(0xFFF8FAFC)
                                  : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Esta información aparece en comprobantes, reportes y la vista del cliente.',
                        style: TextStyle(
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.divider,
            ),
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
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'El nombre del negocio es requerido';
                        }
                        if (val.trim().length < 2) {
                          return 'Debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                      onChanged: (_) => _markChanged(),
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
                      helperText:
                          'Identificador fiscal para comprobantes (11 dígitos)',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (val.trim().length != 11) {
                            return 'El RUC debe tener exactamente 11 dígitos';
                          }
                        }
                        return null;
                      },
                      onChanged: (_) => _markChanged(),
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
                      inputFormatters: [LengthLimitingTextInputFormatter(200)],
                      textCapitalization: TextCapitalization.sentences,
                      focusNode: _addressFocus,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _markChanged(),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final digits = val.trim().replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digits.length < 6) {
                            return 'Ingresa un número telefónico válido';
                          }
                        }
                        return null;
                      },
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
                hintText: 'Ej. Mi Tienda',
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El nombre del negocio es requerido';
                  }
                  if (val.trim().length < 2) {
                    return 'Debe tener al menos 2 caracteres';
                  }
                  return null;
                },
                onChanged: (_) => _markChanged(),
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
                helperText:
                    'Identificador fiscal para comprobantes (11 dígitos)',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    if (val.trim().length != 11) {
                      return 'El RUC debe tener exactamente 11 dígitos';
                    }
                  }
                  return null;
                },
                onChanged: (_) => _markChanged(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _addressCtrl,
                label: 'Dirección física',
                icon: Icons.location_on_outlined,
                hintText: 'Av. Principal 123',
                maxLines: 2,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                textCapitalization: TextCapitalization.sentences,
                focusNode: _addressFocus,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _markChanged(),
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    final digits = val.trim().replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 6) {
                      return 'Ingresa un número telefónico válido';
                    }
                  }
                  return null;
                },
                onChanged: (_) => _markChanged(),
              ),
            ],

            const SizedBox(height: 24),

            // ─── SELECTOR VISUAL DE LOGO DE MARCA ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.darkSurfaceElevated
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar del logo actual
                      ValueListenableBuilder<String>(
                        valueListenable: _logoNotifier,
                        builder: (context, logoUrl, _) {
                          return Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color:
                                  isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : Colors.grey.shade300,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                logoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: logoUrl,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (context, url, error) => Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Image.asset(
                                              'assets/logo_icon.png',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                    )
                                    : Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Image.asset(
                                        'assets/logo_icon.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logo Comercial',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? const Color(0xFFF8FAFC)
                                        : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recomendado: PNG o WebP cuadrado con fondo transparente.',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? const Color(0xFF94A3B8)
                                        : Colors.grey.shade600,
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
                      setState(
                        () => _showManualUrlInput = !_showManualUrlInput,
                      );
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
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade600,
                            size: 20,
                          ),
                          Text(
                            _showManualUrlInput
                                ? 'Ocultar URL manual'
                                : 'Ingresar URL pública manualmente',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.grey.shade700,
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
                        _logoNotifier.value = val.trim();
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
            LoyaltySection(
              globalEnabled: _loyaltyGlobalEnabled,
              customerVisible: _loyaltyCustomerVisible,
              onGlobalChanged: (val) {
                setState(() {
                  _loyaltyGlobalEnabled = val;
                  if (!val) _loyaltyCustomerVisible = false;
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
    return ConnectionSection(
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
