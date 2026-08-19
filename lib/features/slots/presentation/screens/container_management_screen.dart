import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/ble_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/slot_storage_service.dart';
import '../../../sync/services/slot_sync_service.dart';
import '../cubit/slot_cubit.dart';
import '../cubit/slot_state.dart';
import '../widgets/slot_grid_tile.dart';
import '../../../container_management/data/models/spice_definition_model.dart';
import '../../../container_management/presentation/cubit/spice_cubit.dart';
import '../widgets/spice_selection_dialog.dart';

class ContainerManagementScreen extends StatelessWidget {
  final BleService bleService;
  const ContainerManagementScreen({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SlotCubit(
        SlotStorageService(),
        SlotSyncService(bleService: bleService),
      )..loadSlots(),
      child: const _ContainerManagementView(),
    );
  }
}

class _ContainerManagementView extends StatefulWidget {
  const _ContainerManagementView();

  @override
  State<_ContainerManagementView> createState() => _ContainerManagementViewState();
}

class _ContainerManagementViewState extends State<_ContainerManagementView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SlotModel> _filter(List<SlotModel> slots) {
    if (_searchQuery.isEmpty) return slots;
    return slots
        .where((s) =>
            s.spiceName.toLowerCase().contains(_searchQuery) ||
            s.slotNumber.toString().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        title: const Text(
          'Manage Containers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by spice name or slot number…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: BlocConsumer<SlotCubit, SlotState>(
        listener: (context, state) {
          if (state is SlotUpdated) {
            _showSnack(context, '✅ Slot updated successfully', Colors.green.shade700);
          }
          if (state is SlotRefilled) {
            _showSnack(context, '✅ Slot refilled successfully', Colors.green.shade700);
          }
          if (state is SlotError) {
            _showSnack(context, '❌ ${state.message}', Colors.red.shade700);
          }
        },
        builder: (context, state) {
          if (state is SlotLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cubit = context.read<SlotCubit>();
          final filtered = _filter(cubit.slots);

          if (filtered.isEmpty) {
            return _buildEmptyState(_searchQuery.isNotEmpty);
          }

          final bool isBusy = state is SlotUpdating || state is SlotRefilling;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildSummaryRow(cubit.slots),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final slot = filtered[index];
                          return SlotGridTile(
                            slot: slot,
                            onTap: () => _openEditSheet(context, cubit, slot),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                ],
              ),
              if (isBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(List<SlotModel> slots) {
    final int total = slots.length;
    
    final int configured = slots.where((s) {
      final name = s.spiceName.trim();
      return name.isNotEmpty && !name.startsWith('Slot ');
    }).length;

    final int lowThreshold = StorageService.getLowLevelThreshold();
    final int lowCount = slots.where((s) {
      final name = s.spiceName.trim();
      final isSkipped = name.isEmpty || name.startsWith('Slot ');
      return !isSkipped && s.level <= lowThreshold;
    }).length;

    final int expiredCount = slots.where((s) {
      final name = s.spiceName.trim();
      final isSkipped = name.isEmpty || name.startsWith('Slot ');
      return !isSkipped && s.isExpired;
    }).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _SummaryChip(label: '$configured/$total Configured', icon: Icons.kitchen, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          if (lowCount > 0)
            _SummaryChip(label: '$lowCount Low', icon: Icons.warning_amber_rounded, color: Colors.orange.shade600),
          if (expiredCount > 0) ...[
            const SizedBox(width: 8),
            _SummaryChip(label: '$expiredCount Expired', icon: Icons.error_outline, color: Colors.red.shade600),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isFiltered) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFiltered ? Icons.search_off : Icons.inbox_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No slots match your search.' : 'No slots found.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openEditSheet(BuildContext context, SlotCubit cubit, SlotModel slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: context.read<SpiceCubit>()),
        ],
        child: _SlotEditSheet(slot: slot),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary chip
// ─────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit / Refill bottom sheet
// ─────────────────────────────────────────────────────────────
class _SlotEditSheet extends StatefulWidget {
  final SlotModel slot;
  const _SlotEditSheet({required this.slot});

  @override
  State<_SlotEditSheet> createState() => _SlotEditSheetState();
}

class _SlotEditSheetState extends State<_SlotEditSheet> {
  late final TextEditingController _nameController;
  DateTime? _selectedExpiry;
  int _refillLevel = 100;
  bool _showRefill = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.slot.spiceName);
    if (widget.slot.expiryEpoch != null && widget.slot.expiryEpoch! > 0) {
      _selectedExpiry = DateTime.fromMillisecondsSinceEpoch(widget.slot.expiryEpoch! * 1000);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiry ?? now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'SELECT EXPIRY DATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedExpiry = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spice name cannot be empty')),
      );
      return;
    }
    final epochSecs = _selectedExpiry != null
        ? (_selectedExpiry!.millisecondsSinceEpoch ~/ 1000)
        : null;

    final updated = SlotModel(
      slotNumber: widget.slot.slotNumber,
      spiceName: name,
      expiryEpoch: epochSecs,
      level: widget.slot.level,
    );

    context.read<SlotCubit>().updateSlot(updated);
    Navigator.of(context).pop();
  }

  void _confirmRefill() {
    final epochSecs = _selectedExpiry != null
        ? (_selectedExpiry!.millisecondsSinceEpoch ~/ 1000)
        : null;
    context.read<SlotCubit>().refillSlot(
          widget.slot.slotNumber,
          level: _refillLevel,
          expiryEpoch: epochSecs,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.slot.slotNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.slot.spiceName.isEmpty ? 'Empty Slot' : widget.slot.spiceName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Fill Level: ${widget.slot.level}%',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Spice name field
            GestureDetector(
              onTap: () async {
                final selectedSpice = await showDialog<SpiceDefinition>(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: context.read<SpiceCubit>(),
                    child: const SpiceSelectionDialog(),
                  ),
                );
                if (selectedSpice != null) {
                  _nameController.text = selectedSpice.name;
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Spice Name',
                    prefixIcon: const Icon(Icons.spa_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Expiry date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedExpiry != null
                            ? 'Expiry: ${_formatDate(_selectedExpiry!)}'
                            : 'Set Expiry Date (optional)',
                        style: TextStyle(
                          color: _selectedExpiry != null ? Colors.black87 : Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_selectedExpiry != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedExpiry = null),
                        child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Refill section
            if (!_showRefill)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showRefill = true),
                  icon: const Icon(Icons.water_drop_outlined, color: Color(0xFF2563EB)),
                  label: const Text('Refill Container', style: TextStyle(color: Color(0xFF2563EB), fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              _buildRefillSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildRefillSelector() {
    const levels = [25, 50, 75, 100];
    const levelLabels = ['Quarter', 'Half', '¾ Full', 'Full'];
    const levelIcons = [
      Icons.battery_1_bar,
      Icons.battery_3_bar,
      Icons.battery_5_bar,
      Icons.battery_full,
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Select Fill Level',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showRefill = false),
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(levels.length, (i) {
              final selected = _refillLevel == levels[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _refillLevel = levels[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: i < levels.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 8)]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Icon(levelIcons[i], color: selected ? Colors.white : Colors.grey.shade600, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          '${levels[i]}%',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          levelLabels[i],
                          style: TextStyle(
                            color: selected ? Colors.white70 : Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _confirmRefill,
              icon: const Icon(Icons.check),
              label: Text('Confirm Refill to $_refillLevel%'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}