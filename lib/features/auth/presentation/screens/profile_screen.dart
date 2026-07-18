import 'dart:io';
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

import 'package:inventory_store_app/features/auth/presentation/widgets/profile_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile_edit_form_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile_read_only_info_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile_action_buttons_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile_quick_access_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile_shimmer.dart';

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
  File? _selectedImage;

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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
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

    final imageBytes =
        _selectedImage != null ? await _selectedImage!.readAsBytes() : null;

    final success = await cubit.updateProfile(
      updatedUser,
      imageBytes: imageBytes,
    );
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Perfil actualizado exitosamente',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
        _selectedImage = null;
      });
    }
  }

  void _changePassword() async {
    if (_newPasswordCtrl.text.isEmpty || _confirmPasswordCtrl.text.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Llena las contraseñas',
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

  @override
  Widget build(BuildContext context) {
    final appConfigState = context.watch<AppConfigCubit>().state;
    final isLoyaltyGlobal =
        appConfigState.businessInfo?.loyaltyGlobalEnabled ?? false;
    final isLoyaltyCustomer =
        appConfigState.businessInfo?.loyaltyCustomerVisible ?? false;
    final isLoyaltyEnabled =
        widget.openedFromAdmin
            ? isLoyaltyGlobal
            : (isLoyaltyGlobal && isLoyaltyCustomer);

    // En CustomerLayout usualmente está el WalletCubit.
    // En AdminLayout (openedFromAdmin = true) puede que no esté disponible.
    int walletBalance = 0;
    if (!widget.openedFromAdmin) {
      try {
        walletBalance = context.watch<WalletCubit>().state.balance ?? 0;
      } catch (_) {}
    }

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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
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
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          ProfileHeaderSection(
                            displayName: user.fullName,
                            userRole: user.role,
                            email: user.email,
                            walletBalance: walletBalance,
                            avatarUrl: avatarUrl,
                            imageBytes: null,
                            isEditing: _isEditing,
                            isLoyaltyEnabled: isLoyaltyEnabled,
                            onPickImage: _pickImage,
                            onEditToggle: () {
                              if (_isEditing) {
                                setState(() {
                                  _isEditing = false;
                                  _selectedImage = null;
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
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
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                    child: BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                        sigmaX: 8,
                                                        sigmaY: 8,
                                                      ),
                                                      child: Container(
                                                        color: Colors.white
                                                            .withValues(
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
                                          _sectionLabelInline(
                                            context,
                                            'Seguridad',
                                          ),
                                          PasswordChangeCard(
                                            newPasswordCtrl: _newPasswordCtrl,
                                            confirmPasswordCtrl:
                                                _confirmPasswordCtrl,
                                            isUpdating: isLoading,
                                            onSave: _changePassword,
                                          ),
                                        ],
                                      )
                                      : Column(
                                        key: const ValueKey('readMode'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
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
            },
          ),
        );
      },
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
