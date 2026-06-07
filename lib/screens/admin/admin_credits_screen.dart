import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/admin_credit_movements_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

// ─── MODELO LOCAL PARA LA VISTA ──────────────────────────────────────────────
class CreditAccountModel {
  final String creditId;
  final String partnerId;
  final String partnerName;
  final String? partnerDocument;
  final String? partnerPhone;
  final double creditLimit;
  final double currentDebt;
  final double availableCredit;
  final bool isActive;

  CreditAccountModel({
    required this.creditId,
    required this.partnerId,
    required this.partnerName,
    this.partnerDocument,
    this.partnerPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.availableCredit,
    required this.isActive,
  });

  factory CreditAccountModel.fromJson(Map<String, dynamic> json) {
    return CreditAccountModel(
      creditId: json['credit_id'] as String,
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String? ?? 'Cliente Desconocido',
      partnerDocument: json['partner_document'] as String?,
      partnerPhone: json['partner_phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      availableCredit: (json['available_credit'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

// ─── PANTALLA PRINCIPAL ─────────────────────────────────────────────────────
class AdminCreditsScreen extends StatefulWidget {
  const AdminCreditsScreen({super.key});

  @override
  State<AdminCreditsScreen> createState() => _AdminCreditsScreenState();
}

class _AdminCreditsScreenState extends State<AdminCreditsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<CreditAccountModel> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Consulta a la vista SQL que creamos anteriormente
  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase.from('partner_credit_summary').select();

      final searchTerm = _searchCtrl.text.trim();
      if (searchTerm.isNotEmpty) {
        // Búsqueda por nombre o documento
        query = query.or(
          'partner_name.ilike.%$searchTerm%,partner_document.ilike.%$searchTerm%',
        );
      }

      final response = await query.order(
        'current_debt',
        ascending: false,
      ); // Los más endeudados primero

      if (mounted) {
        setState(() {
          _accounts =
              (response as List)
                  .map((item) => CreditAccountModel.fromJson(item))
                  .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar créditos: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchAccounts);
  }

  // --- UI SECUNDARIA: Abrir modal para gestionar la cuenta ---
  void _openAccountOptions(CreditAccountModel account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.partnerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.teal,
                    ),
                    title: const Text('Ver historial de movimientos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AdminCreditMovementsScreen(
                                creditId: account.creditId,
                                customerName: account.partnerName,
                                currentDebt: account.currentDebt,
                                creditLimit: account.creditLimit,
                              ),
                        ),
                      ).then((_) => _fetchAccounts()); // Refresca al volver
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.success,
                    ),
                    title: const Text('Registrar Abono / Pago'),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (_) => _RegisterPaymentModal(
                              account: account,
                              onPaymentSaved: () => _fetchAccounts(),
                            ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                    title: const Text('Editar límite de crédito'),
                    onTap: () {
                      Navigator.pop(context); // Cierra el menú inferior
                      // Abre el mismo modal, pero pasándole la cuenta a editar
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (context) => _CreateCreditAccountModal(
                              accountToEdit: account,
                              onAccountSaved: () => _fetchAccounts(),
                            ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      account.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      color:
                          account.isActive
                              ? AppColors.danger
                              : AppColors.success,
                    ),
                    title: Text(
                      account.isActive
                          ? 'Suspender línea de crédito'
                          : 'Reactivar línea de crédito',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleAccountStatus(account);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _toggleAccountStatus(CreditAccountModel account) async {
    try {
      await _supabase
          .from('customer_credits')
          .update({'is_active': !account.isActive})
          .eq('id', account.creditId);

      _fetchAccounts(); // Refrescar lista
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Estado de la cuenta actualizado',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Cuentas de Crédito',
      showBackButton: true,
      // Botón flotante para crear una nueva línea de crédito a un cliente
      // Botón flotante para crear una nueva línea de crédito a un cliente
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (context) => _CreateCreditAccountModal(
                  // Actualizamos el nombre aquí
                  onAccountSaved: () {
                    _fetchAccounts();
                  },
                ),
          );
        },
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text(
          'Nueva Cuenta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: Column(
        children: [
          // ─── BUSCADOR ───
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o DNI...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ─── LISTA DE CUENTAS ───
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _accounts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_score_rounded,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay cuentas de crédito',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                      itemCount: _accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final account = _accounts[index];

                        // Cálculos visuales
                        final debtPercentage =
                            account.creditLimit > 0
                                ? (account.currentDebt / account.creditLimit)
                                    .clamp(0.0, 1.0)
                                : 0.0;

                        final isMaxedOut =
                            account.currentDebt >= account.creditLimit;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openAccountOptions(account),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabecera: Nombre y Estado
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.tealLight,
                                        child: Text(
                                          account.partnerName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.tealDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              account.partnerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (account.partnerPhone != null ||
                                                account.partnerDocument != null)
                                              Text(
                                                [
                                                  if (account.partnerDocument !=
                                                      null)
                                                    'Doc: ${account.partnerDocument}',
                                                  if (account.partnerPhone !=
                                                      null)
                                                    'Tel: ${account.partnerPhone}',
                                                ].join(' • '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Etiqueta de estado
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              account.isActive
                                                  ? AppColors.successLight
                                                  : AppColors.dangerLight,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          account.isActive
                                              ? 'ACTIVO'
                                              : 'SUSPENDIDO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                account.isActive
                                                    ? AppColors.success
                                                    : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Deuda y Límite Textos
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Deuda Actual',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'S/ ${account.currentDebt.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  isMaxedOut
                                                      ? AppColors.danger
                                                      : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Límite',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'S/ ${account.creditLimit.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Barra de Progreso
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: debtPercentage,
                                      minHeight: 8,
                                      backgroundColor: AppColors.bg,
                                      color:
                                          isMaxedOut
                                              ? AppColors.danger
                                              : (debtPercentage > 0.8
                                                  ? Colors.orange
                                                  : AppColors.teal),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Disponible
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isMaxedOut
                                            ? 'Límite alcanzado'
                                            : '${(debtPercentage * 100).toStringAsFixed(0)}% utilizado',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isMaxedOut
                                                  ? AppColors.danger
                                                  : AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        'Disponible: S/ ${account.availableCredit.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── MODAL PARA CREAR O EDITAR CUENTA DE CRÉDITO ────────────────────────────────
class _CreateCreditAccountModal extends StatefulWidget {
  final VoidCallback onAccountSaved;
  final CreditAccountModel?
  accountToEdit; // NUEVO: Si es nulo, creamos; si tiene datos, editamos.

  const _CreateCreditAccountModal({
    required this.onAccountSaved,
    this.accountToEdit,
  });

  @override
  State<_CreateCreditAccountModal> createState() =>
      _CreateCreditAccountModalState();
}

class _CreateCreditAccountModalState extends State<_CreateCreditAccountModal> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _matches = [];

  String? _selectedProfileId;
  String? _selectedProfileName;

  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    // NUEVO: Si estamos editando, prellenamos los campos
    if (_isEditing) {
      _selectedProfileId = widget.accountToEdit!.partnerId;
      _selectedProfileName = widget.accountToEdit!.partnerName;
      _searchCtrl.text = _selectedProfileName!;
      _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _limitCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_selectedProfileId != null) {
      setState(() {
        _selectedProfileId = null;
        _selectedProfileName = null;
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _searchClients(query),
    );
  }

  Future<void> _searchClients(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _matches = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, document_number')
          .or('full_name.ilike.%$text%,document_number.ilike.%$text%')
          .limit(5);

      if (mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    setState(() {
      _selectedProfileId = client['id'] as String;
      _selectedProfileName = client['full_name'] as String;
      _searchCtrl.text = _selectedProfileName!;
      _matches = [];
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _saveAccount() async {
    if (_selectedProfileId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un cliente primero.',
        type: SnackbarType.error,
      );
      return;
    }

    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (limitVal <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un límite de crédito válido mayor a 0.',
        type: SnackbarType.error,
      );
      return;
    }

    // Validar que el nuevo límite no sea menor a la deuda actual del cliente
    if (_isEditing && limitVal < widget.accountToEdit!.currentDebt) {
      AppSnackbar.show(
        context,
        message:
            'El nuevo límite no puede ser menor a su deuda actual (S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}).',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final adminResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (adminResp != null) adminProfileId = adminResp['id'] as String;
      }

      if (_isEditing) {
        // ACTUALIZAR CUENTA EXISTENTE
        await _supabase
            .from('customer_credits')
            .update({'credit_limit': limitVal})
            .eq('id', widget.accountToEdit!.creditId);
      } else {
        // CREAR NUEVA CUENTA
        await _supabase.from('customer_credits').insert({
          'profile_id': _selectedProfileId,
          'credit_limit': limitVal,
          'created_by': adminProfileId,
        });
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              _isEditing
                  ? 'Límite de crédito actualizado.'
                  : 'Línea de crédito aprobada con éxito.',
          type: SnackbarType.success,
        );
        widget.onAccountSaved();
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.code == '23505') {
          AppSnackbar.show(
            context,
            message: 'Este cliente ya tiene una cuenta de crédito creada.',
            type: SnackbarType.error,
          );
        } else {
          AppSnackbar.show(
            context,
            message: 'Error de BD: ${e.message}',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted)
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing
                ? 'Editar Límite de Crédito'
                : 'Aprobar Línea de Crédito',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Buscador de Cliente
          const Text(
            'Cliente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color:
                  _isEditing
                      ? Colors.grey.shade100
                      : AppColors.bg, // Apariencia de bloqueado
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedProfileId != null
                        ? AppColors.teal
                        : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              enabled: !_isEditing, // Bloquear si estamos editando
              style: TextStyle(
                color:
                    _isEditing ? Colors.grey.shade600 : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o DNI...',
                prefixIcon: Icon(
                  _selectedProfileId != null
                      ? Icons.check_circle_rounded
                      : Icons.search_rounded,
                  color:
                      _selectedProfileId != null
                          ? AppColors.teal
                          : AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_matches.isNotEmpty && _selectedProfileId == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _matches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = _matches[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      client['full_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Doc: ${client['document_number'] ?? 'N/A'}',
                    ),
                    onTap: () => _selectClient(client),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Límite de Crédito
          const Text(
            'Límite de Crédito (S/)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 500.00',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botón Guardar
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      _isEditing
                          ? 'Actualizar Límite'
                          : 'Crear Cuenta de Crédito',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── MODAL PARA REGISTRAR ABONO / PAGO ───────────────────────────────────────
class _RegisterPaymentModal extends StatefulWidget {
  final CreditAccountModel account;
  final VoidCallback onPaymentSaved;

  const _RegisterPaymentModal({
    required this.account,
    required this.onPaymentSaved,
  });

  @override
  State<_RegisterPaymentModal> createState() => _RegisterPaymentModalState();
}

class _RegisterPaymentModalState extends State<_RegisterPaymentModal> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'EFECTIVO';
  bool _isSaving = false;

  static const _paymentMethods = [
    'EFECTIVO',
    'YAPE',
    'PLIN',
    'TRANSFERENCIA',
    'OTRO',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un monto válido mayor a 0.',
        type: SnackbarType.error,
      );
      return;
    }
    if (amount > widget.account.currentDebt) {
      AppSnackbar.show(
        context,
        message:
            'El abono no puede superar la deuda actual (S/ ${widget.account.currentDebt.toStringAsFixed(2)}).',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final resp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (resp != null) adminProfileId = resp['id'] as String;
      }

      // 1. Insertar movimiento de tipo PAYMENT
      await _supabase.from('credit_movements').insert({
        'credit_id': widget.account.creditId,
        'movement_type': 'PAYMENT',
        'amount': amount,
        'payment_method': _paymentMethod,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'created_by': adminProfileId,
      });

      // 2. Actualizar deuda en customer_credits
      final newDebt = (widget.account.currentDebt - amount).clamp(
        0.0,
        double.infinity,
      );
      await _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.account.creditId);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Pago registrado con éxito.',
          type: SnackbarType.success,
        );
        widget.onPaymentSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar Abono / Pago',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.account.partnerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Indicador de deuda actual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Deuda actual',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'S/ ${widget.account.currentDebt.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monto del abono
          const Text(
            'Monto del abono (S/)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 50.00',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Método de pago (chips)
          const Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _paymentMethods.map((method) {
                  final selected = _paymentMethod == method;
                  return GestureDetector(
                    onTap: () => setState(() => _paymentMethod = method),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : AppColors.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.teal : AppColors.border,
                        ),
                      ),
                      child: Text(
                        method,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),

          // Notas opcionales
          const Text(
            'Notas (opcional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej. Pago parcial de factura #123...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botón guardar
          ElevatedButton(
            onPressed: _isSaving ? null : _savePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Guardar Pago',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
