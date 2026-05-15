import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/slot_storage_service.dart';
import '../../../sync/services/slot_sync_service.dart';
import '../cubit/slot_cubit.dart';
import '../cubit/slot_state.dart';
import '../widgets/slot_card.dart';

class ContainerManagementScreen
    extends StatelessWidget {

  const ContainerManagementScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return BlocProvider(
      create: (_) => SlotCubit(
        SlotStorageService(),
        SlotSyncService(),
      )..loadSlots(),

      child: Scaffold(
        backgroundColor:
        const Color(0xFFF1F5F9),

        appBar: AppBar(
          backgroundColor:
          const Color(0xFF2563EB),

          title: const Text(
            'Container Management',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),

        body: BlocConsumer<
            SlotCubit,
            SlotState>(
          listener: (context, state) {

            if (state
            is SlotUpdated) {

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Slot Updated',
                  ),
                ),
              );
            }

            if (state
            is SlotRefilled) {

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Slot Refilled',
                  ),
                ),
              );
            }
          },

          builder: (context, state) {

            if (state
            is SlotLoading) {

              return const Center(
                child:
                CircularProgressIndicator(),
              );
            }

            final cubit =
            context.read<SlotCubit>();

            return ListView.builder(
              padding:
              const EdgeInsets.all(20),

              itemCount:
              cubit.slots.length,

              itemBuilder:
                  (context, index) {

                final slot =
                cubit.slots[index];

                return SlotCard(
                  slot: slot,

                  onRefill: () {

                    context
                        .read<SlotCubit>()
                        .refillSlot(
                      slot.slotNumber,
                    );
                  },

                  onSave:
                      (spice, expiry) {

                    final updatedSlot =
                    SlotModel(
                      slotNumber:
                      slot.slotNumber,

                      spiceName:
                      spice,

                      expiryDate:
                      expiry,

                      level:
                      slot.level,
                    );

                    context
                        .read<SlotCubit>()
                        .updateSlot(
                      updatedSlot,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}