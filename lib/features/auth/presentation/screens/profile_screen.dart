import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_edit_form_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_read_only_info_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_action_buttons_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_quick_access_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_shimmer.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/wallet_cubit.dart';

class ProfileScreen extends StatefulWidget {
  final bool openedFromAdmin;
  const ProfileScreen({super.key, required this.openedFromAdmin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  Uint8List? _selectedImageBytes;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumCtrl = TextEditingController();
  String _docType = 'DNI';

  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    final user = context.read<AuthCubit>().state.currentUser;
    if (user != null) {
      _fullNameCtrl.text = user.fullName;
      _phoneCtrl.text = user.phone;
      _docNumCtrl.text = user.documentNumber;
      _docType = user.documentType.isEmpty ? 'DNI' : user.documentType;
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _docNumCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    ImageSource? source;

    if (isMobile) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Foto de Perfil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                    title: const Text('Tomar Foto'),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                    title: const Text('Seleccionar de Galería'),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      source = ImageSource.gallery;
    }

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    }
  }

  void _saveProfile() async {
    final cubit = context.read<AuthCubit>();
    final currentUser = cubit.state.currentUser;
    if (currentUser == null) return;

    final updatedUser = UserEntity(
      id: currentUser.id,
      email: currentUser.email,
      role: currentUser.role,
      fullName: _fullNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      documentType: _docType,
      documentNumber: _docNumCtrl.text.trim(),
      avatarUrl: currentUser.avatarUrl,
      isActive: currentUser.isActive,
    );

    final success = await cubit.updateProfile(
      updatedUser,
      imageBytes: _selectedImageBytes,
    );

    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Perfil actualizado exitosamente',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
        _selectedImageBytes = null;
      });
    }
  }

  void _changePassword() async {
    if (_newPasswordCtrl.text.isEmpty || _confirmPasswordCtrl.text.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Ingresa las contraseñas requeridas',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      AppSnackbar.show(
        context,
        message: 'Las contraseñas no coinciden',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<AuthCubit>();
    final success = await cubit.changePassword(_newPasswordCtrl.text);
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Contraseña actualizada exitosamente',
        type: SnackbarType.success,
      );
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      setState(() => _isEditing = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isEditing) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Descartar cambios?'),
            content: const Text(
              'Tienes cambios de edición sin guardar. ¿Deseas salir sin guardar los datos?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Continuar editando',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (shouldPop == true && mounted) {
      setState(() {
        _isEditing = false;
        _selectedImageBytes = null;
        _populateFields();
      });
    }
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isLoyaltyGlobal = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final isLoyaltyCustomer = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyCustomerVisible ?? false,
    );
    final isLoyaltyEnabled =
        widget.openedFromAdmin
            ? isLoyaltyGlobal
            : (isLoyaltyGlobal && isLoyaltyCustomer);

    final walletBalance =
        widget.openedFromAdmin
            ? 0
            : context.select<WalletCubit, int>((w) => w.state.balance ?? 0);

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.viewState == ViewState.error && state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final user = state.currentUser;
        final isLoading = state.viewState == ViewState.loading;
        final avatarUrl = user?.avatarUrl;

        if (isLoading && state.authStatus == AuthStatus.initial) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const ProfileShimmer(),
          );
        }

        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: Text('Inicia sesión para ver tu perfil')),
          );
        }

        return PopScope(
          canPop: !_isEditing,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) Navigator.pop(context);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                if (isDesktop) {
                  return _buildDesktopSplitLayout(
                    context,
                    user,
                    avatarUrl,
                    isLoading,
                    isLoyaltyEnabled,
                    walletBalance,
                  );
                }

                return _buildMobileSingleColumnLayout(
                  context,
                  user,
                  avatarUrl,
                  isLoading,
                  isLoyaltyEnabled,
                  walletBalance,
                  constraints,
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Layout Desktop: Split Profile Dashboard (2 Columnas width >= 900) ──────
  Widget _buildDesktopSplitLayout(
    BuildContext context,
    UserEntity user,
    String? avatarUrl,
    bool isLoading,
    bool isLoyaltyEnabled,
    int walletBalance,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Resumen y Acciones (35% Ancho)
              Expanded(
                flex: 35,
                child: Column(
                  children: [
                    ProfileHeaderSection(
                      displayName: user.fullName,
                      userRole: user.role,
                      email: user.email,
                      walletBalance: walletBalance,
                      avatarUrl: avatarUrl,
                      imageBytes: _selectedImageBytes,
                      isEditing: _isEditing,
                      isLoyaltyEnabled: isLoyaltyEnabled,
                      onPickImage: _pickImage,
                      onEditToggle: () {
                        if (_isEditing) {
                          setState(() {
                            _isEditing = false;
                            _selectedImageBytes = null;
                            _populateFields();
                          });
                        } else {
                          setState(() => _isEditing = true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ProfileActionButtonsSection(
                      isAdmin: user.role == AppRoles.admin,
                      openedFromAdmin: widget.openedFromAdmin,
                      onToggleView: () {
                        if (widget.openedFromAdmin) {
                          context.go('/');
                        } else {
                          context.go('/admin');
                        }
                      },
                      onSignOut: () async {
                        await context.read<AuthCubit>().logout();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Columna Derecha: Datos y Seguridad (65% Ancho)
              Expanded(
                flex: 65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.openedFromAdmin && !_isEditing) ...[
                      ProfileQuickAccessSection(
                        isLoyaltyEnabled: isLoyaltyEnabled,
                      ),
                      const SizedBox(height: 20),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _isEditing
                              ? Column(
                                key: const ValueKey('desktopEditMode'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionLabelInline(
                                    context,
                                    'Editar Datos Personales',
                                  ),
                                  Stack(
                                    children: [
                                      ProfileEditFormSection(
                                        nameCtrl: _fullNameCtrl,
                                        phoneCtrl: _phoneCtrl,
                                        docNumCtrl: _docNumCtrl,
                                        docType: _docType,
                                        onDocTypeChanged:
                                            (val) => setState(
                                              () => _docType = val,
                                            ),
                                        onSave: _saveProfile,
                                      ),
                                      if (isLoading)
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 8,
                                                sigmaY: 8,
                                              ),
                                              child: Container(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _sectionLabelInline(context, 'Seguridad'),
                                  PasswordChangeCard(
                                    newPasswordCtrl: _newPasswordCtrl,
                                    confirmPasswordCtrl: _confirmPasswordCtrl,
                                    isUpdating: isLoading,
                                    onSave: _changePassword,
                                  ),
                                ],
                              )
                              : Column(
                                key: const ValueKey('desktopReadMode'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionLabelInline(
                                    context,
                                    'Información de cuenta',
                                  ),
                                  ProfileReadOnlyInfoSection(
                                    email:
                                        user.email.isEmpty
                                            ? 'Sin correo'
                                            : user.email,
                                    userRole: user.role,
                                    fullName: user.fullName,
                                    phone: user.phone,
                                    docType: user.documentType,
                                    docNum: user.documentNumber,
                                  ),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout Móvil / Tablet: 1 Columna Continua ──────────────────────────────
  Widget _buildMobileSingleColumnLayout(
    BuildContext context,
    UserEntity user,
    String? avatarUrl,
    bool isLoading,
    bool isLoyaltyEnabled,
    int walletBalance,
    BoxConstraints constraints,
  ) {
    final isTablet = constraints.maxWidth >= 700;
    final horizontalPadding =
        isTablet ? (constraints.maxWidth - 700) / 2 : 0.0;

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        await context.read<AuthCubit>().checkSession();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ProfileHeaderSection(
                  displayName: user.fullName,
                  userRole: user.role,
                  email: user.email,
                  walletBalance: walletBalance,
                  avatarUrl: avatarUrl,
                  imageBytes: _selectedImageBytes,
                  isEditing: _isEditing,
                  isLoyaltyEnabled: isLoyaltyEnabled,
                  onPickImage: _pickImage,
                  onEditToggle: () {
                    if (_isEditing) {
                      setState(() {
                        _isEditing = false;
                        _selectedImageBytes = null;
                        _populateFields();
                      });
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (!widget.openedFromAdmin && !_isEditing) ...[
                  ProfileQuickAccessSection(
                    isLoyaltyEnabled: isLoyaltyEnabled,
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child:
                        _isEditing
                            ? Column(
                              key: const ValueKey('editMode'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionLabelInline(
                                  context,
                                  'Editar Datos Personales',
                                ),
                                Stack(
                                  children: [
                                    ProfileEditFormSection(
                                      nameCtrl: _fullNameCtrl,
                                      phoneCtrl: _phoneCtrl,
                                      docNumCtrl: _docNumCtrl,
                                      docType: _docType,
                                      onDocTypeChanged:
                                          (val) =>
                                              setState(() => _docType = val),
                                      onSave: _saveProfile,
                                    ),
                                    if (isLoading)
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 8,
                                              sigmaY: 8,
                                            ),
                                            child: Container(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _sectionLabelInline(context, 'Seguridad'),
                                PasswordChangeCard(
                                  newPasswordCtrl: _newPasswordCtrl,
                                  confirmPasswordCtrl: _confirmPasswordCtrl,
                                  isUpdating: isLoading,
                                  onSave: _changePassword,
                                ),
                              ],
                            )
                            : Column(
                              key: const ValueKey('readMode'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionLabelInline(
                                  context,
                                  'Información de cuenta',
                                ),
                                ProfileReadOnlyInfoSection(
                                  email:
                                      user.email.isEmpty
                                          ? 'Sin correo'
                                          : user.email,
                                  userRole: user.role,
                                  fullName: user.fullName,
                                  phone: user.phone,
                                  docType: user.documentType,
                                  docNum: user.documentNumber,
                                ),
                              ],
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                ProfileActionButtonsSection(
                  isAdmin: user.role == AppRoles.admin,
                  openedFromAdmin: widget.openedFromAdmin,
                  onToggleView: () {
                    if (widget.openedFromAdmin) {
                      context.go('/');
                    } else {
                      context.go('/admin');
                    }
                  },
                  onSignOut: () async {
                    await context.read<AuthCubit>().logout();
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabelInline(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
