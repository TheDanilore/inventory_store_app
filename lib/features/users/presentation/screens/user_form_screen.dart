import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class UserFormScreen extends StatelessWidget {
  final String? initialRole;
  final UserEntity? existingUser;

  const UserFormScreen({super.key, this.initialRole, this.existingUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserFormCubit>(),
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
  /// A partir de este ancho el formulario se divide en dos columnas.
  static const double _wideBreakpoint = 900;

  final _formKey = GlobalKey<FormState>();

  // Controladores
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _docCtrl;

  // Estados locales
  String _docType = 'DNI';
  late Set<String> _selectedRoles;
  bool _isActive = true;
  bool _obscurePassword = true;
  String? _selectedWarehouseId;
  List<WarehouseEntity> _warehouses = [];
  bool _isLoadingWarehouses = false;

  // Detección de cambios sin guardar
  bool _dirty = false;
  late final String _initName;
  late final String _initEmail;
  late final String _initPhone;
  late final String _initDoc;
  late final String _initDocType;
  late final bool _initActive;
  late final Set<String> _initRoles;
  String? _initWarehouseId;

  bool get _isEditing => widget.existingUser != null;

  List<_RoleInfo> get _roleInfos => [
    _RoleInfo(
      id: AppRoles.admin,
      title: 'Admin',
      subtitle: 'Acceso total al sistema',
      icon: Icons.admin_panel_settings_outlined,
      color: Colors.indigo,
    ),
    _RoleInfo(
      id: AppRoles.cashier,
      title: 'Cajero',
      subtitle: 'Punto de venta y ventas',
      icon: Icons.point_of_sale_rounded,
      color: AppColors.teal,
    ),
    _RoleInfo(
      id: AppRoles.warehouseKeeper,
      title: 'Almacén',
      subtitle: 'Inventario y kardex',
      icon: Icons.inventory_2_outlined,
      color: Colors.purple.shade600,
    ),
    _RoleInfo(
      id: AppRoles.employee,
      title: 'Empleado',
      subtitle: 'Operaciones generales',
      icon: Icons.badge_outlined,
      color: Colors.orange.shade700,
    ),
  ];

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
    _loadWarehouses();

    // Snapshot inicial para saber si hay cambios sin guardar.
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

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    try {
      final whs = await sl<WarehousesRepository>().getActiveWarehouses();
      if (mounted) {
        setState(() {
          _warehouses = whs;
          _isLoadingWarehouses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingWarehouses = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  // ─── Estado "sucio" ────────────────────────────────────────────

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
    if (d != _dirty && mounted) setState(() => _dirty = d);
  }

  // ─── Validaciones ──────────────────────────────────────────────

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $fieldName';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el correo electrónico';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Revisa el formato (ej: usuario@dominio.com)';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (_isEditing) {
      if (v != null && v.isNotEmpty && v.length < 6) {
        return 'Mínimo 6 caracteres';
      }
      return null;
    }
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _validateDocument(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Número de documento opcional
    }
    final clean = value.trim();
    if (_docType == 'DNI') {
      if (clean.length != 8) return 'El DNI debe tener 8 dígitos';
    } else if (_docType == 'RUC') {
      if (clean.length != 11) return 'El RUC debe tener 11 dígitos';
    } else if (clean.length < 4) {
      return 'Mínimo 4 caracteres';
    }
    return null;
  }

  int get _documentMaxLength =>
      _docType == 'DNI' ? 8 : (_docType == 'RUC' ? 11 : 15);

  List<TextInputFormatter> get _documentFormatters {
    if (_docType == 'DNI' || _docType == 'RUC') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_documentMaxLength),
      ];
    }
    return [
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      LengthLimitingTextInputFormatter(_documentMaxLength),
    ];
  }

  // ─── Acciones ──────────────────────────────────────────────────

  void _onDocTypeChanged(String? val) {
    if (val == null || val == _docType) return;
    // Adapta el número ya escrito al nuevo tipo para evitar valores inválidos.
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
      _dirty = true;
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

    // Garantiza al menos un carácter de cada tipo y mezcla el resultado.
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
  }

  void _toggleRole(String r) {
    if (_selectedRoles.contains(r)) {
      if (_selectedRoles.length > 1) {
        setState(() {
          _selectedRoles.remove(r);
          _dirty = _computeDirty();
        });
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
        _dirty = _computeDirty();
      });
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
    if (_dirty) {
      final discard = await _confirmDiscard();
      if (!discard || !mounted) return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/users');
    }
  }

  // ─── Build ─────────────────────────────────────────────────────

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

        return AdminLayout(
          title: _isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
          showBackButton: true,
          showProfileButton: false,
          showDrawerButton: false,
          body: PopScope(
            canPop: !_dirty,
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
                    _buildPersonalSection(),
                    _buildAccessSection(),
                  ];
                  final asideSections = <Widget>[
                    _buildRolesSection(),
                    _buildWarehouseSection(),
                    if (_isEditing) _buildStatusSection(),
                  ];

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryHeader(),
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
                      _buildActionBar(
                        isLoading: isLoading,
                        wide: wide,
                        maxWidth: maxWidth,
                        hPad: hPad,
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

  // ─── Cabecera con vista previa en vivo ─────────────────────────

  Widget _buildSummaryHeader() {
    return ListenableBuilder(
      listenable: Listenable.merge([_nameCtrl, _emailCtrl]),
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final email = _emailCtrl.text.trim();
        final roles =
            _roleInfos.where((r) => _selectedRoles.contains(r.id)).toList();

        final title =
            name.isNotEmpty
                ? name
                : (_isEditing ? 'Colaborador' : 'Nuevo colaborador');
        final subtitle =
            email.isNotEmpty
                ? email
                : (_isEditing
                    ? 'Modifica los datos, los roles y el estado de acceso.'
                    : 'Completa los datos para crear su cuenta de acceso.');

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialsAvatar(name: name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ModePill(isEditing: _isEditing),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final r in roles) _RoleChip(info: r)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Secciones ─────────────────────────────────────────────────

  Widget _buildPersonalSection() {
    return _SectionCard(
      title: 'Datos personales',
      subtitle: 'Identificación y contacto del colaborador.',
      icon: Icons.badge_rounded,
      children: [
        _CustomTextField(
          controller: _nameCtrl,
          label: 'Nombre completo o razón social',
          required: true,
          hint: 'Ej. Juan Pérez',
          textCapitalization: TextCapitalization.words,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: (v) => _required(v, 'el nombre'),
        ),
        const SizedBox(height: 18),
        _TwoColumns(
          breakpoint: 480,
          gap: 16,
          left: _CustomTextField(
            controller: _docCtrl,
            label: 'Documento de identidad',
            optional: true,
            hint:
                _docType == 'DNI'
                    ? '8 dígitos'
                    : _docType == 'RUC'
                    ? '11 dígitos'
                    : 'N° de documento',
            prefix: _buildDocTypePicker(),
            keyboardType:
                (_docType == 'DNI' || _docType == 'RUC')
                    ? TextInputType.number
                    : TextInputType.text,
            inputFormatters: _documentFormatters,
            textInputAction: TextInputAction.next,
            validator: _validateDocument,
          ),
          right: _CustomTextField(
            controller: _phoneCtrl,
            label: 'Teléfono o WhatsApp',
            optional: true,
            hint: 'Ej. 987654321',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocTypePicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _docType,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.grey.shade600,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items:
                  const ['DNI', 'RUC', 'CE', 'PAS']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
              onChanged: _onDocTypeChanged,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 22, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _buildAccessSection() {
    return _SectionCard(
      title: 'Acceso al sistema',
      subtitle: 'Con estas credenciales el colaborador iniciará sesión.',
      icon: Icons.lock_person_rounded,
      children: [
        _CustomTextField(
          controller: _emailCtrl,
          label: 'Correo electrónico',
          required: !_isEditing,
          hint: 'ejemplo@correo.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          readOnly: _isEditing,
          textInputAction: TextInputAction.next,
          helper: _isEditing ? 'El correo no se puede modificar.' : null,
          suffixIcon:
              _isEditing
                  ? Tooltip(
                    message: 'El correo electrónico no puede ser alterado',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  )
                  : null,
          validator: _isEditing ? null : _validateEmail,
        ),
        const SizedBox(height: 18),
        _CustomTextField(
          controller: _passwordCtrl,
          label: _isEditing ? 'Nueva contraseña' : 'Contraseña',
          required: !_isEditing,
          optional: _isEditing,
          hint: 'Escribe o genera una contraseña',
          icon: Icons.key_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onSave(),
          validator: _validatePassword,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey.shade600,
              size: 20,
            ),
            onPressed:
                () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _passwordCtrl,
                builder: (context, _) {
                  if (_passwordCtrl.text.isEmpty) {
                    return Text(
                      _isEditing
                          ? 'Déjala vacía para mantener la actual.'
                          : 'Mínimo 6 caracteres.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }
                  return _PasswordStrength(password: _passwordCtrl.text);
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Genera una clave segura y la copia al portapapeles',
              child: TextButton.icon(
                onPressed: _generatePassword,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Generar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRolesSection() {
    return _SectionCard(
      title: 'Roles y permisos',
      subtitle: 'Puedes asignar uno o varios según sus responsabilidades.',
      icon: Icons.shield_outlined,
      children: [
        _AdaptiveGrid(
          minItemWidth: 220,
          spacing: 10,
          children: [
            for (final r in _roleInfos)
              _RoleCard(
                info: r,
                isSelected: _selectedRoles.contains(r.id),
                onTap: () => _toggleRole(r.id),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarehouseSection() {
    return _SectionCard(
      title: 'Almacén asignado',
      subtitle: 'Almacén o sucursal por defecto para este colaborador.',
      icon: Icons.storefront_outlined,
      children: [
        if (_isLoadingWarehouses)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          DropdownButtonFormField<String?>(
            initialValue:
                _warehouses.any((w) => w.id == _selectedWarehouseId)
                    ? _selectedWarehouseId
                    : null,
            decoration: InputDecoration(
              labelText: 'Seleccionar almacén',
              hintText: 'Sin almacén asignado',
              prefixIcon: const Icon(Icons.warehouse_outlined, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Ninguno / Sin asignar'),
              ),
              ..._warehouses.map(
                (w) =>
                    DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _selectedWarehouseId = val;
                _dirty = _computeDirty();
              });
            },
          ),
      ],
    );
  }

  Widget _buildStatusSection() {
    final color = _isActive ? Colors.green.shade700 : Colors.red.shade700;
    return _SectionCard(
      title: 'Estado de la cuenta',
      subtitle: 'Controla si puede iniciar sesión.',
      icon: Icons.verified_user_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isActive ? 'Cuenta activa' : 'Cuenta inactiva',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isActive
                        ? 'Puede iniciar sesión y operar.'
                        : 'Acceso suspendido hasta reactivarla.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isActive,
              activeThumbColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  _isActive = v;
                  _dirty = _computeDirty();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  // ─── Barra de acciones fija ────────────────────────────────────

  Widget _buildActionBar({
    required bool isLoading,
    required bool wide,
    required double maxWidth,
    required double hPad,
  }) {
    final saveColor = _isEditing ? Colors.indigo.shade700 : AppColors.primary;

    final cancelButton = OutlinedButton(
      onPressed: isLoading ? null : _handleCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Cancelar',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );

    final saveButton = FilledButton(
      onPressed: isLoading ? null : _onSave,
      style: FilledButton.styleFrom(
        backgroundColor: saveColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child:
          isLoading
              ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.save_rounded : Icons.person_add_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Guardar cambios' : 'Crear colaborador',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child:
                wide
                    ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dirty
                                ? 'Tienes cambios sin guardar.'
                                : 'Los campos con * son obligatorios.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  _dirty
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        cancelButton,
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 200),
                          child: saveButton,
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(flex: 1, child: cancelButton),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: saveButton),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGETS DE APOYO
// ═══════════════════════════════════════════════════════════════════

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.grey.shade200),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

class _RoleInfo {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _RoleInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child:
          initials.isEmpty
              ? Icon(
                Icons.person_outline_rounded,
                size: 26,
                color: AppColors.primary.withValues(alpha: 0.7),
              )
              : Text(
                initials,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final bool isEditing;
  const _ModePill({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    final color = isEditing ? Colors.indigo.shade700 : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isEditing ? 'Edición' : 'Nuevo',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final _RoleInfo info;
  const _RoleChip({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 14, color: info.color),
          const SizedBox(width: 5),
          Text(
            info.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = info.color;
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      checked: isSelected,
      label: '${info.title}, ${info.subtitle}',
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.07) : Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? color.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    info.icon,
                    size: 22,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Casilla (no círculo): comunica que la selección es múltiple.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: radius, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// Dos columnas cuando hay espacio, una sola cuando no.
class _TwoColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double breakpoint;
  final double gap;

  const _TwoColumns({
    required this.left,
    required this.right,
    required this.breakpoint,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              SizedBox(width: gap),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, SizedBox(height: gap + 2), right],
        );
      },
    );
  }
}

/// Reparte los hijos en 1..n columnas según el ancho disponible.
class _AdaptiveGrid extends StatelessWidget {
  final double minItemWidth;
  final double spacing;
  final List<Widget> children;

  const _AdaptiveGrid({
    required this.minItemWidth,
    required this.spacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = max(
          1,
          ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  static int _level(String v) {
    if (v.length < 6) return 1;
    var s = 2;
    if (v.length >= 10) s++;
    final mixedCase =
        RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v);
    final digitOrSymbol =
        RegExp(r'[0-9]').hasMatch(v) || RegExp(r'[^A-Za-z0-9]').hasMatch(v);
    if (mixedCase && digitOrSymbol) s++;
    return min(s, 4);
  }

  @override
  Widget build(BuildContext context) {
    final level = _level(password);
    final colors = [
      Colors.red.shade500,
      Colors.orange.shade600,
      Colors.lightGreen.shade700,
      Colors.green.shade600,
    ];
    const labels = ['Muy corta', 'Débil', 'Buena', 'Segura'];
    final color = colors[level - 1];

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < level ? color : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          labels[level - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final bool required;
  final bool optional;
  final String hint;
  final String? helper;
  final IconData? icon;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const _CustomTextField({
    required this.controller,
    this.label,
    this.required = false,
    this.optional = false,
    required this.hint,
    this.helper,
    this.icon,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      if (required)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (optional) ...[
                const SizedBox(width: 6),
                Text(
                  'Opcional',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Colors.red.shade700,
            ),
            prefixIcon:
                prefix ??
                (icon != null
                    ? Icon(icon, size: 20, color: Colors.grey.shade500)
                    : null),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: _border(Colors.grey.shade300),
            enabledBorder: _border(Colors.grey.shade300),
            focusedBorder: _border(
              readOnly ? Colors.grey.shade300 : AppColors.primary,
              1.6,
            ),
            errorBorder: _border(Colors.red.shade600),
            focusedErrorBorder: _border(Colors.red.shade600, 1.6),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
