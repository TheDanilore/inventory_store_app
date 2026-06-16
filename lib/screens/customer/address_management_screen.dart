import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/profile_address_entry.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/providers/customer/customer_addresses_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/address/customer_address_card.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerAddressesProvider>().init();
    });
  }

  Future<void> _openAddressEditor(
    CustomerAddressesProvider provider, {
    ProfileAddressEntry? existingAddress,
  }) async {
    final queryParam =
        existingAddress == null
            ? ''
            : '?initialAddress=${Uri.encodeComponent(existingAddress.addressLine)}';

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

    try {
      await provider.saveAddress(
        existingAddress:
            existingAddress != null ? {'id': existingAddress.id} : null,
        parsedResult: parsed,
      );
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
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
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

  Future<void> _deleteAddress(
    CustomerAddressesProvider provider,
    ProfileAddressEntry address,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar dirección',
      message: '¿Seguro que deseas eliminar esta dirección?',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;

    try {
      await provider.deleteAddress(address.id);
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
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _setDefaultAddress(
    CustomerAddressesProvider provider,
    ProfileAddressEntry address,
  ) async {
    try {
      await provider.setDefaultAddress(address.id);
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
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerAddressesProvider>();

    return CustomerLayout(
      title: 'Mis Direcciones',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: provider.loadAddresses,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildHeaderBanner(provider),
              ),
            ),

            _buildBody(provider),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(CustomerAddressesProvider provider) {
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
                      provider.addresses.isEmpty
                          ? 'Agrega tu domicilio para recibir tus compras'
                          : '${provider.addresses.length} guardada${provider.addresses.length == 1 ? '' : 's'}',
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

  Widget _buildBody(CustomerAddressesProvider provider) {
    if (provider.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: AppShimmer(
              width: double.infinity,
              height: 140,
              borderRadius: 20,
            ),
          ),
          childCount: 3,
        ),
      );
    }

    if (provider.profileId == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Necesitas iniciar sesión',
            message: 'Inicia sesión para gestionar tus direcciones.',
          ),
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty && provider.addresses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Algo salió mal',
            message: provider.errorMessage,
          ),
        ),
      );
    }

    if (provider.addresses.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
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
                  onPressed: () => _openAddressEditor(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text(
                    'Agregar primera dirección',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == provider.addresses.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openAddressEditor(provider),
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

          final address = provider.addresses[index];
          final isProcessing = provider.isItemProcessing(address.id);

          return CustomerAddressCard(
            address: address,
            isProcessing: isProcessing,
            onSetDefault: () => _setDefaultAddress(provider, address),
            onEdit:
                () => _openAddressEditor(provider, existingAddress: address),
            onDelete: () => _deleteAddress(provider, address),
          );
        },
        childCount:
            provider.addresses.length + 1, // +1 for the add button at the end
      ),
    );
  }
}
