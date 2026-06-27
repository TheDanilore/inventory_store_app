import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/cash_shift_model.dart';
import 'package:inventory_store_app/providers/admin/cash_shifts_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/close_shift_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllCashShiftsScreen extends StatelessWidget {
  const AllCashShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We wrap it in its own provider instance so it doesn't affect the financial_accounts_screen
    return ChangeNotifierProvider<CashShiftsProvider>(
      create: (_) => CashShiftsProvider(),
      child: const _AllCashShiftsBody(),
    );
  }
}

class _AllCashShiftsBody extends StatefulWidget {
  const _AllCashShiftsBody();

  @override
  State<_AllCashShiftsBody> createState() => _AllCashShiftsBodyState();
}

class _AllCashShiftsBodyState extends State<_AllCashShiftsBody> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfiles();
      // Initialize with no profile filter (all users)
      context.read<CashShiftsProvider>().fetchShifts();
    });
  }

  Future<void> _loadProfiles() async {
    try {
      final res = await _supabase.from('profiles').select('id, full_name').neq('role', 'customer').order('full_name');
      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(res);
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashShiftsProvider>();

    return AdminLayout(
      title: 'Historial de Turnos',
      showBackButton: true,
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilter(provider, 'Todos'),
                      const SizedBox(width: 8),
                      _buildStatusFilter(provider, 'OPEN'),
                      const SizedBox(width: 8),
                      _buildStatusFilter(provider, 'CLOSED'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: provider.shifts.isEmpty && provider.isLoading ? null : null, // Cannot read _profileFilter directly as it has no getter yet, but we will fix that
                            hint: _isLoadingProfiles 
                                ? const Text('Cargando usuarios...') 
                                : const Text('Todos los usuarios', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los usuarios', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              ..._profiles.map((p) => DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(p['full_name'] as String),
                              )),
                            ],
                            onChanged: (val) {
                              provider.setProfileFilter(val);
                              setState((){}); // Ensure dropdown updates locally if we don't expose getter
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: provider.isLoading && provider.shifts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.shifts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No hay turnos registrados', style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async => provider.fetchShifts(),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: provider.shifts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final shift = provider.shifts[index];
                                  return _GlobalShiftCard(
                                    shift: shift,
                                    onClose: shift.status == 'OPEN' ? () async {
                                      final expected = await provider.calcExpected(shift.id, shift.accountId ?? '', shift.openingAmount);
                                      if (context.mounted) {
                                        CloseShiftSheet.show(context, shift: shift, expectedAmount: expected).then((success) {
                                          if (success == true && mounted) provider.fetchShifts();
                                        });
                                      }
                                    } : null,
                                  );
                                },
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
                            ),
                            child: AdminPageBlocks(
                              currentPage: provider.currentPage,
                              totalPages: provider.totalPages,
                              onPageChanged: (page) => provider.setPage(page),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(CashShiftsProvider provider, String status) {
    final isSelected = provider.filterStatus == status;
    String label = status;
    if (status == 'OPEN') label = 'Abiertos';
    if (status == 'CLOSED') label = 'Cerrados';

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => provider.setFilterStatus(status),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey[300]!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _GlobalShiftCard extends StatefulWidget {
  final CashShiftModel shift;
  final Future<void> Function()? onClose;

  const _GlobalShiftCard({required this.shift, this.onClose});

  @override
  State<_GlobalShiftCard> createState() => _GlobalShiftCardState();
}

class _GlobalShiftCardState extends State<_GlobalShiftCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.shift.status == 'OPEN';
    final shift = widget.shift;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.point_of_sale_rounded, color: isOpen ? AppColors.success : AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.accountName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 12, color: AppColors.success.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM HH:mm').format(shift.openedAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.person, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shift.openedByName.split(' ')[0],
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(isOpen ? 'ABIERTO' : 'CERRADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isOpen ? AppColors.success : AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Apertura', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      Text('S/ ${shift.openingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
                if (!isOpen) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cierre', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text('S/ ${shift.actualAmount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Diferencia', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text(
                          'S/ ${shift.differenceAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: shift.differenceAmount == null || shift.differenceAmount == 0
                                ? AppColors.success
                                : (shift.differenceAmount! > 0 ? AppColors.success : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isOpen && widget.onClose != null)
                  ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      await widget.onClose!();
                      if (mounted) setState(() => _isLoading = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(0, 32),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Cerrar Turno', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
