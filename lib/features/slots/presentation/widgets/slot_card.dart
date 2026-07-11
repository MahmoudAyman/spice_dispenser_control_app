import 'package:flutter/material.dart';

import '../../../container_management/data/models/slot_model.dart';

class SlotCard extends StatelessWidget {
  final SlotModel slot;

  final int lowLevelThreshold;

  final bool isUpdating;

  final bool isRefilling;

  final VoidCallback onRefill;

  final Function(
      String spice,
      String expiry,
      int capacity,
      ) onSave;

  const SlotCard({
    super.key,
    required this.slot,
    required this.lowLevelThreshold,
    required this.isUpdating,
    required this.isRefilling,
    required this.onRefill,
    required this.onSave,
  });

  Color get levelColor {
    if (slot.level <= lowLevelThreshold) {
      return Colors.red;
    }

    if (slot.level <= lowLevelThreshold + 20) {
      return Colors.orange;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final spiceController = TextEditingController(
      text: slot.spiceName == 'Empty'
          ? ''
          : slot.spiceName,
    );

    final expiryController = TextEditingController(
      text: slot.expiryDate,
    );

    final capacityController = TextEditingController(
      text: slot.capacity.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 20,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                levelColor.withOpacity(0.15),
                child: Text(
                  '${slot.slotNumber}',
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.spiceName.isEmpty ||
                          slot.spiceName ==
                              'Empty'
                          ? 'Empty Slot'
                          : slot.spiceName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capacity: ${slot.capacity}g',
                      style: TextStyle(
                        color:
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (slot.level <=
                  lowLevelThreshold)
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 30,
                ),
            ],
          ),

          const SizedBox(height: 24),

          /// LEVEL
          Text(
            'Level: ${slot.level}%',
            style: TextStyle(
              color: levelColor,
              fontWeight:
              FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(12),
            child:
            LinearProgressIndicator(
              value: slot.level / 100,
              minHeight: 12,
              color: levelColor,
              backgroundColor:
              Colors.grey.shade300,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            slot.lastRefillDate.isEmpty
                ? 'Never Refilled'
                : 'Last Refill: ${slot.lastRefillDate}',
            style: TextStyle(
              color:
              Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          /// SPICE NAME
          TextField(
            controller: spiceController,
            decoration:
            const InputDecoration(
              labelText: 'Spice Name',
            ),
          ),

          const SizedBox(height: 16),

          /// EXPIRY
          TextField(
            controller: expiryController,
            decoration:
            const InputDecoration(
              labelText: 'Expiry Date',
            ),
          ),

          const SizedBox(height: 16),

          /// CAPACITY
          TextField(
            controller:
            capacityController,
            keyboardType:
            TextInputType.number,
            decoration:
            const InputDecoration(
              labelText:
              'Capacity (g)',
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () {
                    final capacity =
                        int.tryParse(
                          capacityController
                              .text,
                        ) ??
                            slot.capacity;

                    onSave(
                      spiceController
                          .text,
                      expiryController
                          .text,
                      capacity,
                    );
                  },
                  child: isUpdating
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.green,
                  ),
                  onPressed: isRefilling
                      ? null
                      : onRefill,
                  child: isRefilling
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Refill',
                    style: TextStyle(
                      color:
                      Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}