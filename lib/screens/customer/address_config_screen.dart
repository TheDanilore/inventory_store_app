import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/shared/data/peru_data.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AddressConfigScreen extends StatefulWidget {
  final String? initialAddress;

  const AddressConfigScreen({super.key, this.initialAddress});

  @override
  State<AddressConfigScreen> createState() => _AddressConfigScreenState();
}

class _AddressConfigScreenState extends State<AddressConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();

  String? _selectedDepartment;
  String? _selectedProvince;
  String? _selectedDistrict;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialAddress();
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _loadInitialAddress() {
    final initial = widget.initialAddress?.trim();
    if (initial == null || initial.isEmpty) return;

    // Parseo mejorado: 'Dep / Prov / Dist - Calle/Av 123 - Ref: Frente al parque'
    // Opcionalmente la referencia podría no estar
    final parts = initial.split(' - ');
    final locationPieces = parts.first.trim().split(' / ');

    if (locationPieces.length >= 3) {
      _selectedDepartment = locationPieces[0].trim();
      _selectedProvince = locationPieces[1].trim();
      _selectedDistrict = locationPieces[2].trim();
    }

    if (parts.length > 1) {
      // El segundo elemento podría ser la calle o la referencia (si es antiguo)
      final p1 = parts[1].trim();
      if (p1.startsWith('Ref:')) {
        _referenceCtrl.text = p1.replaceFirst('Ref: ', '').trim();
      } else {
        _streetCtrl.text = p1;
        if (parts.length > 2) {
          _referenceCtrl.text =
              parts.sublist(2).join(' - ').replaceFirst('Ref: ', '').trim();
        }
      }
    }
  }

  String? _buildAddressPreview() {
    if (_selectedDepartment == null ||
        _selectedProvince == null ||
        _selectedDistrict == null ||
        _streetCtrl.text.trim().isEmpty) {
      return null;
    }
    final base =
        '$_selectedDepartment / $_selectedProvince / $_selectedDistrict';
    final street = _streetCtrl.text.trim();
    final ref = _referenceCtrl.text.trim();

    final streetLine = '$base - $street';
    return ref.isEmpty ? streetLine : '$streetLine - Ref: $ref';
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDepartment == null ||
        _selectedProvince == null ||
        _selectedDistrict == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona departamento, provincia y distrito.',
        type: SnackbarType.error,
      );
      return;
    }

    if (!PeruData.isCoveredDistrict(_selectedDistrict)) {
      AppSnackbar.show(
        context,
        message: 'Lo sentimos, aún no llegamos a esa zona.',
        type: SnackbarType.error,
      );
      return;
    }

    final preview = _buildAddressPreview();
    if (preview == null) return;

    setState(() => _isSaving = true);

    try {
      // Simulamos latencia de guardado para la animacion si se requiere
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      final result = {
        'department': _selectedDepartment,
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'reference':
            _referenceCtrl.text.trim().isEmpty
                ? null
                : _referenceCtrl.text.trim(),
        'address_line': preview,
      };

      Navigator.pop(context, result);
    } catch (e) {
      AppSnackbar.show(
        context,
        message: 'Error procesando formulario',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final preview = _buildAddressPreview();
    final isCovered = PeruData.isCoveredDistrict(_selectedDistrict);
    final isComplete =
        _selectedDepartment != null &&
        _selectedProvince != null &&
        _selectedDistrict != null &&
        _streetCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isSaving ? null : () => Navigator.pop(context),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        title: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Configurar domicilio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: IgnorePointer(
            ignoring: _isSaving,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header banner ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF0F3460)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tu dirección sin errores',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Proporciona la calle y número para un delivery exitoso.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.map_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Selects + referencia ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Departamento
                        _buildDropdownField(
                          label: 'Departamento',
                          icon: Icons.location_city_outlined,
                          value: _selectedDepartment,
                          items: PeruData.departments,
                          onChanged:
                              (v) => setState(() {
                                _selectedDepartment = v;
                                _selectedProvince = null;
                                _selectedDistrict = null;
                              }),
                        ),
                        const SizedBox(height: 14),

                        // Provincia
                        _buildDropdownField(
                          label: 'Provincia',
                          icon: Icons.apartment_outlined,
                          value: _selectedProvince,
                          items: PeruData.provincesOf(_selectedDepartment),
                          enabled: _selectedDepartment != null,
                          onChanged:
                              (v) => setState(() {
                                _selectedProvince = v;
                                _selectedDistrict = null;
                              }),
                        ),
                        const SizedBox(height: 14),

                        // Distrito
                        _buildDropdownField(
                          label: 'Distrito',
                          icon: Icons.place_outlined,
                          value: _selectedDistrict,
                          items: PeruData.districtsOf(_selectedProvince),
                          enabled: _selectedProvince != null,
                          onChanged:
                              (v) => setState(() => _selectedDistrict = v),
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 18),

                        // Dirección exacta
                        _buildTextField(
                          controller: _streetCtrl,
                          label: 'Dirección exacta (Calle/Av/Jr + Número) *',
                          icon: Icons.add_road_outlined,
                          hint: 'Ej: Av. Larco 123',
                          requiredField: true,
                        ),

                        const SizedBox(height: 16),

                        // Referencia
                        _buildTextField(
                          controller: _referenceCtrl,
                          label: 'Referencia (opcional)',
                          icon: Icons.signpost_outlined,
                          hint: 'Ej: Frente al parque, puerta azul',
                          requiredField: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Cobertura + preview ───────────────────────────────
                  if (_selectedDistrict != null) ...[
                    _buildCoverageChip(isCovered),
                    const SizedBox(height: 10),
                  ],

                  if (preview != null) ...[
                    _buildPreviewCard(preview),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 4),

                  // ── Botón guardar ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          (_isSaving || !isComplete || !isCovered)
                              ? null
                              : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: AppColors.success.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: AppColors.background,
                        disabledForegroundColor: AppColors.textHint,
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Guardar dirección',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: items.contains(value) ? value : null,
      onChanged: enabled ? onChanged : null,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Este campo es obligatorio';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textHint,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        filled: true,
        fillColor: enabled ? Colors.transparent : AppColors.background,
      ),
      items:
          items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
      isExpanded: true,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool requiredField,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: [
        // Evitar solo espacios
        FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
      ],
      validator:
          requiredField
              ? (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Este campo es obligatorio';
                }
                if (val.trim().length < 4) {
                  return 'Ingresa una dirección válida';
                }
                return null;
              }
              : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildCoverageChip(bool isCovered) {
    final color = isCovered ? AppColors.success : AppColors.error;
    final icon = isCovered ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final text =
        isCovered
            ? 'Cobertura disponible en esta zona'
            : 'Lo sentimos, aún no llegamos a esa zona';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(String preview) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
