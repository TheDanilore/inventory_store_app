import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';

/// Bottom sheet para agregar o editar una ubicación de cliente.
class CustomerLocationFormSheet extends StatefulWidget {
  final CustomerLocationEntity? existing;
  final PlaceResult? place; // Viene del mapa en modo creación
  final bool isFirstLocation;
  final bool isDialog;
  final Future<void> Function(CustomerLocationEntity)? onSave;

  const CustomerLocationFormSheet({
    super.key,
    this.existing,
    this.place,
    this.isFirstLocation = false,
    this.isDialog = false,
    this.onSave,
  });

  static Future<bool?> show(
    BuildContext context, {
    CustomerLocationEntity? existing,
    PlaceResult? place,
    bool isFirstLocation = false,
    Future<void> Function(CustomerLocationEntity)? onSave,
  }) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 600) {
      return showDialog<bool>(
        context: context,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 800,
                ),
                child: CustomerLocationFormSheet(
                  existing: existing,
                  place: place,
                  isFirstLocation: isFirstLocation,
                  isDialog: true,
                  onSave: onSave,
                ),
              ),
            ),
      );
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CustomerLocationFormSheet(
            existing: existing,
            place: place,
            isFirstLocation: isFirstLocation,
            isDialog: false,
            onSave: onSave,
          ),
    );
  }

  @override
  State<CustomerLocationFormSheet> createState() =>
      _CustomerLocationFormSheetState();
}

class _CustomerLocationFormSheetState extends State<CustomerLocationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late double _lat;
  late double _lng;

  String _selectedType = 'otro';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.place;

    if (e != null) {
      _nameCtrl.text = e.name;
      _addressCtrl.text = e.addressLine ?? '';
      _referenceCtrl.text = e.reference ?? '';
      _notesCtrl.text = e.notes ?? '';
      _lat = e.latitude;
      _lng = e.longitude;
      _selectedType = e.locationType;
      _isDefault = e.isDefault;
    } else if (p != null) {
      _addressCtrl.text = p.fullAddress;
      _lat = p.latitude;
      _lng = p.longitude;
      _isDefault = widget.isFirstLocation;
    } else {
      _lat = 0;
      _lng = 0;
      _isDefault = widget.isFirstLocation;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final result = CustomerLocationEntity(
      id: widget.existing?.id ?? '',
      profileId: widget.existing?.profileId ?? '',
      name: _nameCtrl.text.trim(),
      locationType: _selectedType,
      latitude: _lat,
      longitude: _lng,
      addressLine:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      reference:
          _referenceCtrl.text.trim().isEmpty
              ? null
              : _referenceCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isDefault: _isDefault,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (widget.onSave == null) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave!(result);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: widget.isDialog ? 0 : 60),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            widget.isDialog
                ? BorderRadius.circular(28)
                : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          if (!widget.isDialog)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_rounded,
                    color: AppColors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.existing == null
                      ? 'Detalles de la Ubicación'
                      : 'Editar Ubicación',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    _SectionLabel('Nombre corto para esta ubicación'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: 'Ej: Mi chacra norte, Casa principal',
                        icon: Icons.label_rounded,
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'El nombre es obligatorio'
                                  : null,
                    ),
                    const SizedBox(height: 16),

                    // Tipo de ubicación
                    _SectionLabel('Tipo de lugar'),
                    const SizedBox(height: 8),
                    _TypeSelector(
                      selected: _selectedType,
                      onChanged: (t) => setState(() => _selectedType = t),
                    ),
                    const SizedBox(height: 16),

                    // Dirección (Pre-llenada)
                    _SectionLabel('Dirección'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Ej: Km 12 carretera Casma, parcela 4',
                        icon: Icons.map_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Referencia
                    _SectionLabel('Referencia (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _referenceCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Ej: Frente al canal de riego rojo',
                        icon: Icons.signpost_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notas
                    _SectionLabel('Notas adicionales (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        hint: 'Ej: El portón es verde, cuidado con los perros',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle principal
                    Material(
                      color: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                        activeThumbColor: AppColors.teal,
                        title: const Text(
                          'Ubicación principal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Aparecerá destacada en el perfil',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: AppColors.teal.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          _isSaving
                              ? 'Guardando...'
                              : (widget.existing == null
                                  ? 'Guardar ubicación'
                                  : 'Actualizar'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  static const _types = [
    ('casa', 'Casa', Icons.home_rounded, AppColors.info),
    ('chacra', 'Chacra', Icons.grass_rounded, AppColors.teal),
    ('fundo', 'Fundo', Icons.agriculture_rounded, AppColors.warning),
    ('local', 'Local', Icons.store_rounded, AppColors.accent),
    ('otro', 'Otro', Icons.location_on_rounded, AppColors.textSecondary),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _types.map((t) {
              final (type, label, icon, color) = t;
              final isSelected = selected == type;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  color:
                      isSelected
                          ? color.withValues(alpha: 0.12)
                          : AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? color : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(type),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected ? color : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected ? color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
