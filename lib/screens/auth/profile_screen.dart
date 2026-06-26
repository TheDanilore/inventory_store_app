import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/providers/profile_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/providers/auth_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_header_section.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_quick_action_grid.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_read_only_info_section.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_edit_form_section.dart';
import 'dart:ui';
import 'package:inventory_store_app/screens/auth/widgets/expandable_profile_card.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_action_buttons_section.dart';
import 'package:inventory_store_app/screens/auth/widgets/profile_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final bool openedFromAdmin;
  final ValueChanged<int>? onTabSelected;
  const ProfileScreen({
    super.key,
    this.openedFromAdmin = false,
    this.onTabSelected,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isPersonalDataExpanded = false;
  bool _isSecurityExpanded = false;
  String _docType = 'DNI';
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<ProfileProvider>();
    provider.fetchUserProfile().then((_) {
      if (mounted) {
        setState(() {
          _nameCtrl.text = provider.fullName;
          _phoneCtrl.text = provider.phone;
          _docNumCtrl.text = provider.documentNumber;
          _docType = provider.documentType;
          _hasInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _docNumCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (pickedFile != null) {
      final provider = context.read<ProfileProvider>();
      final bytesOriginales = await pickedFile.readAsBytes();
      final bytesOptimizados = await provider.optimizeImage(bytesOriginales);
      provider.setImageBytes(bytesOptimizados);
    }
  }

  Future<void> _saveProfile() async {
    final provider = context.read<ProfileProvider>();
    final success = await provider.saveProfile(
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      docType: _docType,
      docNum: _docNumCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isPersonalDataExpanded = false);
      AppSnackbar.show(
        context,
        message: 'Perfil actualizado con éxito',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'Error al actualizar el perfil.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Ingresa y confirma la nueva contraseña.',
        type: SnackbarType.error,
      );
      return;
    }
    if (newPassword != confirmPassword) {
      AppSnackbar.show(
        context,
        message: 'Las contraseñas no coinciden.',
        type: SnackbarType.error,
      );
      return;
    }
    if (newPassword.length < 8) {
      AppSnackbar.show(
        context,
        message: 'La contraseña debe tener al menos 8 caracteres.',
        type: SnackbarType.error,
      );
      return;
    }

    final provider = context.read<ProfileProvider>();
    final success = await provider.changePassword(newPassword);

    if (!mounted) return;

    if (success) {
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      setState(() => _isSecurityExpanded = false);
      AppSnackbar.show(
        context,
        message: 'Contraseña actualizada con éxito.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'Error al cambiar contraseña.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final walletBalance = context.watch<WalletProvider>().balance ?? 0;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return CustomerLayout(
      onTabSelected: widget.onTabSelected,
      title: 'Mi Perfil',
      currentIndex: 2,
      showBackButton: widget.openedFromAdmin,
      showProfileIcon: false,
      showBottomNav: !widget.openedFromAdmin,
      showCartIcon: false,
      body:
          provider.isLoading || !_hasInitialized
              ? const ProfileShimmer()
              : RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () async {
                  await provider.fetchUserProfile();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isTablet = constraints.maxWidth >= 750;

                      final headerSection = ProfileHeaderSection(
                        displayName:
                            provider.fullName.isEmpty
                                ? 'Usuario'
                                : provider.fullName,
                        userRole: provider.userRole,
                        email: email,
                        walletBalance: walletBalance,
                        avatarUrl: provider.avatarUrl,
                        imageBytes: provider.imageBytes,
                        isEditing: true, // Always show camera icon
                        onPickImage: _pickImage,
                        onEditToggle: null, // Removed toggle button
                      );

                      final quickActions =
                          widget.openedFromAdmin
                              ? const SizedBox.shrink()
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionLabel('Accesos rápidos'),
                                  ProfileQuickActionGrid(
                                    items: [
                                      ProfileQuickActionItem(
                                        title: 'Monedas',
                                        value: 'Canjear ',
                                        icon: Icons.stars_rounded,
                                        color: AppColors.gold,
                                        onTap:
                                            () => context.push(
                                              '/customer/points',
                                            ),
                                      ),
                                      ProfileQuickActionItem(
                                        title: 'Pedidos',
                                        value: 'Ver historial',
                                        icon: Icons.receipt_long_rounded,
                                        color: AppColors.info,
                                        onTap:
                                            () => context.push(
                                              '/customer/orders',
                                            ),
                                      ),
                                      ProfileQuickActionItem(
                                        title: 'Direcciones',
                                        value: 'Ver direcciones',
                                        icon: Icons.location_on_rounded,
                                        color: AppColors.success,
                                        onTap:
                                            () => context.push(
                                              '/customer/address',
                                            ),
                                      ),
                                      ProfileQuickActionItem(
                                        title: 'Deseos',
                                        value: 'Ver wishlist',
                                        icon: Icons.favorite_rounded,
                                        color: AppColors.accent,
                                        onTap:
                                            () => context.push(
                                              '/customer/wishlist',
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              );

                      final profileCards = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabelInline('Datos Personales'),
                          Stack(
                            children: [
                              ExpandableProfileCard(
                                title: 'Datos Personales',
                                icon: Icons.person_outline_rounded,
                                isExpanded: _isPersonalDataExpanded,
                                onToggle: () {
                                  setState(() {
                                    _isPersonalDataExpanded =
                                        !_isPersonalDataExpanded;
                                    if (_isPersonalDataExpanded) {
                                      _nameCtrl.text = provider.fullName;
                                      _phoneCtrl.text = provider.phone;
                                      _docNumCtrl.text =
                                          provider.documentNumber;
                                      _docType = provider.documentType;
                                    }
                                  });
                                },
                                collapsedChild: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ProfileReadOnlyInfoSection(
                                    email: email.isEmpty ? 'Sin correo' : email,
                                    userRole: provider.userRole,
                                    fullName: provider.fullName,
                                    phone: provider.phone,
                                    docType: provider.documentType,
                                    docNum: provider.documentNumber,
                                  ),
                                ),
                                expandedChild: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ProfileEditFormSection(
                                    nameCtrl: _nameCtrl,
                                    phoneCtrl: _phoneCtrl,
                                    docNumCtrl: _docNumCtrl,
                                    docType: _docType,
                                    onDocTypeChanged:
                                        (v) => setState(() => _docType = v),
                                    onSave:
                                        provider.isSaving
                                            ? () {}
                                            : _saveProfile,
                                  ),
                                ),
                              ),
                              if (provider.isSaving)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 4,
                                        sigmaY: 4,
                                      ),
                                      child: Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _sectionLabelInline('Seguridad'),
                          Stack(
                            children: [
                              ExpandableProfileCard(
                                title: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                isExpanded: _isSecurityExpanded,
                                onToggle: () {
                                  setState(() {
                                    _isSecurityExpanded = !_isSecurityExpanded;
                                  });
                                },
                                collapsedChild: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.password_rounded,
                                        size: 16,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '••••••••',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                expandedChild: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: PasswordChangeCard(
                                    newPasswordCtrl: _newPasswordCtrl,
                                    confirmPasswordCtrl: _confirmPasswordCtrl,
                                    isUpdating: provider.isUpdatingPassword,
                                    onSave: _changePassword,
                                  ),
                                ),
                              ),
                              if (provider.isUpdatingPassword)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 4,
                                        sigmaY: 4,
                                      ),
                                      child: Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );

                      final actionButtons = ProfileActionButtonsSection(
                        isAdmin: provider.userRole == 'Administrador',
                        openedFromAdmin: widget.openedFromAdmin,
                        onToggleView: () {
                          if (widget.openedFromAdmin) {
                            context.go('/customer');
                          } else {
                            context.go('/admin');
                          }
                        },
                        onSignOut: () async {
                          final authProvider = context.read<AuthProvider>();
                          authProvider.clearSession();
                          try {
                            await provider.signOut();
                          } catch (e) {
                            debugPrint('Logout error: $e');
                          }
                        },
                      );

                      if (isTablet) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [headerSection, quickActions],
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  24,
                                ),
                                child: Column(
                                  children: [
                                    profileCards,
                                    const SizedBox(height: 32),
                                    actionButtons,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          headerSection,
                          const SizedBox(height: 8),
                          quickActions,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: profileCards,
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: actionButtons,
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _sectionLabelInline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
