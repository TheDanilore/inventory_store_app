import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_modal_sheet.dart';

class AgronomicAvatarPreset {
  final String id;
  final String title;
  final String role;
  final String avatarUrl;
  final Color badgeColor;
  final IconData icon;

  const AgronomicAvatarPreset({
    required this.id,
    required this.title,
    required this.role,
    required this.avatarUrl,
    required this.badgeColor,
    required this.icon,
  });
}

/// Selector interactivo camaleónico de Avatares Agrícolas y Fotos de Perfil.
/// Se adapta entre BottomSheet arrastrable en móvil y Diálogo centrado con Blur/ESC en Tablet y Desktop.
class AgronomicAvatarPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final String userInitial;
  final void Function(String? newAvatarUrl, Uint8List? imageBytes)
  onAvatarSelected;

  const AgronomicAvatarPickerDialog({
    super.key,
    required this.currentAvatarUrl,
    required this.userInitial,
    required this.onAvatarSelected,
  });

  static const List<AgronomicAvatarPreset> presets = [
    AgronomicAvatarPreset(
      id: 'agronomo',
      title: 'Ingeniero Agrónomo',
      role: 'Suelos & Nutrición',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=CarlosAgronomo&backgroundColor=b6e3f4',
      badgeColor: Color(0xFF059669),
      icon: Icons.agriculture_rounded,
    ),
    AgronomicAvatarPreset(
      id: 'almacen',
      title: 'Operador de Almacén',
      role: 'Stock & FEFO',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=MateoAlmacen&backgroundColor=ffd5dc',
      badgeColor: Color(0xFF2563EB),
      icon: Icons.inventory_2_rounded,
    ),
    AgronomicAvatarPreset(
      id: 'campo',
      title: 'Técnico de Campo',
      role: 'Monitoreo Fitosanitario',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=LucasCampo&backgroundColor=d1d4f9',
      badgeColor: Color(0xFF0D9488),
      icon: Icons.eco_rounded,
    ),
    AgronomicAvatarPreset(
      id: 'productora',
      title: 'Productora Agrícola',
      role: 'Administración & Cosecha',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=MariaProductora&backgroundColor=c0aede',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.yard_rounded,
    ),
    AgronomicAvatarPreset(
      id: 'calidad',
      title: 'Supervisora de Calidad',
      role: 'Semillas & Insumos',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=ElenaCalidad&backgroundColor=ffdfbf',
      badgeColor: Color(0xFFEA580C),
      icon: Icons.verified_rounded,
    ),
    AgronomicAvatarPreset(
      id: 'ventas',
      title: 'Asesor Técnico POS',
      role: 'Atención & Venta Agrícola',
      avatarUrl:
          'https://api.dicebear.com/7.x/adventurer/png?seed=DiegoVentas&backgroundColor=d1fae5',
      badgeColor: Color(0xFF16A34A),
      icon: Icons.storefront_rounded,
    ),
  ];

  static Future<void> show(
    BuildContext context, {
    required String? currentAvatarUrl,
    required String userInitial,
    required void Function(String? newAvatarUrl, Uint8List? imageBytes)
    onAvatarSelected,
  }) {
    return AdaptiveModalSheet.show<void>(
      context,
      maxWidth: 580,
      maxHeightFactor: 0.88,
      barrierLabel: 'Personalizar avatar',
      builder:
          (ctx) => AgronomicAvatarPickerDialog(
            currentAvatarUrl: currentAvatarUrl,
            userInitial: userInitial,
            onAvatarSelected: onAvatarSelected,
          ),
    );
  }

  @override
  State<AgronomicAvatarPickerDialog> createState() =>
      _AgronomicAvatarPickerDialogState();
}

