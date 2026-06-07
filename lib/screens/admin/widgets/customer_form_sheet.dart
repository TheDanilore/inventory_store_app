import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── PUNTO DE ENTRADA ─────────────────────────────────────────────────────────
//
// Uso — crear:
//   CustomerFormSheet.show(context, onSaved: () => _load());
//
// Uso — editar:
//   CustomerFormSheet.show(context, customer: c, onSaved: () => _load());
//
// ─────────────────────────────────────────────────────────────────────────────

class CustomerFormSheet extends StatefulWidget {
  final CustomerSummary? customer; // null → modo crear

  const CustomerFormSheet({super.key, this.customer});

  /// Abre el bottom sheet. Devuelve true si se guardó algo.
  static Future<bool?> show(
    BuildContext context, {
    CustomerSummary? customer,
    VoidCallback? onSaved,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerFormSheet(customer: customer),
    );
    if (saved == true) onSaved?.call();
    return saved;
  }

  @override
  State<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<CustomerFormSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumberCtrl = TextEditingController();
  final _walletCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _debtCtrl = TextEditingController();

  String _docType = 'DNI';
  bool _isActive = true;
  bool _hasCredit = false;
  bool _isSaving = false;

  // Estado inicial del crédito (para saber si hay que insertar o actualizar)
  bool _creditExistsInDb = false;
  String? _creditId;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final c = widget.customer;
    if (c == null) return;

    _nameCtrl.text = c.fullName;
    _phoneCtrl.text = c.phone ?? '';
    _docNumberCtrl.text = c.documentNumber ?? '';
    _docType = c.documentType ?? 'DNI';
    _walletCtrl.text = c.walletBalance.toString();
    _isActive = c.isActive;

