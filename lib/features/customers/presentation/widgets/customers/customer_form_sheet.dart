import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_form/customer_form_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_form/customer_form_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_credit_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_personal_info_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_status_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_wallet_section.dart';

/// Hoja modal adaptativa para crear o editar perfiles de clientes
class CustomerFormSheet extends StatelessWidget {
  final CustomerEntity? customer;
  final bool isDialog;

  const CustomerFormSheet({super.key, this.customer, this.isDialog = false});

  static Future<bool?> show(
    BuildContext context, {
    CustomerEntity? customer,
    VoidCallback? onSaved,
  }) async {
    final saved = await AdaptiveDetailSheet.show<bool>(
      context,
      desktopWidth: 580,
      breakpoint: 900,
      barrierLabel: 'Cerrar formulario de cliente',
      builder:
          (sheetCtx) => CustomerFormSheet(
            customer: customer,
            isDialog: AdaptiveDetailSheet.isSideSheet(sheetCtx),
          ),
    );
    if (saved == true) onSaved?.call();
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerFormCubit>(),
      child: _CustomerFormSheetContent(customer: customer, isDialog: isDialog),
    );
  }
}

class _CustomerFormSheetContent extends StatefulWidget {
  final CustomerEntity? customer;
  final bool isDialog;

  const _CustomerFormSheetContent({this.customer, this.isDialog = false});

  @override
  State<_CustomerFormSheetContent> createState() =>
      _CustomerFormSheetContentState();
}

class _CustomerFormSheetContentState extends State<_CustomerFormSheetContent> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumberCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _walletAdjustCtrl = TextEditingController(text: '0');

  // Estado del perfil
  String _docType = 'DNI';
  bool _isActive = true;

  // Estado de crédito (inicializado en Frame 0 para Zero-Shimmer)
  bool _hasCredit = true;
  bool _isUnlimited = true;
  bool _creditIsActive = true;
  bool _creditExistsInDb = false;
  String? _creditId;
  double _currentDebt = 0;

  // Billetera
  double _currentWalletBalance = 0;

  bool get _isEditing => widget.customer != null;

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
    if (c == null) {
      _hasCredit = true;
      _isUnlimited = true;
      return;
    }

    _nameCtrl.text = c.fullName;
    _phoneCtrl.text = c.phone ?? '';
    _docNumberCtrl.text = c.documentNumber ?? '';
    _docType = c.documentType ?? 'DNI';
    _isActive = c.isActive;
    _currentWalletBalance = c.walletBalance;

    // Zero-Shimmer: Renderizado instantáneo en Frame 0 desde la entidad existente
    _currentDebt = c.currentDebt;
    _hasCredit = c.creditLimit > 0 || c.currentDebt > 0;
    _isUnlimited = c.creditLimit <= 0 && _hasCredit;
    if (!_isUnlimited) {
      _creditLimitCtrl.text = c.creditLimit.toStringAsFixed(2);
    }
    _creditExistsInDb = c.creditLimit > 0 || c.currentDebt > 0;

    final initialCredit = CustomerCreditEntity(
      id: '',
      profileId: c.id,
      creditLimit: c.creditLimit,
      currentDebt: c.currentDebt,
      isActive: _hasCredit,
    );

    // Cargar con initialData y L1 Cache: sin spinners ni saltos visuales
    context.read<CustomerFormCubit>().loadCredit(
      c.id,
      initialData: initialCredit,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final delta = int.tryParse(_walletAdjustCtrl.text.trim()) ?? 0;
    final double newLimit =
        (_hasCredit && !_isUnlimited)
            ? (double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0)
            : 0.0;

    context.read<CustomerFormCubit>().save(
      customerId: widget.customer?.id,
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      documentNumber:
          _docNumberCtrl.text.trim().isEmpty
              ? null
              : _docNumberCtrl.text.trim(),
      documentType: _docType,
      isActive: _isActive,
      walletAdjustDelta: delta,
      currentWalletBalance: _currentWalletBalance,
      hasCredit: _hasCredit,
      creditExistsInDb: _creditExistsInDb,
      creditId: _creditId,
      creditIsActive: _creditIsActive,
      newCreditLimit: newLimit,
    );
  }

  void _onStateListener(BuildContext context, CustomerFormState state) {
    if (state is CustomerFormSuccess) {
      Navigator.pop(context, true);
    } else if (state is CustomerFormError) {
      AppSnackbar.show(
        context,
        message: state.message,
        type: SnackbarType.error,
      );
    } else if (state is CustomerFormCreditLoaded) {
      final account = state.creditAccount;
      if (account != null && mounted) {
        setState(() {
          _creditExistsInDb = true;
          _creditId = account.id;
          _creditIsActive = account.isActive;
          _hasCredit = account.isActive;
          _currentDebt = account.currentDebt;
          _isUnlimited = account.isUnlimited;
          if (!account.isUnlimited) {
            _creditLimitCtrl.text = account.creditLimit.toStringAsFixed(2);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return BlocListener<CustomerFormCubit, CustomerFormState>(
        listener: _onStateListener,
        child: _buildSheetBody(context, null),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) {
        return BlocListener<CustomerFormCubit, CustomerFormState>(
          listener: _onStateListener,
          child: _buildSheetBody(context, scrollCtrl),
        );
      },
    );
  }

  Widget _buildSheetBody(BuildContext context, ScrollController? scrollCtrl) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.loyaltyGlobalEnabled,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            widget.isDialog
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          if (!widget.isDialog)
            const AppSheetDragHandle()
          else
            const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
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

          // Formulario con secciones desacopladas
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 100),
                children: [
                  CustomerPersonalInfoSection(
                    nameCtrl: _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    docNumberCtrl: _docNumberCtrl,
                    docType: _docType,
                    onDocTypeChanged: (v) => setState(() => _docType = v),
                  ),
                  const SizedBox(height: 24),

                  CustomerStatusSection(
                    isActive: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 24),

                  if (_isEditing && isLoyaltyEnabled) ...[
                    CustomerWalletSection(
                      currentWalletBalance: _currentWalletBalance,
                      walletAdjustCtrl: _walletAdjustCtrl,
                    ),
                    const SizedBox(height: 24),
                  ],

                  CustomerCreditSection(
                    isEditing: _isEditing,
                    hasCredit: _hasCredit,
                    isUnlimited: _isUnlimited,
                    creditExistsInDb: _creditExistsInDb,
                    currentDebt: _currentDebt,
                    creditLimitCtrl: _creditLimitCtrl,
                    onHasCreditChanged: (v) => setState(() => _hasCredit = v),
                    onUnlimitedChanged: (v) => setState(() => _isUnlimited = v),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Footer con botón de guardado y rebuild granular
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
              child: BlocBuilder<CustomerFormCubit, CustomerFormState>(
                buildWhen:
                    (prev, curr) =>
                        (prev is CustomerFormSaving) !=
                        (curr is CustomerFormSaving),
                builder: (context, state) {
                  final isSaving = state is CustomerFormSaving;
                  return ElevatedButton(
                    onPressed: isSaving ? null : _save,
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
                        isSaving
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
