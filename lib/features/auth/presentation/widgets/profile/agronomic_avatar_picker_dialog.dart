import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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

/// Selector interactivo y premium de Avatares Agrícolas y Fotos de Perfil
class AgronomicAvatarPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final String userInitial;
  final void Function(String? newAvatarUrl, Uint8List? imageBytes) onAvatarSelected;

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
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          elevation: 16,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: AgronomicAvatarPickerDialog(
              currentAvatarUrl: currentAvatarUrl,
              userInitial: userInitial,
              onAvatarSelected: onAvatarSelected,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.88,
          child: AgronomicAvatarPickerDialog(
            currentAvatarUrl: currentAvatarUrl,
            userInitial: userInitial,
            onAvatarSelected: onAvatarSelected,
          ),
        ),
      );
    }
  }

  @override
  State<AgronomicAvatarPickerDialog> createState() =>
      _AgronomicAvatarPickerDialogState();
}

class _AgronomicAvatarPickerDialogState
    extends State<AgronomicAvatarPickerDialog> with SingleTickerProviderStateMixin {
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
        setState(() {
          _uploadedBytes = bytes;
          _selectedUrl = null;
          _isResetToInitials = false;
        });
      }
    } catch (_) {}
  }

  void _handleApply() {
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
    return Column(
      children: [
        // ── Header con vista previa actual ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Color(0xFF065F46),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalizar Avatar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Elige un rol agrícola o sube tu propia foto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // ── Tab Bar (Predeterminados Agrícolas vs Foto Personalizada) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
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

        // ── Contenido de las pestañas ──────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPresetsTab(),
              _buildCustomPhotoTab(),
            ],
          ),
        ),

        // ── Footer con Acciones ────────────────────────────────────────
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
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
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 12.5)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _handleApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Aplicar Avatar',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsTab() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemCount: AgronomicAvatarPickerDialog.presets.length,
      itemBuilder: (context, index) {
        final preset = AgronomicAvatarPickerDialog.presets[index];
        final isSelected = !_isResetToInitials &&
            _uploadedBytes == null &&
            _selectedUrl == preset.avatarUrl;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedUrl = preset.avatarUrl;
              _uploadedBytes = null;
              _isResetToInitials = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF059669)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF059669).withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      backgroundImage: CachedNetworkImageProvider(preset.avatarUrl),
                    ),
                    if (isSelected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 11, color: Colors.white),
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
                        preset.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF065F46)
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.role,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
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
        );
      },
    );
  }

  Widget _buildCustomPhotoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Vista previa del avatar cargado
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
              image: _uploadedBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_uploadedBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _uploadedBytes == null
                ? const Icon(
                    Icons.photo_camera_outlined,
                    size: 38,
                    color: Color(0xFF94A3B8),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sube una fotografía desde tu dispositivo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Formatos compatibles: JPG, PNG. Tamaño máximo recomendado: 5 MB.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Tomar Foto', style: TextStyle(fontSize: 12.5)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('Seleccionar de Galería', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
