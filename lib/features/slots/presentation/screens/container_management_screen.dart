import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../dashboard/presentation/controllers/machine_controller.dart';
import '../../../sync/services/slot_storage_service.dart';
import '../../../sync/services/slot_sync_service.dart';
import '../cubit/slot_cubit.dart';
import '../cubit/slot_state.dart';
import '../widgets/slot_card.dart';

class ContainerManagementScreen extends StatefulWidget {
  const ContainerManagementScreen({
    super.key,
  });

  @override
  State<ContainerManagementScreen> createState() =>
      _ContainerManagementScreenState();
}

class _ContainerManagementScreenState
    extends State<ContainerManagementScreen> {
  double lowLevelThreshold = 20;

  @override
  void initState() {
    super.initState();

    lowLevelThreshold =
        StorageService.getLowLevelThreshold().toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SlotCubit(
        SlotStorageService(),
        SlotSyncService(),
      )
        ..loadSlots()
        ..syncLevels(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2563EB),
          title: const Text(
            'Container Management',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        body: BlocConsumer<SlotCubit, SlotState>(
          listener: (context, state) {
            if (state is SlotUpdated) {
              final List<SlotModel> slots =
              StorageService.getSlots();

              context
                  .read<MachineController>()
                  .loadSlots(slots);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Slot Updated'),
                ),
              );
            }

            if (state is SlotRefilled) {
              final List<SlotModel> slots =
              StorageService.getSlots();

              context
                  .read<MachineController>()
                  .loadSlots(slots);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Slot Refilled'),
                ),
              );
            }

            if (state is SlotError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                ),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.watch<SlotCubit>();

            /// Loading only on first load
            if (state is SlotLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (cubit.slots.isEmpty) {
              return const Center(
                child: Text('No slots available'),
              );
            }

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Level Alert Threshold (${lowLevelThreshold.toInt()}%)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: lowLevelThreshold,
                        min: 5,
                        max: 50,
                        divisions: 9,
                        label:
                        '${lowLevelThreshold.toInt()}%',
                        onChanged: (value) async {
                          setState(() {
                            lowLevelThreshold = value;
                          });

                          await StorageService
                              .saveLowLevelThreshold(
                            value.toInt(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await context
                          .read<SlotCubit>()
                          .syncLevels();
                    },
                    child: ListView.builder(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      itemCount: cubit.slots.length,
                      itemBuilder: (context, index) {
                        final slot =
                        cubit.slots[index];

                        return SlotCard(
                          slot: slot,
                          lowLevelThreshold:
                          lowLevelThreshold.toInt(),

                          isUpdating: cubit.isUpdating(
                            slot.slotNumber,
                          ),

                          isRefilling: cubit.isRefilling(
                            slot.slotNumber,
                          ),

                          onRefill: () {
                            context
                                .read<SlotCubit>()
                                .refillSlot(
                              slot.slotNumber,
                            );
                          },

                          onSave: (
                              spice,
                              expiry,
                              capacity,
                              ) {
                            final updatedSlot =
                            slot.copyWith(
                              spiceName: spice,
                              expiryDate: expiry,
                              capacity: capacity,
                            );

                            context
                                .read<SlotCubit>()
                                .updateSlot(
                              updatedSlot,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}