    // Cargar crédito
    _loadCredit();
  }

  Future<void> _loadCredit() async {
    if (!_isEditing) return;
    final resp = await _supabase
        .from('customer_credits')
        .select('id, credit_limit, current_debt, is_active')
        .eq('profile_id', widget.customer!.id)
        .maybeSingle();

    if (resp != null && mounted) {
      setState(() {
        _creditExistsInDb = true;
        _creditId = resp['id'] as String;
        _hasCredit = resp['is_active'] as bool;
        _creditLimitCtrl.text =
            (resp['credit_limit'] as num).toStringAsFixed(2);
        _debtCtrl.text = (resp['current_debt'] as num).toStringAsFixed(2);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _docNumberCtrl.dispose();
    _walletCtrl.dispose();
    _creditLimitCtrl.dispose();
    _debtCtrl.dispose();
    super.dispose();
  }

  // ─── GUARDAR ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final profileData = {
        'full_name': _nameCtrl.text.trim(),
        'phone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'document_type': _docType,
        'document_number': _docNumberCtrl.text.trim().isEmpty
            ? null
            : _docNumberCtrl.text.trim(),
        'is_active': _isActive,
        'wallet_balance': int.tryParse(_walletCtrl.text.trim()) ?? 0,
      };

      String profileId;

      if (_isEditing) {
        // Actualizar perfil
        await _supabase
            .from('profiles')
            .update(profileData)
            .eq('id', widget.customer!.id);
        profileId = widget.customer!.id;
      } else {
        // Insertar perfil nuevo (sin auth_user_id → cliente manual)
        final inserted = await _supabase
            .from('profiles')
            .insert({...profileData, 'role': 'customer'})
            .select('id')
            .single();
        profileId = inserted['id'] as String;
      }

      // ── Crédito ──────────────────────────────────────────────────────────
      if (_hasCredit) {
        final creditData = {
          'profile_id': profileId,
          'credit_limit':
              double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0,
          'current_debt': double.tryParse(_debtCtrl.text.trim()) ?? 0.0,
          'is_active': true,
        };

        if (_creditExistsInDb && _creditId != null) {
          await _supabase
              .from('customer_credits')
              .update(creditData)
              .eq('id', _creditId!);
        } else {
          await _supabase.from('customer_credits').insert({
            ...creditData,
            'created_by': _supabase.auth.currentUser?.id,
          });
        }
      } else if (_creditExistsInDb && _creditId != null) {
        // Desactivar crédito si ya existía
        await _supabase
            .from('customer_credits')
            .update({'is_active': false})
            .eq('id', _creditId!);
      }

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _showError(_pgError(e));
    } catch (e) {
      _showError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _pgError(PostgrestException e) {
    final msg = e.message;
    if (msg.contains('uq_profile_identity')) {
      return 'Ya existe un cliente con ese tipo y número de documento.';
    }
    if (msg.contains('profiles_auth_user_id_key')) {
      return 'Este usuario ya tiene un perfil.';
    }
    return 'Error de base de datos: $msg';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit_rounded
                            : Icons.person_add_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Editar cliente' : 'Nuevo',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? widget.customer!.fullName
                              : 'Completa los datos del cliente',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Formulario ───────────────────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 100),
                    children: [
                      // ── Sección: Datos personales ──────────────────────
                      _SectionHeader(
                        icon: Icons.person_rounded,
                        title: 'Datos personales',
                      ),
                      const SizedBox(height: 12),

                      // Nombre completo
                      _FieldLabel('Nombre completo *'),
                      _StyledField(
                        controller: _nameCtrl,
                        hint: 'Ej: Juan Pérez López',
                        prefixIcon: Icons.badge_rounded,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa el nombre'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Teléfono
                      _FieldLabel('Teléfono'),
                      _StyledField(
                        controller: _phoneCtrl,
                        hint: 'Ej: 987654321',
                        prefixIcon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tipo + Número de documento
                      _FieldLabel('Documento de identidad'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tipo
                          Container(
                            width: 100,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _docType,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'DNI', child: Text('DNI')),
                                  DropdownMenuItem(
                                      value: 'RUC', child: Text('RUC')),
                                  DropdownMenuItem(
                                      value: 'CE', child: Text('CE')),
                                  DropdownMenuItem(
                                      value: 'Pasaporte',
                                      child: Text('Pasaporte')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _docType = v ?? 'DNI'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Número
                          Expanded(
                            child: _StyledField(
                              controller: _docNumberCtrl,
                              hint: 'Número de documento',
                              prefixIcon: Icons.numbers_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(15),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Sección: Estado y billetera ────────────────────
                      _SectionHeader(
                        icon: Icons.tune_rounded,
                        title: 'Estado y billetera',
                      ),
                      const SizedBox(height: 12),

                      // Toggle activo / inactivo
                      _ToggleRow(
                        icon: Icons.circle,
                        iconColor:
                            _isActive ? AppColors.success : AppColors.textMuted,
                        title: _isActive ? 'Cliente activo' : 'Cliente inactivo',
                        subtitle: _isActive
                            ? 'Puede realizar compras'
                            : 'No puede realizar compras',
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 14),

                      // Saldo billetera
                      _FieldLabel('Saldo en billetera (monedas)'),
                      _StyledField(
                        controller: _walletCtrl,
                        hint: '0',
                        prefixIcon: Icons.stars_rounded,
                        prefixIconColor: Colors.amber.shade700,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Sección: Línea de crédito ──────────────────────
                      _SectionHeader(
                        icon: Icons.credit_card_rounded,
                        title: 'Línea de crédito',
                      ),
                      const SizedBox(height: 12),

                      _ToggleRow(
                        icon: Icons.credit_score_rounded,
                        iconColor:
                            _hasCredit ? AppColors.primary : AppColors.textMuted,
                        title: 'Crédito habilitado',
                        subtitle: _hasCredit
                            ? 'El cliente puede comprar a crédito'
                            : 'Sin línea de crédito',
                        value: _hasCredit,
                        onChanged: (v) => setState(() => _hasCredit = v),
                      ),

                      if (_hasCredit) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Límite de crédito'),
                                  _StyledField(
                                    controller: _creditLimitCtrl,
                                    hint: '0.00',
                                    prefixIcon: Icons.account_balance_wallet_rounded,
                                    prefixText: 'S/ ',
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                    validator: (v) {
                                      if (!_hasCredit) return null;
                                      final n =
                                          double.tryParse(v?.trim() ?? '');
                                      if (n == null || n < 0) {
                                        return 'Monto inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Deuda actual'),
                                  _StyledField(
                                    controller: _debtCtrl,
                                    hint: '0.00',
                                    prefixIcon: Icons.money_off_rounded,
                                    prefixText: 'S/ ',
                                    prefixIconColor: AppColors.danger,
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                    validator: (v) {
                                      if (!_hasCredit) return null;
                                      final debt =
                                          double.tryParse(v?.trim() ?? '') ??
                                              0.0;
                                      final limit = double.tryParse(
                                              _creditLimitCtrl.text.trim()) ??
                                          0.0;
                                      if (debt < 0) return 'Inválido';
                                      if (debt > limit && limit > 0) {
                                        return 'Supera el límite';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Barra de uso de crédito (preview)
                        const SizedBox(height: 10),
                        _CreditPreview(
                          limitCtrl: _creditLimitCtrl,
                          debtCtrl: _debtCtrl,
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Footer con botón guardar ────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: AppColors.border, width: 1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEditing
                                    ? Icons.save_rounded
                                    : Icons.person_add_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isEditing
                                    ? 'Guardar cambios'
                                    : 'Crear cliente',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
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
      },
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final Color? prefixIconColor;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.prefixIconColor,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(
          prefixIcon,
          size: 18,
          color: prefixIconColor ?? AppColors.textMuted,
        ),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Muestra una barra de uso del crédito en tiempo real mientras el usuario
/// escribe los montos.
class _CreditPreview extends StatefulWidget {
  final TextEditingController limitCtrl;
  final TextEditingController debtCtrl;

  const _CreditPreview({required this.limitCtrl, required this.debtCtrl});

  @override
  State<_CreditPreview> createState() => _CreditPreviewState();
}

class _CreditPreviewState extends State<_CreditPreview> {
  @override
  void initState() {
    super.initState();
    widget.limitCtrl.addListener(_rebuild);
    widget.debtCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.limitCtrl.removeListener(_rebuild);
    widget.debtCtrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limit = double.tryParse(widget.limitCtrl.text.trim()) ?? 0.0;
    final debt = double.tryParse(widget.debtCtrl.text.trim()) ?? 0.0;
    final pct = limit > 0 ? (debt / limit).clamp(0.0, 1.0) : 0.0;
    final isRisk = pct >= 0.8;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isRisk ? AppColors.danger : AppColors.success)
            .withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isRisk ? AppColors.danger : AppColors.success)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uso del crédito',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isRisk ? AppColors.danger : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isRisk ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Disponible: S/ ${(limit - debt).clamp(0, double.infinity).toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
              Text(
                'Límite: S/ ${limit.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
