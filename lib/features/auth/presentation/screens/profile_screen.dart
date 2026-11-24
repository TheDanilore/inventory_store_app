import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/adaptive_modal_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/hover_shortcut_tooltip.dart';
import 'package:inventory_store_app/core/widgets/staggered_reveal.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/agronomic_avatar_picker_dialog.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_action_buttons_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_appearance_card.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_edit_form_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_header_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_read_only_info_section.dart';
import 'package:inventory_store_app/features/auth/presentation/widgets/profile/profile_shimmer.dart';

class ProfileScreen extends StatefulWidget {
  final bool openedFromAdmin;
  const ProfileScreen({super.key, this.openedFromAdmin = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
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

  bool _hasUnsavedChanges() {
    final user = context.read<AuthCubit>().state.currentUser;
    if (user == null) return false;
    final initialDocType =
        user.documentType.isEmpty ? 'DNI' : user.documentType;
    return _fullNameCtrl.text.trim() != user.fullName ||
        _phoneCtrl.text.trim() != user.phone ||
        _docNumCtrl.text.trim() != user.documentNumber ||
        _docType != initialDocType ||
        _selectedImageBytes != null ||
        _newPasswordCtrl.text.isNotEmpty ||
        _confirmPasswordCtrl.text.isNotEmpty;
  }

  void _enterEditMode() {
    _populateFields();
    setState(() => _isEditing = true);
  }

  void _exitEditMode() {
    setState(() {
      _isEditing = false;
      _selectedImageBytes = null;
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _populateFields();
    });
  }

  Future<void> _requestCancelEdit() async {
    if (!_isEditing) return;
    if (!_hasUnsavedChanges()) {
      _exitEditMode();
      return;
    }
    final discard = await _showDiscardDialog();
    if (discard == true && mounted) {
      _exitEditMode();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    // Guardar con modificador de plataforma (funciona incluso dentro de inputs)
    final isSaveModifier =
        kIsWeb ? isAlt : (AppShortcutLabels.isApple ? isMeta : isCtrl);
    if (_isEditing &&
        isSaveModifier &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveProfile();
      return KeyEventResult.handled;
    }

    // Escape: primero desenfoca input activo; luego sale de edición
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (FocusUtils.isInputFieldFocused()) {
        FocusManager.instance.primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      if (_isEditing) {
        _requestCancelEdit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // REGLA ESTRICTA: atajos single-key silenciados cuando un campo editable tiene foco
    if (FocusUtils.isInputFieldFocused() || isAlt || isCtrl || isMeta) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      AppFeedbackService.selectionClick();
      if (_isEditing) {
        _requestCancelEdit();
      } else {
        _enterEditMode();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      AppFeedbackService.selectionClick();
      ThemeCircularWave.switchTheme(context);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      AppFeedbackService.lightImpact();
      _openAvatarPicker();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openAvatarPicker() async {
    final user = context.read<AuthCubit>().state.currentUser;
    final initial =
        (user != null && user.fullName.isNotEmpty)
            ? user.fullName[0].toUpperCase()
            : 'U';

    await AgronomicAvatarPickerDialog.show(
      context,
      currentAvatarUrl: user?.avatarUrl,
      userInitial: initial,
      onAvatarSelected: (newAvatarUrl, imageBytes) async {
        final cubit = context.read<AuthCubit>();
        final currentUser = cubit.state.currentUser;
        if (currentUser == null) return;

        if (imageBytes != null) {
          if (_isEditing) {
            setState(() {
              _selectedImageBytes = imageBytes;
            });
          } else {
            final success = await cubit.updateProfile(
              currentUser,
              imageBytes: imageBytes,
            );
            if (success && mounted) {
              AppSnackbar.show(
                context,
                message: 'Foto de perfil actualizada exitosamente',
                type: SnackbarType.success,
              );
            }
          }
        } else if (newAvatarUrl != null) {
          final updatedUser = currentUser.copyWith(
            avatarUrl: newAvatarUrl.isEmpty ? '' : newAvatarUrl,
          );
          final success = await cubit.updateProfile(updatedUser);
          if (success && mounted) {
            if (_isEditing) {
              setState(() {
                _selectedImageBytes = null;
              });
            }
            AppSnackbar.show(
              context,
              message:
                  newAvatarUrl.isEmpty
                      ? 'Avatar restablecido a iniciales'
                      : 'Avatar agrícola actualizado',
              type: SnackbarType.success,
            );
          }
        }
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos obligatorios del formulario.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<AuthCubit>();
    final currentUser = cubit.state.currentUser;
    if (currentUser == null) return;

    final updatedUser = AuthUserEntity(
      id: currentUser.id,
      authUserId: currentUser.authUserId,
      email: currentUser.email,
      role: currentUser.role,
      fullName: _fullNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      documentType: _docType,
      documentNumber: _docNumCtrl.text.trim(),
      avatarUrl: currentUser.avatarUrl,
      isActive: currentUser.isActive,
      roles: currentUser.roles,
      permissions: currentUser.permissions,
      warehouseId: currentUser.warehouseId,
      warehouseName: currentUser.warehouseName,
      birthdate: currentUser.birthdate,
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

  Future<void> _changePassword() async {
    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Ingresa las contraseñas requeridas',
        type: SnackbarType.warning,
      );
      return;
    }
    if (newPass.length < 8) {
      AppSnackbar.show(
        context,
        message: 'La contraseña debe tener mínimo 8 caracteres',
        type: SnackbarType.warning,
      );
      return;
    }
    if (newPass != confirmPass) {
      AppSnackbar.show(
        context,
        message: 'Las contraseñas no coinciden',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<AuthCubit>();
    final success = await cubit.changePassword(newPass);
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

  Future<bool?> _showDiscardDialog() {
    return AdaptiveModalSheet.show<bool>(
      context,
      maxWidth: 440,
      showDragHandle: false,
      barrierLabel: 'Descartar cambios',
      builder: (modalCtx) {
        final isDialog = AdaptiveModalSheet.isDialogMode(modalCtx);
        final warningColor = AppColors.warningText(modalCtx);

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDialog) const AppSheetDragHandle(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  isDialog ? 22 : 10,
                  24,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: warningColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.edit_off_rounded,
                            color: warningColor,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿Descartar cambios?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.txtPrimary(modalCtx),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tienes cambios de edición sin guardar. ¿Deseas salir sin guardar los datos?',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.txtSecondary(modalCtx),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.txtSecondary(modalCtx),
                            side: BorderSide(
                              color: AppColors.brdSubtle(modalCtx),
                            ),
                            minimumSize: const Size(120, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Continuar'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(modalCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(120, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Descartar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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

  Future<bool> _onWillPop() async {
    if (!_isEditing) return true;
    if (!_hasUnsavedChanges()) {
      _exitEditMode();
      return true;
    }

    final shouldPop = await _showDiscardDialog();
    if (shouldPop == true && mounted) {
      _exitEditMode();
    }
    return shouldPop ?? false;
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas salir y cerrar tu sesión?',
      confirmText: 'Cerrar Sesión',
      confirmColor: AppColors.error,
    );
    if (confirmed == true && mounted) {
      await context.read<AuthCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    const isLoyaltyEnabled = false;
    const walletBalance = 0;

    return BlocConsumer<AuthCubit, AuthState>(
      buildWhen:
          (previous, current) =>
              previous.currentUser != current.currentUser ||
              previous.viewState != current.viewState,
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
            backgroundColor: AppColors.bg(context),
            body: const ProfileShimmer(),
          );
        }

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return Scaffold(
            backgroundColor: AppColors.bg(context),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary(context),
              ),
            ),
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
            backgroundColor: AppColors.bg(context),
            body: Focus(
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  if (width >= 1024) {
                    return _buildSplitWorkspaceLayout(
                      context,
                      user,
                      avatarUrl,
                      isLoading,
                      isLoyaltyEnabled,
                      walletBalance,
                      isDesktop: true,
                    );
                  }
                  if (width >= 600) {
                    return _buildSplitWorkspaceLayout(
                      context,
                      user,
                      avatarUrl,
                      isLoading,
                      isLoyaltyEnabled,
                      walletBalance,
                      isDesktop: false,
                    );
                  }
                  return _buildMobileLayout(
                    context,
                    user,
                    avatarUrl,
                    isLoading,
                    isLoyaltyEnabled,
                    walletBalance,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tablet (600–1023px) & Desktop/Web (>= 1024px) Split Workspace ─────────
  Widget _buildSplitWorkspaceLayout(
    BuildContext context,
    AuthUserEntity user,
    String? avatarUrl,
    bool isLoading,
    bool isLoyaltyEnabled,
    int walletBalance, {
    required bool isDesktop,
  }) {
    final horizontalGap = isDesktop ? 24.0 : 20.0;
    final outerPadding = isDesktop ? 24.0 : 20.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(outerPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Identidad + Apariencia + Sesión
              Expanded(
                flex: isDesktop ? 34 : 38,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggeredReveal(
                      index: 0,
                      child: ProfileHeaderSection(
                        displayName: user.fullName,
                        userRole: user.role,
                        email: user.email,
                        walletBalance: walletBalance,
                        avatarUrl: avatarUrl,
                        imageBytes: _selectedImageBytes,
                        isEditing: _isEditing,
                        isLoyaltyEnabled: isLoyaltyEnabled,
                        isTablet: !isDesktop,
                        warehouseName: user.warehouseName,
                        isActive: user.isActive,
                        onPickImage: _openAvatarPicker,
                        onEditToggle: () {
                          if (_isEditing) {
                            _requestCancelEdit();
                          } else {
                            _enterEditMode();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    StaggeredReveal(
                      index: 1,
                      child: ProfileAppearanceCard(compact: !isDesktop),
                    ),
                    const SizedBox(height: 14),
                    StaggeredReveal(
                      index: 2,
                      child: ProfileActionButtonsSection(
                        isAdmin: user.role == AppRoles.admin,
                        onSignOut: _confirmAndSignOut,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: horizontalGap),
              // Columna Derecha: Datos / Edición y Seguridad
              Expanded(
                flex: isDesktop ? 66 : 62,
                child: StaggeredReveal(
                  index: 1,
                  child: _buildDetailSwitcher(
                    context,
                    user,
                    isLoading,
                    isDenseDesktop: isDesktop,
                    isWideLayout: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Móvil (< 600px): Apple iOS HIG 1 Columna con SafeArea ─────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    AuthUserEntity user,
    String? avatarUrl,
    bool isLoading,
    bool isLoyaltyEnabled,
    int walletBalance,
  ) {
    return RefreshIndicator(
      color: AppColors.brandPrimary(context),
      backgroundColor: AppColors.surfElevated(context),
      onRefresh: () async {
        AppFeedbackService.lightImpact();
        await context.read<AuthCubit>().checkSession();
      },
      child: SafeArea(
        top: false,
        bottom: true,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StaggeredReveal(
                    index: 0,
                    child: ProfileHeaderSection(
                      displayName: user.fullName,
                      userRole: user.role,
                      email: user.email,
                      walletBalance: walletBalance,
                      avatarUrl: avatarUrl,
                      imageBytes: _selectedImageBytes,
                      isEditing: _isEditing,
                      isLoyaltyEnabled: isLoyaltyEnabled,
                      warehouseName: user.warehouseName,
                      isActive: user.isActive,
                      onPickImage: _openAvatarPicker,
                      onEditToggle: () {
                        if (_isEditing) {
                          _requestCancelEdit();
                        } else {
                          _enterEditMode();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  StaggeredReveal(
                    index: 1,
                    child: const ProfileAppearanceCard(compact: true),
                  ),
                  const SizedBox(height: 20),
                  StaggeredReveal(
                    index: 2,
                    child: _buildDetailSwitcher(
                      context,
                      user,
                      isLoading,
                      isDenseDesktop: false,
                      isWideLayout: false,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StaggeredReveal(
                    index: 3,
                    child: ProfileActionButtonsSection(
                      isAdmin: user.role == AppRoles.admin,
                      onSignOut: _confirmAndSignOut,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSwitcher(
    BuildContext context,
    AuthUserEntity user,
    bool isLoading, {
    required bool isDenseDesktop,
    required bool isWideLayout,
  }) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedSize(
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration:
            disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 280),
        reverseDuration:
            disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder:
            (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
        transitionBuilder: (child, animation) {
          if (disableAnimations) return child;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child:
            _isEditing
                ? Column(
                  key: const ValueKey('profileEditMode'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabelInline(
                      context,
                      'Editar Datos Personales',
                      badge: 'Editando',
                    ),
                    Stack(
                      children: [
                        ProfileEditFormSection(
                          formKey: _formKey,
                          nameCtrl: _fullNameCtrl,
                          phoneCtrl: _phoneCtrl,
                          docNumCtrl: _docNumCtrl,
                          docType: _docType,
                          onDocTypeChanged:
                              (val) => setState(() => _docType = val),
                          onSave: _saveProfile,
                          onCancel: _requestCancelEdit,
                          isWideLayout: isWideLayout,
                        ),
                        if (isLoading)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                child: Container(
                                  color: AppColors.glassSurface(context),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.brandPrimary(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabelInline(context, 'Seguridad y Contraseña'),
                    PasswordChangeCard(
                      newPasswordCtrl: _newPasswordCtrl,
                      confirmPasswordCtrl: _confirmPasswordCtrl,
                      isUpdating: isLoading,
                      onSave: _changePassword,
                      isWideLayout: isWideLayout,
                    ),
                  ],
                )
                : Column(
                  key: const ValueKey('profileReadMode'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabelInline(
                      context,
                      'Información de cuenta',
                      onEditAction: _enterEditMode,
                    ),
                    ProfileReadOnlyInfoSection(
                      email: user.email.isEmpty ? 'Sin correo' : user.email,
                      userRole: user.role,
                      fullName: user.fullName,
                      phone: user.phone,
                      docType: user.documentType,
                      docNum: user.documentNumber,
                      warehouseName: user.warehouseName,
                      isDenseDesktop: isDenseDesktop,
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _sectionLabelInline(
    BuildContext context,
    String text, {
    String? badge,
    VoidCallback? onEditAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.txtPrimary(context),
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimarySoft(context),
                ),
              ),
            ),
          if (onEditAction != null)
            HoverShortcutTooltip(
              message: 'Editar información',
              shortcut: 'E',
              child: TextButton.icon(
                onPressed: () {
                  AppFeedbackService.selectionClick();
                  onEditAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimarySoft(context),
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text(
                  'Editar',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
