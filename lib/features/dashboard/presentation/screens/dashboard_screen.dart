import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../cubit/machine_state_cubit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SlotModel> slots = [];

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  void loadSlots() {
    setState(() {
      slots = StorageService.getSlots();
    });
    debugPrint('DASHBOARD LOADED SLOTS: ${slots.length}');
  }

  Color _getLevelColor(int level) {
    if (level > 50) return AppColors.green;
    if (level > 20) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final bleCubit = context.watch<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;

    return BlocProvider(
      create: (context) => MachineStateCubit(bleCubit.bleService),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.white),
                onPressed: () async {
                  try {
                    await bleCubit.syncService.requestSync();
                    loadSlots();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing levels...')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Failed to sync: $e');
                  }
                },
                tooltip: 'Sync Levels',
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            loadSlots();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Connection & Live Machine Status Card
                _buildMachineStatusCard(context, isConnected),
                const SizedBox(height: 24),

                // 2. Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Spice Containers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      '${slots.length} Slots Available',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Spice Containers Grid
                slots.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.kitchen_outlined, size: 48, color: AppColors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No Containers Set Up',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please complete the setup to configure your spice slots.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppColors.grey),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: slots.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemBuilder: (context, index) {
                          final slot = slots[index];
                          final isLow = slot.level <= 20;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isLow ? Colors.redAccent.withOpacity(0.3) : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary.withOpacity(0.1),
                                        child: Text(
                                          '${slot.slotNumber}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      if (isLow)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'LOW',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    slot.spiceName.isEmpty ? 'Empty Slot' : slot.spiceName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Exp: ${slot.expiryDate.isEmpty ? 'N/A' : slot.expiryDate}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: slot.level / 100.0,
                                            minHeight: 8,
                                            backgroundColor: Colors.grey[100],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              _getLevelColor(slot.level),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${slot.level}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getLevelColor(slot.level),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineStatusCard(BuildContext context, bool isConnected) {
    if (!isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.grey),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Machine Disconnected',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connect your device to synchronize spice levels and dispense.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
              onPressed: () {
                // Return to connection screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      );
    }

    final machine = StorageService.getLastMachine();

    return BlocBuilder<MachineStateCubit, MachineStateState>(
      builder: (context, state) {
        String statusText = 'Connected & Ready';
        String subtitleText = 'Your smart dispenser is ready.';
        Color statusColor = AppColors.green;
        IconData statusIcon = Icons.check_circle;
        Widget? actionWidget;

        if (state is MachineStatusUpdated) {
          final status = state.status;
          if (status.state == 'dispensing') {
            statusText = 'Dispensing Spice...';
            subtitleText = 'Active dispensing progress: ${status.progress}%';
            statusColor = AppColors.primary;
            statusIcon = Icons.hourglass_top_outlined;
            actionWidget = Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SizedBox(
                width: double.infinity,
                child: LinearProgressIndicator(
                  value: status.progress / 100.0,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          } else if (status.state == 'completed') {
            statusText = 'Dispensing Completed';
            subtitleText = 'Ready for next action.';
            statusColor = AppColors.green;
            statusIcon = Icons.done_all;
          }
        } else if (state is MachineAlertState) {
          final alert = state.alert;
          statusText = 'Machine Alert';
          subtitleText = 'Alert code ${alert.code} on slot ${alert.slot}.';
          statusColor = Colors.redAccent;
          statusIcon = Icons.warning_amber_rounded;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 28, color: statusColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              machine?.deviceName ?? 'Smart Dispenser',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionWidget != null) actionWidget,
            ],
          ),
        );
      },
    );
  }
}
