import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
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

  // ── Controladores ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumberCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();

  // Ajuste de billetera: solo se usa para registrar el DELTA en wallet_movements
  final _walletAdjustCtrl = TextEditingController(text: '0');

  // ── Estado ─────────────────────────────────────────────────────────────────
  String _docType = 'DNI';
  bool _isActive = true;

  // Crédito
  bool _hasCredit = false;
  bool _creditIsActive = false; // estado real del crédito en BD
  bool _creditExistsInDb = false;
  String? _creditId;
  double _currentDebt = 0; // solo lectura, viene de BD

  // Billetera
  int _currentWalletBalance = 0; // saldo actual en BD

  // UI
  bool _isLoadingCredit = false;
  bool _isSaving = false;

  bool get _isEditing => widget.customer != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _docNumberCtrl.dispose();
    _creditLimitCtrl.dispose();
    _walletAdjustCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    final c = widget.customer;
    if (c == null) return;

    _nameCtrl.text = c.fullName;
    _phoneCtrl.text = c.phone ?? '';
    _docNumberCtrl.text = c.documentNumber ?? '';
    _docType = c.documentType ?? 'DNI';
    _isActive = c.isActive;
    _currentWalletBalance = c.walletBalance;

    _loadCredit();
  }

  Future<void> _loadCredit() async {
    if (!_isEditing) return;
    setState(() => _isLoadingCredit = true);

    try {
      final resp =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', widget.customer!.id)
              .maybeSingle();

      if (resp != null && mounted) {
        final limit = (resp['credit_limit'] as num).toDouble();
        final isActive = resp['is_active'] as bool;
        setState(() {
          _creditExistsInDb = true;
          _creditId = resp['id'] as String;
          _creditIsActive = isActive;
          _hasCredit = isActive;
          _currentDebt = (resp['current_debt'] as num).toDouble();
          _creditLimitCtrl.text = limit.toStringAsFixed(2);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCredit = false);
    }
  }

  // ── GUARDAR ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 1. Obtener el profile_id del Administrador
      String? adminProfileId;
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId != null) {
        final adminResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (adminResp != null) adminProfileId = adminResp['id'] as String;
      }

      final profileData = {
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'document_type': _docType,
        'document_number':
            _docNumberCtrl.text.trim().isEmpty
                ? null
                : _docNumberCtrl.text.trim(),
        'is_active': _isActive,
      };

      String profileId;

      if (_isEditing) {
        await _supabase
            .from('profiles')
            .update(profileData)
            .eq('id', widget.customer!.id);
        profileId = widget.customer!.id;

        // Ajuste de billetera: solo si el delta ≠ 0
        final delta = int.tryParse(_walletAdjustCtrl.text.trim()) ?? 0;
        if (delta != 0) {
          // 1. Actualizar saldo
          await _supabase
              .from('profiles')
              .update({'wallet_balance': _currentWalletBalance + delta})
              .eq('id', profileId);

          // 2. Registrar movimiento en wallet_movements
          await _supabase.from('wallet_movements').insert({
            'profile_id': profileId,
            'points': delta,
            'movement_type': delta > 0 ? 'ADMIN_ADD' : 'ADMIN_SUBTRACT',
            'description':
                delta > 0
                    ? 'Ajuste manual (+$delta monedas)'
                    : 'Ajuste manual ($delta monedas)',
          });
        }
      } else {
        // Insertar perfil nuevo (sin auth_user_id → cliente manual)
        final inserted =
            await _supabase
                .from('profiles')
                .insert({...profileData, 'role': 'customer'})
                .select('id')
                .single();
        profileId = inserted['id'] as String;
      }

      // ── Crédito ────────────────────────────────────────────────────────────
      final newLimit = double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0;

      if (_hasCredit) {
        if (_creditExistsInDb && _creditId != null) {
          // Actualizar
          await _supabase
              .from('customer_credits')
              .update({
                'credit_limit': newLimit,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', _creditId!);
        } else {
          // Crear crédito nuevo
          await _supabase.from('customer_credits').insert({
            'profile_id': profileId,
            'credit_limit': newLimit,
            'current_debt': 0.0,
            'is_active': true,
            'created_by': adminProfileId,
          });
        }
      } else if (_creditExistsInDb && _creditId != null && _creditIsActive) {
        // El crédito existía activo y el usuario lo desactivó
        await _supabase
            .from('customer_credits')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
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
    final msg = e.message.toLowerCase();
    if (msg.contains('profiles_auth_user_id_key')) {
      return 'Este usuario ya tiene un perfil registrado.';
    }
    if (msg.contains('unique') && msg.contains('document')) {
      return 'Ya existe un cliente con ese número de documento.';
    }
    return 'Error al guardar: ${e.message}';
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, message: msg, type: SnackbarType.error);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

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
              // ── Handle ────────────────────────────────────────────────────
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

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                          _isEditing ? 'Editar cliente' : 'Nuevo cliente',
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

              // ── Formulario ────────────────────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 100),
                    children: [
                      // ══ SECCIÓN: Datos personales ══════════════════════════
                      _SectionHeader(
                        icon: Icons.person_rounded,
                        title: 'Datos personales',
                      ),
                      const SizedBox(height: 12),

                      _FieldLabel('Nombre completo *'),
                      _StyledField(
                        controller: _nameCtrl,
                        hint: 'Ej: Juan Pérez López',
                        prefixIcon: Icons.badge_rounded,
                        textCapitalization: TextCapitalization.words,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Ingresa el nombre'
                                    : null,
                      ),
                      const SizedBox(height: 14),

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

                      _FieldLabel('Documento de identidad'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tipo de documento
                          Container(
                            width: 110,
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
                                    value: 'DNI',
                                    child: Text('DNI'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'RUC',
                                    child: Text('RUC'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CE',
                                    child: Text('CE'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Pasaporte',
                                    child: Text('Pasaporte'),
                                  ),
                                ],
                                onChanged:
                                    (v) =>
                                        setState(() => _docType = v ?? 'DNI'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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

                      // ══ SECCIÓN: Estado ════════════════════════════════════
                      _SectionHeader(icon: Icons.tune_rounded, title: 'Estado'),
                      const SizedBox(height: 12),

                      _ToggleRow(
                        icon: Icons.circle,
                        iconColor:
                            _isActive ? AppColors.success : AppColors.textMuted,
                        title:
                            _isActive ? 'Cliente activo' : 'Cliente inactivo',
                        subtitle:
                            _isActive
                                ? 'Puede realizar compras'
                                : 'No puede realizar compras',
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 24),

                      // ══ SECCIÓN: Billetera (solo edición) ═════════════════
                      if (_isEditing) ...[
                        _SectionHeader(
                          icon: Icons.stars_rounded,
                          title: 'Billetera de monedas',
                        ),
                        const SizedBox(height: 12),

                        // Saldo actual (solo lectura)
                        _ReadOnlyInfoRow(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: Colors.amber.shade700,
                          label: 'Saldo actual',
                          value: '$_currentWalletBalance monedas',
                        ),
                        const SizedBox(height: 12),

                        // Ajuste manual (delta, puede ser negativo)
                        _FieldLabel('Ajuste manual (puede ser negativo)'),
                        _StyledField(
                          controller: _walletAdjustCtrl,
                          hint: '0',
                          prefixIcon: Icons.add_circle_outline_rounded,
                          prefixIconColor: Colors.amber.shade700,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*'),
                            ),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty || v == '0') {
                              return null; // sin cambio, OK
                            }
                            final delta = int.tryParse(v.trim());
                            if (delta == null) return 'Valor inválido';
                            final newBalance = _currentWalletBalance + delta;
                            if (newBalance < 0) {
                              return 'El saldo resultante no puede ser negativo';
                            }
                            return null;
                          },
                        ),
                        // Preview del saldo resultante
                        _WalletAdjustPreview(
                          currentBalance: _currentWalletBalance,
                          adjustCtrl: _walletAdjustCtrl,
                        ),
                        const SizedBox(height: 6),
                        const _InfoNote(
                          text:
                              'El ajuste queda registrado en el historial de movimientos de billetera.',
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ══ SECCIÓN: Línea de crédito ══════════════════════════
                      _SectionHeader(
                        icon: Icons.credit_card_rounded,
                        title: 'Línea de crédito',
                      ),
                      const SizedBox(height: 12),

                      // Indicador de carga del crédito
                      if (_isLoadingCredit)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else ...[
                        _ToggleRow(
                          icon: Icons.credit_score_rounded,
                          iconColor:
                              _hasCredit
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                          title:
                              _hasCredit ? 'Crédito habilitado' : 'Sin crédito',
                          subtitle:
                              _hasCredit
                                  ? 'El cliente puede comprar a crédito'
                                  : 'Activa para asignar una línea de crédito',
                          value: _hasCredit,
                          onChanged: (v) => setState(() => _hasCredit = v),
                        ),

                        if (_hasCredit) ...[
                          const SizedBox(height: 14),

                          // Deuda actual (solo lectura en edición)
                          if (_isEditing && _creditExistsInDb) ...[
                            _ReadOnlyInfoRow(
                              icon: Icons.money_off_rounded,
                              iconColor:
                                  _currentDebt > 0
                                      ? AppColors.danger
                                      : AppColors.textMuted,
                              label: 'Deuda actual',
                              value: 'S/ ${_currentDebt.toStringAsFixed(2)}',
                              note:
                                  _currentDebt > 0
                                      ? 'Registra pagos desde el detalle del cliente'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Límite de crédito (editable)
                          _FieldLabel('Límite de crédito'),
                          _StyledField(
                            controller: _creditLimitCtrl,
                            hint: '0.00',
                            prefixIcon: Icons.account_balance_wallet_rounded,
                            prefixText: 'S/ ',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            validator: (v) {
                              if (!_hasCredit) return null;
                              final n = double.tryParse(v?.trim() ?? '');
                              if (n == null || n < 0) {
                                return 'Ingresa un límite válido';
                              }
                              // Advertir si el nuevo límite es menor a la deuda
                              if (_isEditing &&
                                  n < _currentDebt &&
                                  _currentDebt > 0) {
                                return 'El límite no puede ser menor a la deuda actual (S/ ${_currentDebt.toStringAsFixed(2)})';
                              }
                              return null;
                            },
                          ),

                          // Preview de uso de crédito
                          const SizedBox(height: 10),
                          _CreditPreview(
                            limitCtrl: _creditLimitCtrl,
                            currentDebt: _isEditing ? _currentDebt : 0,
                          ),

                          // Nota aclaratoria
                          const SizedBox(height: 8),
                          const _InfoNote(
                            text:
                                'La deuda se actualiza automáticamente al registrar ventas y pagos. No se edita manualmente.',
                          ),
                        ],
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Footer ────────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
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
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
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

/// Fila de información de solo lectura (no editable)
class _ReadOnlyInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? note;

  const _ReadOnlyInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.note,
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
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Nota informativa pequeña
class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 12,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ],
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGET: Preview de ajuste de billetera ───────────────────────────────────

class _WalletAdjustPreview extends StatefulWidget {
  final int currentBalance;
  final TextEditingController adjustCtrl;

  const _WalletAdjustPreview({
    required this.currentBalance,
    required this.adjustCtrl,
  });

  @override
  State<_WalletAdjustPreview> createState() => _WalletAdjustPreviewState();
}

class _WalletAdjustPreviewState extends State<_WalletAdjustPreview> {
  @override
  void initState() {
    super.initState();
    widget.adjustCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.adjustCtrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delta = int.tryParse(widget.adjustCtrl.text.trim()) ?? 0;
    final newBalance = widget.currentBalance + delta;
    final isValid = newBalance >= 0;

    if (delta == 0) return const SizedBox.shrink();

    final color =
        !isValid
            ? AppColors.danger
            : delta > 0
            ? AppColors.success
            : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              delta > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.currentBalance}  →  ',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            Text(
              '$newBalance monedas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET: Preview de crédito ───────────────────────────────────────────────

class _CreditPreview extends StatefulWidget {
  final TextEditingController limitCtrl;
  final double currentDebt;

  const _CreditPreview({required this.limitCtrl, required this.currentDebt});

  @override
  State<_CreditPreview> createState() => _CreditPreviewState();
}

class _CreditPreviewState extends State<_CreditPreview> {
  @override
  void initState() {
    super.initState();
    widget.limitCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.limitCtrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limit = double.tryParse(widget.limitCtrl.text.trim()) ?? 0.0;
    final debt = widget.currentDebt;
    final pct = limit > 0 ? (debt / limit).clamp(0.0, 1.0) : 0.0;
    final available = (limit - debt).clamp(0.0, double.infinity);
    final isRisk = pct >= 0.8;
    final color = isRisk ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vista previa del crédito',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}% usado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
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
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PreviewStat(
                  label: 'Deuda',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  color: debt > 0 ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: _PreviewStat(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _PreviewStat(
                  label: 'Límite',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
