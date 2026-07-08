import 'dart:io';
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

import 'widgets/profile_header_section.dart';
import 'widgets/profile_edit_form_section.dart';
import 'widgets/profile_read_only_info_section.dart';

import 'widgets/profile_action_buttons_section.dart';

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

    final imageBytes = _selectedImage != null ? await _selectedImage!.readAsBytes() : null;

    final success = await cubit.updateProfile(updatedUser, imageBytes: imageBytes);
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
      AppSnackbar.show(context, message: 'Llena las contraseñas', type: SnackbarType.warning);
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      AppSnackbar.show(context, message: 'Las contraseñas no coinciden', type: SnackbarType.warning);
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
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.viewState == ViewState.error && state.errorMessage != null) {
           AppSnackbar.show(context, message: state.errorMessage!, type: SnackbarType.error);
        }
      },
      builder: (context, state) {
        final user = state.currentUser;
        final isLoading = state.viewState == ViewState.loading;
        final avatarUrl = user?.avatarUrl;

        return Scaffold(
          backgroundColor: AppColors.background,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
              ),
              onPressed: () => context.canPop() ? context.pop() : context.go(widget.openedFromAdmin ? '/admin' : '/customer'),
            ),
            actions: [
              if (user == null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isEditing
                        ? IconButton(
                            key: const ValueKey('cancelBtn'),
                            icon: const Icon(Icons.close_rounded, color: AppColors.error),
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _selectedImage = null;
                                _populateFields();
                              });
                            },
                          )
                        : IconButton(
                            key: const ValueKey('editBtn'),
                            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                            onPressed: () {
                              setState(() => _isEditing = true);
                            },
                          ),
                  ),
                ),
            ],
          ),
          body: user == null
              ? const Center(child: Text('Inicia sesión para ver tu perfil'))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      ProfileHeaderSection(
                        displayName: user.fullName,
                        userRole: user.role,
                        email: user.email,
                        walletBalance: 0, // Ignored logic for now
                        avatarUrl: avatarUrl,
                        imageBytes: null, // we handle file directly, so just pass null
                        isEditing: _isEditing,
                        isLoyaltyEnabled: false,
                        onPickImage: _pickImage,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _isEditing
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionLabelInline(context, 'Editar Datos Personales'),
                                    Stack(
                                      children: [
                                        ProfileEditFormSection(
                                          nameCtrl: _fullNameCtrl,
                                          phoneCtrl: _phoneCtrl,
                                          docNumCtrl: _docNumCtrl,
                                          docType: _docType,
                                          onDocTypeChanged: (val) => setState(() => _docType = val),
                                          onSave: _saveProfile,
                                        ),
                                        if (isLoading)
                                          Positioned.fill(
                                            child: Container(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              child: const Center(child: CircularProgressIndicator()),
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
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionLabelInline(context, 'Información de cuenta'),
                                    ProfileReadOnlyInfoSection(
                                      email: user.email.isEmpty ? 'Sin correo' : user.email,
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
                            context.go('/customer');
                          } else {
                            context.go('/admin');
                          }
                        },
                        onSignOut: () async {
                          await context.read<AuthCubit>().logout();
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
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
