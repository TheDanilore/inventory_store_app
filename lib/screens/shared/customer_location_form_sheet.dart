import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:inventory_store_app/models/customer_location.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/shared/customer_location_map_screen.dart';

/// Bottom sheet para agregar o editar una ubicación de cliente.
/// Retorna un [CustomerLocation] parcial (sin id/profileId) vía Navigator.pop().
class CustomerLocationFormSheet extends StatefulWidget {
  final CustomerLocation? existing; // null = nueva ubicación
  final bool isFirstLocation;

  const CustomerLocationFormSheet({
    super.key,
    this.existing,
    this.isFirstLocation = false,
  });

  static Future<CustomerLocation?> show(
    BuildContext context, {
    CustomerLocation? existing,
    bool isFirstLocation = false,
  }) async {
    return showModalBottomSheet<CustomerLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CustomerLocationFormSheet(
            existing: existing,
            isFirstLocation: isFirstLocation,
          ),
    );
  }

  @override
  State<CustomerLocationFormSheet> createState() =>
      _CustomerLocationFormSheetState();
}

class _CustomerLocationFormSheetState
    extends State<CustomerLocationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  String _selectedType = 'otro';
  bool _isDefault = false;
  bool _isGettingGps = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _addressCtrl.text = e.addressLine ?? '';
      _referenceCtrl.text = e.reference ?? '';
      _notesCtrl.text = e.notes ?? '';
      _latCtrl.text = e.latitude.toStringAsFixed(6);
      _lngCtrl.text = e.longitude.toStringAsFixed(6);
      _selectedType = e.locationType;
      _isDefault = e.isDefault;
    } else {
      _isDefault = widget.isFirstLocation;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _getGpsLocation() async {
    setState(() => _isGettingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _latCtrl.text = pos.latitude.toStringAsFixed(6);
          _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener GPS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  Future<void> _openMapPicker() async {
    double? initLat = double.tryParse(_latCtrl.text);
    double? initLng = double.tryParse(_lngCtrl.text);

    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder:
            (_) => CustomerLocationMapScreen(
              isPickerMode: true,
              initialPickerPoint:
                  (initLat != null && initLng != null)
                      ? LatLng(initLat, initLng)
                      : null,
            ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latCtrl.text = result.latitude.toStringAsFixed(6);
        _lngCtrl.text = result.longitude.toStringAsFixed(6);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las coordenadas no son válidas.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final result = CustomerLocation(
      id: widget.existing?.id ?? '',
      profileId: widget.existing?.profileId ?? '',
      name: _nameCtrl.text.trim(),
      locationType: _selectedType,
      latitude: lat,
      longitude: lng,
      addressLine:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      reference:
          _referenceCtrl.text.trim().isEmpty
              ? null
              : _referenceCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isDefault: _isDefault,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
                      ? 'Nueva Ubicación'
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
                    _SectionLabel('Nombre de la ubicación'),
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

                    // Coordenadas GPS
                    _SectionLabel('Coordenadas GPS'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[-0-9.]'),
                              ),
                            ],
                            decoration: _inputDecoration(
                              hint: 'Latitud',
                              icon: Icons.my_location_rounded,
                            ),
                            validator:
                                (v) =>
                                    (v == null || double.tryParse(v) == null)
                                        ? 'Inválida'
                                        : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[-0-9.]'),
                              ),
                            ],
                            decoration: _inputDecoration(
                              hint: 'Longitud',
                              icon: Icons.explore_rounded,
                            ),
                            validator:
                                (v) =>
                                    (v == null || double.tryParse(v) == null)
                                        ? 'Inválida'
                                        : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Botones GPS y mapa
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGettingGps ? null : _getGpsLocation,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: BorderSide(
                                color: AppColors.teal.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon:
                                _isGettingGps
                                    ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.teal,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.gps_fixed_rounded,
                                      size: 16,
                                    ),
                            label: Text(
                              _isGettingGps ? 'Obteniendo...' : 'Usar GPS',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openMapPicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.info,
                              side: BorderSide(
                                color: AppColors.info.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(
                              Icons.map_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Elegir en mapa',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Descripción libre
                    _SectionLabel('Descripción (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Ej: Km 12 carretera Casma, parcela 4',
                        icon: Icons.text_snippet_rounded,
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
                        hint: 'Ej: Frente al canal de riego',
                        icon: Icons.signpost_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notas
                    _SectionLabel('Notas (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        hint: 'Ej: Solo se puede llegar en mototaxi',
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
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          widget.existing == null
                              ? 'Guardar ubicación'
                              : 'Actualizar',
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
        children: _types.map((t) {
          final (type, label, icon, color) = t;
          final isSelected = selected == type;
          return GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
