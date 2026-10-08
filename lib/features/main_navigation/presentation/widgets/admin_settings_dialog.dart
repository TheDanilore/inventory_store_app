import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';

/// Modal centralizado de Configuración del ERP (Shopeers / Apple HIG Style)
class AdminSettingsDialog extends StatefulWidget {
  const AdminSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const AdminSettingsDialog(),
    );
  }

  @override
  State<AdminSettingsDialog> createState() => _AdminSettingsDialogState();
}

class _AdminSettingsDialogState extends State<AdminSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuraciones del Sistema',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ajustes de empresa, interfaz y parámetros operacionales',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    tooltip: 'Cerrar (Esc)',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Tab Bar Navigation ──────────────────────────────────────
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: const Color(0xFF2563EB),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.storefront_rounded, size: 16), text: 'Empresa'),
                  Tab(icon: Icon(Icons.palette_outlined, size: 16), text: 'Apariencia'),
                  Tab(icon: Icon(Icons.account_balance_rounded, size: 16), text: 'Cuentas'),
                  Tab(icon: Icon(Icons.card_giftcard_rounded, size: 16), text: 'Puntos'),
                  Tab(icon: Icon(Icons.print_rounded, size: 16), text: 'Impresora POS'),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Tab Views ──────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBusinessTab(context),
                  _buildAppearanceTab(context),
                  _buildFinancialAccountsTab(context),
                  _buildLoyaltyPointsTab(context),
                  _buildPrinterTab(context),
                ],
              ),
            ),

            // ── Dialog Footer ──────────────────────────────────────────
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preferencias del Sistema',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Listo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessTab(BuildContext context) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final name = info?.businessName ?? 'DANILORE ONE ERP';
        final ruc = info?.taxId ?? '20601234567';
        final address = info?.address ?? 'Av. Principal 123';
        final phone = info?.phone ?? '987 654 321';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSettingRow(
              icon: Icons.business_rounded,
              title: 'Nombre Comercial',
              subtitle: name,
              trailing: 'Moneda: PEN (S/)',
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              icon: Icons.numbers_rounded,
              title: 'RUC / Identificación Fiscal',
              subtitle: ruc,
              trailing: 'IGV: 18%',
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              icon: Icons.location_on_outlined,
              title: 'Dirección Comercial',
              subtitle: address,
              trailing: phone,
            ),
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/business-info');
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Editar Información Completa de Empresa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          icon: Icons.light_mode_rounded,
          title: 'Tema de la Interfaz',
          subtitle: 'Estilo Ejecutivo Apple / Linear (Claro)',
          trailing: 'Modo Actual: Claro',
        ),
        const SizedBox(height: 14),
        _buildSettingRow(
          icon: Icons.vibration_rounded,
          title: 'Feedback Háptico',
          subtitle: 'Vibración y confirmación en escaneos y acciones rápidas',
          trailing: 'Activado',
        ),
        const SizedBox(height: 14),
        _buildSettingRow(
          icon: Icons.keyboard_rounded,
          title: 'Atajos Globales de Teclado',
          subtitle: 'Búsqueda instantánea con ⌘K, recarga con R y filtros con 1..4',
          trailing: 'Habilitados',
        ),
      ],
    );
  }

  Widget _buildFinancialAccountsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Cuentas Financieras & Cajas',
          subtitle: 'Administra cuentas bancarias, billeteras digitales (Yape, Plin) y cajas',
          trailing: 'Activas',
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/financial-accounts');
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Administrar Cuentas Financieras'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoyaltyPointsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          icon: Icons.card_giftcard_rounded,
          title: 'Sistema de Fidelización y Puntos',
          subtitle: 'Define el porcentaje de puntos otorgados por compra y vigencia',
          trailing: 'Configurable',
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/points-settings');
            },
            icon: const Icon(Icons.stars_rounded, size: 18),
            label: const Text('Gestionar Ajustes de Puntos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          icon: Icons.print_rounded,
          title: 'Formato de Impresión de Tickets POS',
          subtitle: 'Ancho estándar de comprobantes térmicos para ventas',
          trailing: '80 mm (Térmico)',
        ),
        const SizedBox(height: 14),
        _buildSettingRow(
          icon: Icons.receipt_long_rounded,
          title: 'Impresión Automática',
          subtitle: 'Disparar impresión al confirmar cobro en terminal de caja',
          trailing: 'Opcional en cobro',
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
