import 'package:flutter/material.dart';

import '../../../../core/storage/storage_service.dart';

import '../../../container_management/data/models/slot_model.dart';

class DashboardScreen
    extends StatefulWidget {

  const DashboardScreen({
    super.key,
  });

  @override
  State<DashboardScreen>
  createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<
        DashboardScreen> {

  List<SlotModel> slots = [];

  @override
  void initState() {
    super.initState();

    loadSlots();
  }

  void loadSlots() {

    slots =
        StorageService.getSlots();

    debugPrint(
      'LOADED SLOTS: ${slots.length}',
    );

    for (final slot in slots) {

      debugPrint(
        'Slot ${slot.slotNumber}: ${slot.spiceName}',
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
      const Color(0xFFF4F7FB),

      appBar: AppBar(
        title: const Text(
          'Dashboard',
        ),
      ),

      body:
      slots.isEmpty

          ? const Center(
        child: Text(
          'No Slots Found',
        ),
      )

          : ListView.builder(

        padding:
        const EdgeInsets.all(20),

        itemCount:
        slots.length,

        itemBuilder:
            (context, index) {

          final slot =
          slots[index];

          return Container(

            margin:
            const EdgeInsets.only(
              bottom: 16,
            ),

            padding:
            const EdgeInsets.all(
              20,
            ),

            decoration:
            BoxDecoration(
              color: Colors.white,

              borderRadius:
              BorderRadius.circular(
                24,
              ),
            ),

            child: Row(
              children: [

                CircleAvatar(
                  radius: 28,

                  child: Text(
                    '${slot.slotNumber}',
                  ),
                ),

                const SizedBox(
                  width: 16,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [

                      Text(
                        slot.spiceName,

                        style:
                        const TextStyle(
                          fontSize: 18,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        'Expiry: ${slot.expiryDate}',
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        'Level: ${slot.level}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}