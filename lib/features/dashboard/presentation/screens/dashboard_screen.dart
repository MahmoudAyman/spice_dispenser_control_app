import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../controllers/machine_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      loadSlots();
    });
  }

  void loadSlots() {
    final List<SlotModel> loadedSlots =
    StorageService.getSlots();

    context
        .read<MachineController>()
        .loadSlots(
      loadedSlots,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller =
    context.watch<MachineController>();

    final machineState =
        controller.machineState;

    final slots = controller.slots;

    final lowLevelThreshold =
    StorageService.getLowLevelThreshold();

    final lowSlots = slots
        .where(
          (slot) =>
      slot.level <=
          lowLevelThreshold,
    )
        .length;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor:
        const Color(0xFF2563EB),
        elevation: 0,
        title: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Smart Spice Machine',
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin:
            const EdgeInsets.only(
              right: 16,
            ),
            padding:
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.15),
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                  BoxDecoration(
                    color: machineState
                        .connected
                        ? Colors.green
                        : Colors.red,
                    shape:
                    BoxShape.circle,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  machineState.connected
                      ? 'Connected'
                      : 'Disconnected',
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            /// MACHINE ALERT
            if (machineState.alertCode !=
                null)
              Container(
                width: double.infinity,
                margin:
                const EdgeInsets.only(
                  bottom: 24,
                ),
                padding:
                const EdgeInsets.all(
                  18,
                ),
                decoration:
                BoxDecoration(
                  color: Colors.red
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  border: Border.all(
                    color: Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color:
                      Colors.red,
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          const Text(
                            'Machine Alert',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize:
                              16,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            '${machineState.alertCode} on slot ${machineState.alertSlot}',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        controller
                            .clearAlert();
                      },
                      icon:
                      const Icon(
                        Icons.close,
                      ),
                    ),
                  ],
                ),
              ),

            /// LOW LEVEL ALERT
            if (lowSlots > 0)
              Container(
                width: double.infinity,
                margin:
                const EdgeInsets.only(
                  bottom: 24,
                ),
                padding:
                const EdgeInsets.all(
                  18,
                ),
                decoration:
                BoxDecoration(
                  color: Colors.orange
                      .withOpacity(0.1),
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  border: Border.all(
                    color:
                    Colors.orange,
                  ),
                ),
                child: Text(
                  '$lowSlots container(s) are running low',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

            /// HEADER
            Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
              children: [
                const Text(
                  'Spice Containers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Text(
                    '${slots.length} Slots',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            /// GRID
            GridView.builder(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                0.82,
              ),
              itemBuilder:
                  (context, index) {
                final slot =
                slots[index];

                final lowSpice =
                    slot.level <=
                        lowLevelThreshold;

                return Container(
                  padding:
                  const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      26,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withOpacity(
                          0.04,
                        ),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Text(
                            'Slot ${slot.slotNumber}',
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                          if (lowSpice)
                            const Icon(
                              Icons.warning,
                              color:
                              Colors.red,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(
                          height: 16),
                      Text(
                        slot.spiceName,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(
                          height: 8),
                      Text(
                        'Expiry: ${slot.expiryDate}',
                        style:
                        TextStyle(
                          color: Colors
                              .grey
                              .shade700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Text(
                            '${slot.level}%',
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize:
                              18,
                            ),
                          ),
                          Text(
                            lowSpice
                                ? 'Low'
                                : 'Good',
                            style:
                            TextStyle(
                              color: lowSpice
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                          height: 10),
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                        child:
                        LinearProgressIndicator(
                          value:
                          slot.level /
                              100,
                          minHeight:
                          10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}