import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/screens/customer/customer_main_screen.dart';
import 'package:inventory_store_app/screens/customer/points_screen.dart';
import 'package:inventory_store_app/screens/customer/orders_screen.dart';
import 'package:inventory_store_app/screens/customer/wishlist_screen.dart';
import 'package:inventory_store_app/screens/customer/address_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/screens/auth/login_screen.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';

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
  final _supabase = Supabase.instance.client;
  String _userRole = 'Cargando...';
  bool _isLoading = true;
  bool _isEditing = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docNumCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String _docType = 'DNI';
  String? _profileId;
  String? _avatarUrl;
  Uint8List? _imageBytes;
  bool _isUpdatingPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
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

  // ─── Data & Actions ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // 1. Leemos los bytes originales
      final bytesOriginales = await pickedFile.readAsBytes();
      // 2. Comprimimos
      final bytesOptimizados = await _optimizarImagen(bytesOriginales);
      // 3. Guardamos en el estado
      setState(() => _imageBytes = bytesOptimizados);
    }
  }

  Future<void> _loadUserAddresses(String profileId) async {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data =
            await _supabase
                .from('profiles')
                .select(
                  'id, role, full_name, phone, document_type, document_number, avatar_url',
                )
                .eq('auth_user_id', user.id)
                .single();
        setState(() {
          _profileId = data['id']?.toString();
          _userRole =
              data['role'] == AppRoles.admin ? 'Administrador' : 'Cliente';
          _nameCtrl.text = data['full_name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _docNumCtrl.text = data['document_number'] ?? '';
          _avatarUrl = data['avatar_url'];
          _docType =
              ['DNI', 'RUC', 'CE', 'PASAPORTE'].contains(data['document_type'])
                  ? data['document_type']
                  : 'DNI';
          _isLoading = false;
        });
        if (_profileId != null) await _loadUserAddresses(_profileId!);
      } catch (e) {
        setState(() {
          _userRole = 'Cliente';
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      String? finalAvatarUrl = _avatarUrl;
      String? oldAvatarUrl; // Para guardar la url vieja temporalmente

      if (_imageBytes != null) {
        oldAvatarUrl = _avatarUrl; // Respaldamos la vieja por si acaso

        final fileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        finalAvatarUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      // Actualizamos la base de datos
      await _supabase
          .from('profiles')
          .update({
            'full_name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'document_type': _docType,
            'document_number': _docNumCtrl.text.trim(),
            if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
          })
          .eq('auth_user_id', user.id);

      // NUEVO: Si todo salió bien y había una imagen vieja, la borramos del bucket
      if (_imageBytes != null &&
          oldAvatarUrl != null &&
          oldAvatarUrl.contains('/public/avatars/')) {
        final oldPath = oldAvatarUrl.split('/public/avatars/').last;
        if (oldPath.isNotEmpty) {
          await _supabase.storage.from('avatars').remove([oldPath]);
        }
      }

      setState(() {
        _avatarUrl = finalAvatarUrl;
        _isEditing = false;
        _imageBytes =
            null; // IMPORTANTE: limpiar bytes para evitar re-subidas accidentales
      });

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Perfil actualizado con éxito',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    setState(() => _isUpdatingPassword = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Contraseña actualizada con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cambiar contraseña: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true); // Bloquea la UI

    await _supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, __, ___) => const LoginScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  Future<Uint8List> _optimizarImagen(Uint8List bytesOriginales) async {
    // 1. Si pesa menos de 250 KB, pasa directo.
    if (bytesOriginales.lengthInBytes < 250 * 1024) {
      return bytesOriginales;
    }

    try {
      // 2. Intentamos comprimir nativamente
      final bytesComprimidos = await FlutterImageCompress.compressWithList(
        bytesOriginales,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      // A veces si falla silenciosamente devuelve un arreglo vacío
      if (bytesComprimidos.isNotEmpty &&
          bytesComprimidos.lengthInBytes < bytesOriginales.lengthInBytes) {
        return bytesComprimidos; // ¡Éxito!
      }
    } catch (e) {
      debugPrint('Error interno de compresión: $e');
      // NUEVO: Mostrar alerta en pantalla para saber por qué falla
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al comprimir: $e',
          backgroundColor: Colors.red,
        );
      }
    }

    // Fallback de seguridad: devuelve la original si todo lo demás falla
    return bytesOriginales;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Retornamos un loader fluido en lugar del texto estático
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final walletBalance = context.watch<WalletProvider>().balance ?? 0;

    return CustomerLayout(
      onTabSelected: widget.onTabSelected,
      title: 'Mi Perfil',
      currentIndex: 2,
      showBackButton: widget.openedFromAdmin,
      showProfileIcon: false,
      showBottomNav: !widget.openedFromAdmin,
      showCartIcon: false,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero header ──────────────────────────────────────
                    ProfileHeaderSection(
                      displayName:
                          _nameCtrl.text.isEmpty ? 'Usuario' : _nameCtrl.text,
                      userRole: _userRole,
                      email: user.email ?? '',
                      walletBalance: walletBalance,
                      avatarUrl: _avatarUrl,
                      imageBytes: _imageBytes,
                      isEditing: _isEditing,
                      onPickImage: _pickImage,
                      onEditToggle:
                          () => setState(() => _isEditing = !_isEditing),
                    ),

                    const SizedBox(height: 8),

                    // ── Quick actions grid ────────────────────────────────
                    if (!widget.openedFromAdmin) ...[
                      _sectionLabel('Accesos rápidos'),
                      ProfileQuickActionGrid(
                        items: [
                          ProfileQuickActionItem(
                            title: 'Monedas',
                            value: 'Canjear ',
                            icon: Icons.stars_rounded,
                            color: AppColors.gold,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PointsScreen(),
                                  ),
                                ),
                          ),
                          ProfileQuickActionItem(
                            title: 'Pedidos',
                            value: 'Ver historial',
                            icon: Icons.receipt_long_rounded,
                            color: AppColors.info,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const CustomerOrdersScreen(),
                                  ),
                                ),
                          ),
                          ProfileQuickActionItem(
                            title: 'Direcciones',
                            value: 'Ver direcciones',
                            icon: Icons.location_on_rounded,
                            color: AppColors.success,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const AddressManagementScreen(),
                                  ),
                                ),
                          ),
                          ProfileQuickActionItem(
                            title: 'Deseos',
                            value: 'Ver wishlist',
                            icon: Icons.favorite_rounded,
                            color: AppColors.accent,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WishlistScreen(),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 4),

                    // ── Datos / edición ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isEditing) ...[
                            _sectionLabelInline('Editar datos personales'),
                            ProfileEditFormSection(
                              nameCtrl: _nameCtrl,
                              phoneCtrl: _phoneCtrl,
                              docNumCtrl: _docNumCtrl,
                              docType: _docType,
                              onDocTypeChanged:
                                  (v) => setState(() => _docType = v),
                              onSave: _saveProfile,
                            ),
                            const SizedBox(height: 14),
                            _sectionLabelInline('Seguridad'),
                            _PasswordCard(
                              newPasswordCtrl: _newPasswordCtrl,
                              confirmPasswordCtrl: _confirmPasswordCtrl,
                              isUpdating: _isUpdatingPassword,
                              onSave: _changePassword,
                            ),
                          ] else ...[
                            _sectionLabelInline('Información de cuenta'),
                            ProfileReadOnlyInfoSection(
                              email: user.email ?? 'Sin correo',
                              userRole: _userRole,
                              fullName:
                                  _nameCtrl.text.isEmpty
                                      ? 'No registrado'
                                      : _nameCtrl.text,
                              phone:
                                  _phoneCtrl.text.isEmpty
                                      ? 'No registrado'
                                      : _phoneCtrl.text,
                              docType: _docType,
                              docNum:
                                  _docNumCtrl.text.isEmpty
                                      ? 'No registrado'
                                      : _docNumCtrl.text,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── Botones de acción ─────────────────────────
                          ProfileActionButtonsSection(
                            isAdmin: _userRole == 'Administrador',
                            openedFromAdmin: widget.openedFromAdmin,
                            onToggleView:
                                () => Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (context, __, ___) =>
                                            widget.openedFromAdmin
                                                ? const CustomerMainScreen()
                                                : const AdminCatalogScreen(),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                ),
                            onSignOut: _signOut,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
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

// ─── Header Section ───────────────────────────────────────────────────────────

class ProfileHeaderSection extends StatelessWidget {
  final String displayName;
  final String userRole;
  final String email;
  final int walletBalance;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final bool isEditing;
  final VoidCallback? onPickImage;
  final VoidCallback? onEditToggle;

  const ProfileHeaderSection({
    super.key,
    required this.displayName,
    required this.userRole,
    required this.email,
    required this.walletBalance,
    required this.avatarUrl,
    required this.imageBytes,
    required this.isEditing,
    this.onPickImage,
    this.onEditToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              children: [
                // Avatar row
                Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: isEditing ? onPickImage : null,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.primary,
                              backgroundImage:
                                  imageBytes != null
                                      ? MemoryImage(imageBytes!)
                                          as ImageProvider
                                      : (avatarUrl != null
                                          ? NetworkImage(avatarUrl!)
                                          : null),
                              child:
                                  (imageBytes == null && avatarUrl == null)
                                      ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      )
                                      : null,
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name + role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              userRole.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Edit button
                    if (onEditToggle != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onEditToggle,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  isEditing
                                      ? AppColors.accent.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.close_rounded
                                  : Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Wallet balance strip
                const SizedBox(height: 18),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PointsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            size: 18,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo de monedas',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '$walletBalance monedas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Grid ────────────────────────────────────────────────────────

class ProfileQuickActionItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ProfileQuickActionItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class ProfileQuickActionGrid extends StatelessWidget {
  final List<ProfileQuickActionItem> items;
  const ProfileQuickActionGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) => _QuickActionCard(item: items[index]),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final ProfileQuickActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: item.color,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Read-only info section ───────────────────────────────────────────────────

class ProfileReadOnlyInfoSection extends StatelessWidget {
  final String email;
  final String userRole;
  final String fullName;
  final String phone;
  final String docType;
  final String docNum;

  const ProfileReadOnlyInfoSection({
    super.key,
    required this.email,
    required this.userRole,
    required this.fullName,
    required this.phone,
    required this.docType,
    required this.docNum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          children: [
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              value: email,
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              label: 'Rol del sistema',
              value: userRole,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          children: [
            _InfoTile(
              icon: Icons.person_outline_rounded,
              label: 'Nombre completo',
              value: fullName,
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: phone,
            ),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'Documento ($docType)',
              value: docNum,
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppColors.border,
          ),
      ],
    );
  }
}

// ─── Edit Form Section ────────────────────────────────────────────────────────

class ProfileEditFormSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController docNumCtrl;
  final String docType;
  final ValueChanged<String> onDocTypeChanged;
  final VoidCallback onSave;

  const ProfileEditFormSection({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.docNumCtrl,
    required this.docType,
    required this.onDocTypeChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          AppTextField(
            controller: nameCtrl,
            label: 'Nombre Completo',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: phoneCtrl,
            label: 'Teléfono',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo Doc',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items:
                      ['DNI', 'RUC', 'CE', 'PASAPORTE']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) onDocTypeChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: docNumCtrl,
                  label: 'Nº Documento',
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Guardar cambios',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Password Card ────────────────────────────────────────────────────────────

class _PasswordCard extends StatelessWidget {
  final TextEditingController newPasswordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool isUpdating;
  final VoidCallback onSave;

  const _PasswordCard({
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.isUpdating,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: newPasswordCtrl,
            label: 'Nueva contraseña',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: confirmPasswordCtrl,
            label: 'Confirmar contraseña',
            icon: Icons.lock_reset_outlined,
            obscureText: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isUpdating ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon:
                  isUpdating
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                isUpdating ? 'Actualizando...' : 'Actualizar contraseña',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons Section ───────────────────────────────────────────────────

class ProfileActionButtonsSection extends StatelessWidget {
  final bool isAdmin;
  final bool openedFromAdmin;
  final VoidCallback onToggleView;
  final VoidCallback onSignOut;

  const ProfileActionButtonsSection({
    super.key,
    required this.isAdmin,
    required this.openedFromAdmin,
    required this.onToggleView,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin) ...[
          _ProfileActionTile(
            icon:
                openedFromAdmin
                    ? Icons.storefront_rounded
                    : Icons.admin_panel_settings_rounded,
            label:
                openedFromAdmin
                    ? 'Ver Tienda como Cliente'
                    : 'Volver a Vista Admin',
            color: AppColors.info,
            onTap: onToggleView,
          ),
          const SizedBox(height: 10),
        ],
        _ProfileActionTile(
          icon: Icons.logout_rounded,
          label: 'Cerrar Sesión',
          color: AppColors.error,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
