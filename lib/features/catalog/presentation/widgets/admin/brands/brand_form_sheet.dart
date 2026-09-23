import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/brands/brands_cubit.dart';

/// Formulario adaptativo de Marca (Brand):
/// - Desktop / Tablet (>= 720px): Slide-Over Drawer lateral derecho (Linear/Stripe style).
/// - Mobile (< 720px): Modal BottomSheet elástico con esquinas redondeadas (Apple HIG style).
class BrandFormSheet extends StatefulWidget {
  final BrandEntity? brand;
  final bool isSlideOver;

  const BrandFormSheet({
    super.key,
    this.brand,
    this.isSlideOver = false,
  });

  static Future<bool?> showAdaptive(
    BuildContext context, {
    BrandEntity? brand,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cubit = context.read<BrandsCubit>();

    if (screenWidth >= 720) {
      return showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogContext, anim1, anim2) {
          return BlocProvider.value(
            value: cubit,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 460,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: BrandFormSheet(
                    brand: brand,
                    isSlideOver: true,
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => BlocProvider.value(
          value: cubit,
          child: BrandFormSheet(
            brand: brand,
            isSlideOver: false,
          ),
        ),
      );
    }
  }

  @override
  State<BrandFormSheet> createState() => _BrandFormSheetState();
}

class _BrandFormSheetState extends State<BrandFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _logoCtrl;
  late final TextEditingController _websiteCtrl;
  final FocusNode _nameFocusNode = FocusNode();
  bool _isActive = true;

  String _previewName = '';
  String _previewLogo = '';

  @override
  void initState() {
    super.initState();
    final b = widget.brand;
    _previewName = b?.name ?? '';
    _previewLogo = b?.logoUrl ?? '';
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _logoCtrl = TextEditingController(text: b?.logoUrl ?? '');
    _websiteCtrl = TextEditingController(text: b?.website ?? '');
    _isActive = b?.isActive ?? true;

    _nameCtrl.addListener(() {
      if (mounted) setState(() => _previewName = _nameCtrl.text.trim());
    });
    _logoCtrl.addListener(() {
      if (mounted) setState(() => _previewLogo = _logoCtrl.text.trim());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _logoCtrl.dispose();
    _websiteCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<BrandsCubit>();
    final success = await cubit.saveBrand(
      existingBrand: widget.brand,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      logoUrl: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      isActive: _isActive,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
      AppSnackbar.show(
        context,
        message: widget.brand == null
            ? 'Marca "${_nameCtrl.text.trim()}" creada con éxito.'
            : 'Marca actualizada exitosamente.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.brand != null;
    final cubitState = context.watch<BrandsCubit>().state;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header del Sheet / Drawer ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.branding_watermark_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Editar Marca' : 'Nueva Marca',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isEdit
                            ? 'Actualiza los datos y presencia de marca'
                            : 'Registra un fabricante o marca para los productos',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar (Esc)',
                ),
              ],
            ),
          ),

          // ── Cuerpo scrollable con inputs ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre de la Marca
                  _buildSectionLabel('NOMBRE DE LA MARCA *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    focusNode: _nameFocusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Ej. Bayer, Syngenta, Stihl, Nike...',
                      prefixIcon: const Icon(Icons.verified_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El nombre de la marca es requerido.';
                      }
                      if (v.trim().length < 2) {
                        return 'Debe tener al menos 2 caracteres.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // URL del Logo
                  _buildSectionLabel('URL DEL LOGO (OPCIONAL)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _logoCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://ejemplo.com/logo.png',
                      prefixIcon: const Icon(Icons.image_outlined, size: 20),
                      suffixIcon: _previewLogo.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _logoCtrl.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Sitio Web Oficial
                  _buildSectionLabel('SITIO WEB OFICIAL (OPCIONAL)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _websiteCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://www.marca.com',
                      prefixIcon: const Icon(Icons.language_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Descripción
                  _buildSectionLabel('DESCRIPCIÓN / NOTAS (OPCIONAL)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Breve reseña sobre el fabricante o línea de productos...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Switch Estado Activo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado de la marca',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _isActive
                                  ? 'Activa y visible en catálogo / formularios'
                                  : 'Inactiva (oculta en selección de productos)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isActive,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Previsualización en Vivo de la Tarjeta
                  _buildLivePreviewCard(),
                ],
              ),
            ),
          ),

          // ── Footer con Botones de Acción ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: cubitState.isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: cubitState.isSaving ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: cubitState.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    cubitState.isSaving
                        ? 'Guardando...'
                        : (isEdit ? 'Actualizar Marca' : 'Guardar Marca'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isSlideOver) {
      return content;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: content,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final name = _previewName.isEmpty ? 'Nombre de la Marca' : _previewName;
    final hasLogo = _previewLogo.isNotEmpty && _previewLogo.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'VISTA PREVIA EN TARJETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Logo preview box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? CachedNetworkImage(
                        imageUrl: _previewLogo,
                        fit: BoxFit.contain,
                        placeholder: (ctx, url) => const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (ctx, url, err) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 20, color: AppColors.textMuted),
                        ),
                      )
                    : Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
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
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _previewName.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isActive ? AppColors.successLight : AppColors.slateLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isActive ? 'ACTIVA' : 'INACTIVA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _isActive ? AppColors.success : AppColors.slate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descCtrl.text.isNotEmpty
                          ? _descCtrl.text
                          : (_websiteCtrl.text.isNotEmpty
                              ? _websiteCtrl.text
                              : 'Sin descripción adicional'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
