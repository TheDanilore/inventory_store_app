import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/pos/data/models/cash_shift_model.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cash_shifts_provider.dart';
import 'package:inventory_store_app/features/financial/presentation/screens/widgets/financial/close_shift_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class AllCashShiftsScreen extends StatelessWidget {
  const AllCashShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfiles();
      context.read<CashShiftsProvider>().fetchShifts();
    });
  }

  Future<void> _loadProfiles() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name')
          .neq('role', 'customer')
          .order('full_name');
      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(res);
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
  }

  void _showUserPickerBottomSheet(CashShiftsProvider provider) {
    if (_isLoadingProfiles) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filtrar por Usuario',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildUserOption(
                          provider, 
                          title: 'Todos los usuarios', 
                          value: null, 
                          icon: Icons.group_rounded
                        ),
                        const Divider(height: 24),
                        ..._profiles.map((p) => _buildUserOption(
                          provider,
                          title: p['full_name'] as String,
                          value: p['id'] as String,
                          icon: Icons.person_rounded,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserOption(CashShiftsProvider provider, {required String title, required String? value, required IconData icon}) {
    final isSelected = _selectedProfileId == value;
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      onTap: () {
        setState(() => _selectedProfileId = value);
        provider.setProfileFilter(value);
        Navigator.pop(context);
      },
      leading: CircleAvatar(
        backgroundColor: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
        child: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: colorScheme.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? colorScheme.primary.withValues(alpha: 0.05) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashShiftsProvider>();
    final theme = Theme.of(context);
    
    String selectedUserName = 'Todos los usuarios';
    if (_selectedProfileId != null) {
      final p = _profiles.where((p) => p['id'] == _selectedProfileId).firstOrNull;
      if (p != null) selectedUserName = p['full_name'] as String;
    }

    return AdminLayout(
      title: 'Historial de Turnos',
      showBackButton: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Filters Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusFilter(provider, 'Todos', theme),
                          const SizedBox(width: 8),
                          _buildStatusFilter(provider, 'OPEN', theme),
                          const SizedBox(width: 8),
                          _buildStatusFilter(provider, 'CLOSED', theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _showUserPickerBottomSheet(provider),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedProfileId == null ? Icons.group_rounded : Icons.person_rounded, 
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isLoadingProfiles ? 'Cargando usuarios...' : selectedUserName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // List Section
              Expanded(
                child: provider.isLoading && provider.shifts.isEmpty
                    ? const _ShiftsSkeleton()
                    : provider.shifts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay turnos registrados', 
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () async => provider.fetchShifts(),
                                  child: AnimationLimiter(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: provider.shifts.length,
                                      separatorBuilder: (_, index) => const SizedBox(height: 16),
                                      itemBuilder: (context, index) {
                                        final shift = provider.shifts[index];
                                        return AnimationConfiguration.staggeredList(
                                          position: index,
                                          duration: const Duration(milliseconds: 375),
                                          child: SlideAnimation(
                                            verticalOffset: 20.0,
                                            child: FadeInAnimation(
                                              child: _GlobalShiftCard(
                                                shift: shift,
                                                onClose: shift.status == 'OPEN' ? () async {
                                                  final expected = await provider.calcExpected(shift.id, shift.accountId ?? '', shift.openingAmount);
                                                  if (context.mounted) {
                                                    CloseShiftSheet.show(context, shift: shift, expectedAmount: expected).then((success) {
                                                      if (success == true && mounted) provider.fetchShifts();
                                                    });
                                                  }
                                                } : null,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03), 
                                      blurRadius: 10, 
                                      offset: const Offset(0, -2)
                                    )
                                  ],
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
        ),
      ),
    );
  }

  Widget _buildStatusFilter(CashShiftsProvider provider, String status, ThemeData theme) {
    final isSelected = provider.filterStatus == status;
    String label = status;
    if (status == 'OPEN') label = 'Abiertos';
    if (status == 'CLOSED') label = 'Cerrados';

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => provider.setFilterStatus(status),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : theme.colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isOpen ? AppColors.success : colorScheme.onSurfaceVariant).withValues(alpha: 0.1), 
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    Icons.point_of_sale_rounded, 
                    color: isOpen ? AppColors.success : colorScheme.onSurfaceVariant, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.accountName, 
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 14, color: AppColors.success.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM HH:mm').format(shift.openedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shift.openedByName.split(' ')[0],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isOpen ? AppColors.success : colorScheme.onSurfaceVariant).withValues(alpha: 0.15), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                        isOpen ? 'ABIERTO' : 'CERRADO', 
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.w800, 
                          color: isOpen ? AppColors.success : colorScheme.onSurfaceVariant
                        )
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apertura', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant, 
                          fontWeight: FontWeight.w600
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${shift.openingAmount.toStringAsFixed(2)}', 
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        )
                      ),
                    ],
                  ),
                ),
                if (!isOpen) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cierre', 
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant, 
                            fontWeight: FontWeight.w600
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'S/ ${shift.actualAmount?.toStringAsFixed(2) ?? '0.00'}', 
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          )
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Diferencia', 
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant, 
                            fontWeight: FontWeight.w600
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'S/ ${shift.differenceAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFeatures: [const FontFeature.tabularFigures()],
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                      minimumSize: const Size(0, 48), // 48dp Minimum Touch Target
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Cerrar Turno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftsSkeleton extends StatelessWidget {
  const _ShiftsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return AppShimmer(
          height: 150,
          borderRadius: 16.0,
        );
      },
    );
  }
}

