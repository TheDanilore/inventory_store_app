import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_access_section.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_action_bar.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_personal_section.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_roles_section.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_status_section.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_summary_header.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_warehouse_section.dart';

class UserFormScreen extends StatelessWidget {
  final String? initialRole;
  final UserEntity? existingUser;

  const UserFormScreen({super.key, this.initialRole, this.existingUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserFormCubit>()..loadWarehouses(),
      child: _UserFormContent(
        initialRole: initialRole,
        existingUser: existingUser,
      ),
    );
  }
}

class _UserFormContent extends StatefulWidget {
  final String? initialRole;
  final UserEntity? existingUser;

  const _UserFormContent({this.initialRole, this.existingUser});

  @override
  State<_UserFormContent> createState() => _UserFormContentState();
}

class _UserFormContentState extends State<_UserFormContent> {
  static const double _wideBreakpoint = 900;
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _docCtrl;

  // Estados locales de selección
  String _docType = 'DNI';
  late Set<String> _selectedRoles;
  bool _isActive = true;
  bool _obscurePassword = true;
  String? _selectedWarehouseId;

  // Detección reactiva de cambios sin disparar rebuilds de todo el árbol
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);
  late final String _initName;
  late final String _initEmail;
  late final String _initPhone;
  late final String _initDoc;
  late final String _initDocType;
  late final bool _initActive;
  late final Set<String> _initRoles;
  String? _initWarehouseId;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.existingUser?.fullName ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.existingUser?.email ?? '');
    _passwordCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: widget.existingUser?.phone ?? '');
    _docCtrl = TextEditingController(
      text: widget.existingUser?.documentNumber ?? '',
    );

    final initialRoles = <String>{};
    if (_isEditing) {
      _docType = widget.existingUser?.documentType ?? 'DNI';
      _isActive = widget.existingUser?.isActive ?? true;
      initialRoles.addAll(widget.existingUser?.allRoles ?? []);
    }
    if (initialRoles.isEmpty) {
      final defaultRole = widget.initialRole ?? AppRoles.employee;
      initialRoles.add(defaultRole);
    }
    _selectedRoles = initialRoles;

    _selectedWarehouseId = widget.existingUser?.warehouseId;
    _initWarehouseId = _selectedWarehouseId;

    // Snapshot inicial para comparar modificaciones
    _initName = _nameCtrl.text;
    _initEmail = _emailCtrl.text;
    _initPhone = _phoneCtrl.text;
    _initDoc = _docCtrl.text;
    _initDocType = _docType;
    _initActive = _isActive;
    _initRoles = {...initialRoles};

    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _phoneCtrl,
      _docCtrl,
    ]) {
      c.addListener(_syncDirty);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _phoneCtrl,
      _docCtrl,
    ]) {
      c.removeListener(_syncDirty);
    }
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
    _isDirty.dispose();
    super.dispose();
  }

  bool _computeDirty() {
    return _nameCtrl.text != _initName ||
        _emailCtrl.text != _initEmail ||
        _phoneCtrl.text != _initPhone ||
        _docCtrl.text != _initDoc ||
        _passwordCtrl.text.isNotEmpty ||
        _docType != _initDocType ||
        _isActive != _initActive ||
        _selectedWarehouseId != _initWarehouseId ||
        _selectedRoles.length != _initRoles.length ||
        !_selectedRoles.containsAll(_initRoles);
  }

  void _syncDirty() {
    final d = _computeDirty();
    if (d != _isDirty.value) {
      _isDirty.value = d;
    }
  }

  void _onDocTypeChanged(String? val) {
    if (val == null || val == _docType) return;
    var text = _docCtrl.text;
    if (val == 'DNI' || val == 'RUC') {
      text = text.replaceAll(RegExp(r'\D'), '');
    } else {
      text = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }
    final max = val == 'DNI' ? 8 : (val == 'RUC' ? 11 : 15);
    if (text.length > max) text = text.substring(0, max);

    setState(() {
      _docType = val;
    });
    if (text != _docCtrl.text) _docCtrl.text = text;
    _syncDirty();
  }

  void _generatePassword() {
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const symbols = '!@#\$%&*?';
    const all = lower + upper + digits + symbols;
    final random = Random.secure();
    String pick(String s) => s[random.nextInt(s.length)];

    final generated =
        (<String>[
          pick(lower),
          pick(upper),
          pick(digits),
          pick(symbols),
          ...List.generate(8, (_) => pick(all)),
        ]..shuffle(random)).join();

    _passwordCtrl.text = generated;
    setState(() => _obscurePassword = false);

    Clipboard.setData(ClipboardData(text: generated));
    AppSnackbar.show(
      context,
      message: 'Contraseña generada y copiada al portapapeles',
      type: SnackbarType.success,
    );
    _syncDirty();
  }

  void _toggleRole(String r) {
    if (_selectedRoles.contains(r)) {
      if (_selectedRoles.length > 1) {
        setState(() {
          _selectedRoles.remove(r);
        });
        _syncDirty();
      } else {
        AppSnackbar.show(
          context,
          message: 'El usuario debe tener al menos un rol asignado.',
          type: SnackbarType.warning,
        );
      }
    } else {
      setState(() {
        _selectedRoles.add(r);
      });
      _syncDirty();
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos marcados antes de continuar.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_selectedRoles.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Debes seleccionar al menos un rol.',
        type: SnackbarType.warning,
      );
      return;
    }

    final primaryRole = _selectedRoles.first;
    context.read<UserFormCubit>().saveUser(
      id: widget.existingUser?.id,
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text.trim(),
      role: primaryRole,
      roles: _selectedRoles.toList(),
      phone: _phoneCtrl.text.trim(),
      documentType: _docType,
      documentNumber: _docCtrl.text.trim(),
      isActive: _isActive,
      warehouseId: _selectedWarehouseId,
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('¿Descartar los cambios?'),
            content: const Text(
              'Hay información sin guardar. Si sales ahora, se perderá.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Seguir editando'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Descartar'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _handleCancel() async {
    if (_isDirty.value) {
      final discard = await _confirmDiscard();
      if (!discard || !mounted) return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/users');
    }
  }

  Widget _spaced(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserFormCubit, UserFormState>(
      listener: (context, state) {
        if (state is UserFormSuccess) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.success,
          );

          // Revalidación silenciosa en background para UsersCubit (SWR)
          try {
            sl<UsersCubit>()
              ..fetchUsers(forceRefresh: true)
              ..fetchCounts();
          } catch (_) {}

          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/users');
          }
        } else if (state is UserFormError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is UserFormLoading;

        return ValueListenableBuilder<bool>(
          valueListenable: _isDirty,
          builder: (context, isDirty, _) {
            return AdminLayout(
              title: _isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: PopScope(
                canPop: !isDirty,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _handleCancel();
                },
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= _wideBreakpoint;
                      final maxWidth = wide ? 1040.0 : 640.0;
                      final hPad = wide ? 32.0 : 16.0;

                      final mainSections = <Widget>[
                        UserFormPersonalSection(
                          nameCtrl: _nameCtrl,
                          docCtrl: _docCtrl,
                          phoneCtrl: _phoneCtrl,
                          docType: _docType,
                          onDocTypeChanged: _onDocTypeChanged,
                        ),
                        UserFormAccessSection(
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          isEditing: _isEditing,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          onGeneratePassword: _generatePassword,
                          onSubmitted: _onSave,
                        ),
                      ];

                      final asideSections = <Widget>[
                        UserFormRolesSection(
                          selectedRoles: _selectedRoles,
                          onToggleRole: _toggleRole,
                        ),
                        UserFormWarehouseSection(
                          selectedWarehouseId: _selectedWarehouseId,
                          onWarehouseChanged: (val) {
                            setState(() {
                              _selectedWarehouseId = val;
                            });
                            _syncDirty();
                          },
                        ),
                        if (_isEditing)
                          UserFormStatusSection(
                            isActive: _isActive,
                            onToggleActive: (v) {
                              setState(() {
                                _isActive = v;
                              });
                              _syncDirty();
                            },
                          ),
                      ];

                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxWidth,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      UserFormSummaryHeader(
                                        nameCtrl: _nameCtrl,
                                        emailCtrl: _emailCtrl,
                                        isEditing: _isEditing,
                                        selectedRoles: _selectedRoles,
                                      ),
                                      const SizedBox(height: 20),
                                      if (wide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _spaced(mainSections),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              flex: 2,
                                              child: _spaced(asideSections),
                                            ),
                                          ],
                                        )
                                      else
                                        _spaced([
                                          ...mainSections,
                                          ...asideSections,
                                        ]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          UserFormActionBar(
                            isLoading: isLoading,
                            isEditing: _isEditing,
                            wide: wide,
                            maxWidth: maxWidth,
                            hPad: hPad,
                            isDirtyListenable: _isDirty,
                            onCancel: _handleCancel,
                            onSave: _onSave,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
