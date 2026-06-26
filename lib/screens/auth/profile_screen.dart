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

  bool _isEditing = false;
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
      setState(() => _isEditing = false);
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
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SizedBox(
                    height: double.infinity,
                    child: RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: () async {
                        await provider.fetchUserProfile();
                        // Also might fetch wallet balance if provider handles it?
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: ProfileHeaderSection(
                              displayName:
                                  provider.fullName.isEmpty
                                      ? 'Usuario'
                                      : provider.fullName,
                              userRole: provider.userRole,
                              email: email,
                              walletBalance: walletBalance,
                              avatarUrl: provider.avatarUrl,
                              imageBytes: provider.imageBytes,
                              isEditing: _isEditing,
                              onPickImage: _pickImage,
                              onEditToggle:
                                  () => setState(() {
                                    if (_isEditing) {
                                      // Cancelar edición revierte los valores
                                      _nameCtrl.text = provider.fullName;
                                      _phoneCtrl.text = provider.phone;
                                      _docNumCtrl.text =
                                          provider.documentNumber;
                                      _docType = provider.documentType;
                                      provider.setImageBytes(null);
                                    }
                                    _isEditing = !_isEditing;
                                  }),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),

                          if (!widget.openedFromAdmin)
                            SliverToBoxAdapter(
                              child: Column(
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
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    child:
                                        _isEditing
                                            ? Column(
                                              key: const ValueKey('editMode'),
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _sectionLabelInline(
                                                  'Editar datos personales',
                                                ),
                                                Stack(
                                                  children: [
                                                    ProfileEditFormSection(
                                                      nameCtrl: _nameCtrl,
                                                      phoneCtrl: _phoneCtrl,
                                                      docNumCtrl: _docNumCtrl,
                                                      docType: _docType,
                                                      onDocTypeChanged:
                                                          (v) => setState(
                                                            () => _docType = v,
                                                          ),
                                                      onSave:
                                                          provider.isSaving
                                                              ? () {}
                                                              : _saveProfile,
                                                    ),
                                                    if (provider.isSaving)
                                                      const Positioned.fill(
                                                        child: ColoredBox(
                                                          color: Colors.white54,
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 14),
                                                _sectionLabelInline(
                                                  'Seguridad',
                                                ),
                                                PasswordChangeCard(
                                                  newPasswordCtrl:
                                                      _newPasswordCtrl,
                                                  confirmPasswordCtrl:
                                                      _confirmPasswordCtrl,
                                                  isUpdating:
                                                      provider
                                                          .isUpdatingPassword,
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
                                                  'Información de cuenta',
                                                ),
                                                ProfileReadOnlyInfoSection(
                                                  email:
                                                      email.isEmpty
                                                          ? 'Sin correo'
                                                          : email,
                                                  userRole: provider.userRole,
                                                  fullName: provider.fullName,
                                                  phone: provider.phone,
                                                  docType:
                                                      provider.documentType,
                                                  docNum:
                                                      provider.documentNumber,
                                                ),
                                              ],
                                            ),
                                  ),

                                  const SizedBox(height: 20),

                                  ProfileActionButtonsSection(
                                    isAdmin:
                                        provider.userRole == 'Administrador',
                                    openedFromAdmin: widget.openedFromAdmin,
                                    onToggleView: () {
                                      if (widget.openedFromAdmin) {
                                        context.go('/customer');
                                      } else {
                                        context.go('/admin');
                                      }
                                    },
                                    onSignOut: () async {
                                      final authProvider =
                                          context.read<AuthProvider>();
                                      authProvider.clearSession();
                                      try {
                                        await provider.signOut();
                                      } catch (e) {
                                        debugPrint('Logout error: $e');
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
