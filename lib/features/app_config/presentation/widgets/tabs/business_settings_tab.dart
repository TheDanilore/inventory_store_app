import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/change_connection_dialog.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_scroll_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_section_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_tiles.dart';

class BusinessSettingsTab extends StatefulWidget {
  final bool isDark;

  const BusinessSettingsTab({super.key, required this.isDark});

  @override
  State<BusinessSettingsTab> createState() => _BusinessSettingsTabState();
}

class _BusinessSettingsTabState extends State<BusinessSettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _logoUrlCtrl;

  bool _isBusinessPopulated = false;
  bool _hasBusinessChanges = false;
  bool _isSavingBusiness = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController();
    _taxIdCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _logoUrlCtrl = TextEditingController();

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

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;

    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (blocCtx, state) {
        final info = state.businessInfo;
        if (!_isBusinessPopulated && info != null) {
          _populateBusinessFields(info);
        }

        final logoUrl = _logoUrlCtrl.text.trim();
        final supabaseUrl = state.connectionUrl ?? 'https://*.supabase.co';

        return SettingsScrollContent(
          isDark: isDark,
          children: [
            // ── Card 1: Identidad de Marca y Logotipo Comercial ─────────────
            SettingsSectionCard(
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
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
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
                                            Icons.upload_file_rounded,
                                            size: 15,
                                          ),
                                  label: Text(
                                    _isUploadingLogo
                                        ? 'Optimizando...'
                                        : 'Subir Imagen',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed:
                                      _isUploadingLogo ? null : _pickLogoImage,
                                ),
                                if (logoUrl.isNotEmpty)
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 15,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text(
                                      'Quitar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _logoUrlCtrl.clear();
                                        _hasBusinessChanges = true;
                                      });
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
              ],
            ),
            const SizedBox(height: 16),

            // ── Card 2: Datos Fiscales y de Contacto ─────────────────────────
            SettingsSectionCard(
              isDark: isDark,
              icon: Icons.badge_rounded,
              title: 'Datos Fiscales y Dirección Comercial',
              subtitle:
                  'Parámetros legales impresos en las cabeceras de tickets y comprobantes',
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final isMultiCol = c.maxWidth >= 600;
                    if (isMultiCol) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'Razón Social / Nombre Comercial *',
                                  hint: 'Ej: INVERSIONES DANILORE S.A.C.',
                                  icon: Icons.business_rounded,
                                  controller: _businessNameCtrl,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'RUC / Tax ID',
                                  hint: '10751565149',
                                  icon: Icons.numbers_rounded,
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
                                flex: 2,
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label:
                                      'Dirección Fiscal de la Sede Principal',
                                  hint: 'Av. Principal 123, Lima, Perú',
                                  icon: Icons.location_on_rounded,
                                  controller: _addressCtrl,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildBusinessInputField(
                                  context: context,
                                  isDark: isDark,
                                  label: 'Teléfono de Contacto',
                                  hint: '+51 987 654 321',
                                  icon: Icons.phone_rounded,
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildBusinessInputField(
                            context: context,
                            isDark: isDark,
                            label: 'Razón Social / Nombre Comercial *',
                            hint: 'Ej: INVERSIONES DANILORE S.A.C.',
                            icon: Icons.business_rounded,
                            controller: _businessNameCtrl,
                          ),
                          const SizedBox(height: 12),
                          _buildBusinessInputField(
                            context: context,
                            isDark: isDark,
                            label: 'RUC / Tax ID',
                            hint: '10751565149',
                            icon: Icons.numbers_rounded,
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
                            label: 'Dirección Fiscal de la Sede Principal',
                            hint: 'Av. Principal 123, Lima, Perú',
                            icon: Icons.location_on_rounded,
                            controller: _addressCtrl,
                          ),
                          const SizedBox(height: 12),
                          _buildBusinessInputField(
                            context: context,
                            isDark: isDark,
                            label: 'Teléfono de Contacto',
                            hint: '+51 987 654 321',
                            icon: Icons.phone_rounded,
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Botones de acción Guardar / Descartar
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_hasBusinessChanges) ...[
                        OutlinedButton(
                          onPressed: () => _discardBusinessChanges(info),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Descartar Cambios'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      FilledButton.icon(
                        icon:
                            _isSavingBusiness
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.save_rounded, size: 18),
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
            SettingsSectionCard(
              isDark: isDark,
              icon: Icons.cloud_done_rounded,
              title: 'Infraestructura de Datos & Nube',
              subtitle: 'Conexión activa con el backend Supabase Multi-Tenant',
              action: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text(
                  'Cambiar Servidor (Multi-Tenant)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(
                    0xFF2563EB,
                  ).withValues(alpha: 0.08),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
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
                SettingsInfoTile(
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
}