class _AgronomicAvatarPickerDialogState
    extends State<AgronomicAvatarPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedUrl;
  Uint8List? _uploadedBytes;
  bool _isResetToInitials = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedUrl = widget.currentAvatarUrl;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        AppFeedbackService.lightImpact();
        setState(() {
          _uploadedBytes = bytes;
          _selectedUrl = null;
          _isResetToInitials = false;
        });
      }
    } catch (_) {}
  }

  void _handleApply() {
    AppFeedbackService.mediumImpact();
    if (_isResetToInitials) {
      widget.onAvatarSelected('', null);
    } else if (_uploadedBytes != null) {
      widget.onAvatarSelected(null, _uploadedBytes);
    } else {
      widget.onAvatarSelected(_selectedUrl, null);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDialog = AdaptiveModalSheet.isDialogMode(context);
    final isDark = AppColors.isDark(context);
    final successColor = AppColors.successText(context);

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // ── Cabecera ─────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 8, 14, 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.successBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.successBorder(context)),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  color: successColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalizar Avatar',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.txtPrimary(context),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elige un rol agrícola o sube tu propia foto',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.txtSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDialog) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfSubtle(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.brdSubtle(context)),
                  ),
                  child: Text(
                    'ESC',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.txtMuted(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.txtSecondary(context),
                ),
              ),
            ],
          ),
        ),

        // ── Tab Bar (Predeterminados Agrícolas vs Subir Foto) ───────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfSubtle(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.brd(context)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              onTap: (_) => AppFeedbackService.selectionClick(),
              indicator: BoxDecoration(
                color:
                    isDark ? AppColors.darkSurfaceHighlight : AppColors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorderSubtle : AppColors.border,
                ),
              ),
              labelColor: AppColors.txtPrimary(context),
              unselectedLabelColor: AppColors.txtSecondary(context),
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.agriculture_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Roles Agrícolas'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Subir Foto'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Contenido de pestañas ────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildPresetsTab(), _buildCustomPhotoTab()],
          ),
        ),

        // ── Footer con SafeArea ──────────────────────────────────────────
        Divider(height: 1, color: AppColors.dividerColor(context)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    AppFeedbackService.selectionClick();
                    setState(() {
                      _isResetToInitials = true;
                      _selectedUrl = null;
                      _uploadedBytes = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Usar iniciales',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _isResetToInitials
                            ? AppColors.brandPrimarySoft(context)
                            : AppColors.txtSecondary(context),
                    minimumSize: const Size(44, 44),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.txtSecondary(context),
                        side: BorderSide(color: AppColors.brdSubtle(context)),
                        minimumSize: const Size(88, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _handleApply,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.successDark : AppColors.tealDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(132, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Aplicar Avatar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsTab() {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 430;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            childAspectRatio: isNarrow ? 3.8 : 2.15,
          ),
          itemCount: AgronomicAvatarPickerDialog.presets.length,
          itemBuilder: (context, index) {
            final preset = AgronomicAvatarPickerDialog.presets[index];
            final isSelected =
                !_isResetToInitials &&
                _uploadedBytes == null &&
                _selectedUrl == preset.avatarUrl;

            return _PresetAvatarTile(
              preset: preset,
              isSelected: isSelected,
              disableAnimations: disableAnimations,
              onTap: () {
                AppFeedbackService.selectionClick();
                setState(() {
                  _selectedUrl = preset.avatarUrl;
                  _uploadedBytes = null;
                  _isResetToInitials = false;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCustomPhotoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfSubtle(context),
              border: Border.all(
                color: AppColors.brdSubtle(context),
                width: 2,
              ),
              image:
                  _uploadedBytes != null
                      ? DecorationImage(
                        image: MemoryImage(_uploadedBytes!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                _uploadedBytes == null
                    ? Icon(
                      Icons.photo_camera_outlined,
                      size: 38,
                      color: AppColors.txtMuted(context),
                    )
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Sube una fotografía desde tu dispositivo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.txtPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Formatos compatibles: JPG, PNG. Tamaño máximo recomendado: 5 MB.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.txtSecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.txtPrimary(context),
                  side: BorderSide(color: AppColors.brdSubtle(context)),
                  minimumSize: const Size(136, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Tomar Foto', style: TextStyle(fontSize: 13)),
              ),
              FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary(context),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(176, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text(
                  'Seleccionar de Galería',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetAvatarTile extends StatefulWidget {
  final AgronomicAvatarPreset preset;
  final bool isSelected;
  final bool disableAnimations;
  final VoidCallback onTap;

  const _PresetAvatarTile({
    required this.preset,
    required this.isSelected,
    required this.disableAnimations,
    required this.onTap,
  });

  @override
  State<_PresetAvatarTile> createState() => _PresetAvatarTileState();
}

class _PresetAvatarTileState extends State<_PresetAvatarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final successColor = AppColors.successText(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:
              widget.disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? AppColors.successBg(context)
                    : (_hovered
                        ? AppColors.surfHover(context)
                        : AppColors.surfSubtle(context)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  widget.isSelected
                      ? successColor
                      : (_hovered
                          ? AppColors.brdSubtle(context)
                          : AppColors.brd(context)),
              width: widget.isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.surf(context),
                    backgroundImage: CachedNetworkImageProvider(
                      widget.preset.avatarUrl,
                    ),
                  ),
                  if (widget.isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surf(context),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.preset.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color:
                            widget.isSelected
                                ? successColor
                                : AppColors.txtPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.preset.role,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.txtSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
