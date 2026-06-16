import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/models/profile_address_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _profileId;
  List<ProfileAddressEntry> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadProfileAndAddresses();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _buildAddressLine(Map<String, dynamic> address) {
    final department = (address['department'] ?? '').toString().trim();
    final province = (address['province'] ?? '').toString().trim();
    final district = (address['district'] ?? '').toString().trim();
    final reference = (address['reference'] ?? '').toString().trim();
    final location = '$department / $province / $district';
    return reference.isEmpty ? location : '$location - Ref: $reference';
  }

  ProfileAddressEntry _toAddressEntry(Map<String, dynamic> address) {
    return ProfileAddressEntry(
      id: address['id'].toString(),
      addressLine: _buildAddressLine(address),
      reference:
          (address['reference'] ?? '').toString().trim().isEmpty
              ? null
              : (address['reference'] ?? '').toString().trim(),
      department: (address['department'] ?? '').toString().trim(),
      province: (address['province'] ?? '').toString().trim(),
      district: (address['district'] ?? '').toString().trim(),
      isDefault: address['is_default'] == true,
    );
  }

  Map<String, String?>? _parseAddressPreview(String preview) {
    final clean = preview.trim();
    if (clean.isEmpty) return null;
    final parts = clean.split(' - ');
    final locationPieces = parts.first.trim().split(' / ');
    if (locationPieces.length < 3) return null;
    final reference =
        parts.length > 1
            ? parts.sublist(1).join(' - ').replaceFirst('Ref: ', '').trim()
            : null;
    return {
      'department': locationPieces[0].trim(),
      'province': locationPieces[1].trim(),
      'district': locationPieces[2].trim(),
      'reference': (reference == null || reference.isEmpty) ? null : reference,
      'address_line': clean,
    };
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadProfileAndAddresses() async {
    if (mounted) setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .single();
      final profileId = profile['id']?.toString();
      if (profileId == null) throw Exception('No se encontró el perfil.');
      final response = await _supabase
          .from('user_addresses')
          .select(
            'id, department, province, district, reference, is_default, created_at',
          )
          .eq('profile_id', profileId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _profileId = profileId;
        _addresses = List<Map<String, dynamic>>.from(
          response,
        ).map(_toAddressEntry).toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudieron cargar las direcciones: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAddresses() async {
    if (_profileId == null) {
      await _loadProfileAndAddresses();
      return;
    }
    try {
      final response = await _supabase
          .from('user_addresses')
          .select(
            'id, department, province, district, reference, is_default, created_at',
          )
          .eq('profile_id', _profileId!)
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(
          response,
        ).map(_toAddressEntry).toList(growable: false);
      });
    } catch (_) {}
  }

  Future<void> _openAddressEditor({
    Map<String, dynamic>? existingAddress,
  }) async {
    if (_profileId == null) return;
    final queryParam =
        existingAddress == null
            ? ''
            : '?initialAddress=${Uri.encodeComponent(_buildAddressLine(existingAddress))}';

    final result = await context.push<String>(
      '/customer/address/config$queryParam',
    );
    if (!mounted || result == null) return;
    final parsed = _parseAddressPreview(result);
    if (parsed == null) {
      AppSnackbar.show(
        context,
        message: 'No se pudo leer la dirección guardada.',
        type: SnackbarType.error,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (existingAddress != null) {
        await _supabase
            .from('user_addresses')
            .update({
              'department': parsed['department'],
              'province': parsed['province'],
              'district': parsed['district'],
              'reference': parsed['reference'],
              'address_line': parsed['address_line'],
            })
            .eq('id', existingAddress['id']);
      } else {
        await _supabase.from('user_addresses').insert({
          'profile_id': _profileId,
          'department': parsed['department'],
          'province': parsed['province'],
          'district': parsed['district'],
          'reference': parsed['reference'],
          'address_line': parsed['address_line'],
          'is_default': _addresses.isEmpty,
        });
      }
      await _refreshAddresses();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            existingAddress == null
                ? 'Dirección agregada con éxito.'
                : 'Dirección actualizada con éxito.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar la dirección: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultAddress(ProfileAddressEntry address) async {
    if (_profileId == null) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('user_addresses')
          .update({'is_default': false})
          .eq('profile_id', _profileId!);
      await _supabase
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', address.id);
      await _refreshAddresses();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Dirección principal actualizada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo cambiar la dirección principal: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(ProfileAddressEntry address) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar dirección',
      message: '¿Seguro que deseas eliminar esta dirección?',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.from('user_addresses').delete().eq('id', address.id);
      await _refreshAddresses();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Dirección eliminada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo eliminar la dirección: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis direcciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _addresses.isEmpty
                          ? 'Agrega tu domicilio para recibir tus compras'
                          : '${_addresses.length} guardada${_addresses.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(ProfileAddressEntry address) {
    final isMain = address.isDefault;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color:
            isMain ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isMain
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
          width: isMain ? 1.5 : 1,
        ),
        // 1. LA SOMBRA SE QUEDA AFUERA
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // 2. MATERIAL E INKWELL ADENTRO PARA HOVER Y MANITA DE LA TARJETA
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Opcional: acción al tocar toda la tarjeta
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono + textos + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            isMain
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isMain
                            ? Icons.location_on_rounded
                            : Icons.location_on_outlined,
                        color:
                            isMain
                                ? AppColors.primary
                                : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  address.district,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (isMain)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Principal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${address.department}, ${address.province}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (address.reference != null &&
                              address.reference!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address.reference!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Acciones
                Row(
                  children: [
                    if (!isMain)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _setDefaultAddress(address),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Fijar como principal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    _iconAction(
                      icon: Icons.edit_outlined,
                      color: AppColors.info,
                      onTap:
                          () => _openAddressEditor(
                            existingAddress: {
                              'id': address.id,
                              'department': address.department,
                              'province': address.province,
                              'district': address.district,
                              'reference': address.reference,
                              'is_default': address.isDefault,
                            },
                          ),
                    ),
                    const SizedBox(width: 8),
                    _iconAction(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: () => _deleteAddress(address),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => _openAddressEditor(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
          label: const Text(
            'Agregar nueva dirección',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      title: 'Mis Direcciones',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: false,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
              : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refreshAddresses,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),
                    if (_addresses.isNotEmpty) ...[
                      ..._addresses.map(_buildAddressCard),
                      _buildAddButton(),
                    ] else ...[
                      const SizedBox(height: 24),
                      AppEmptyState(
                        icon: Icons.location_off_outlined,
                        title: 'Aún no tienes direcciones',
                        message:
                            'Agrega tu domicilio para recibir tus compras más rápido.',
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _openAddressEditor(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_location_alt_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Agregar primera dirección',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
