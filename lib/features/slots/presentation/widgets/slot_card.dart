import 'package:flutter/material.dart';

import '../../../container_management/data/models/slot_model.dart';

class SlotCard extends StatelessWidget {

  final SlotModel slot;

  final VoidCallback onRefill;

  final Function(
      String spice,
      String expiry,
      ) onSave;

  const SlotCard({
    super.key,
    required this.slot,
    required this.onRefill,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {

    final spiceController =
    TextEditingController(
      text: slot.spiceName,
    );

    final expiryController =
    TextEditingController(
      text: slot.expiryDate,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 20,
      ),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.05,
            ),

            blurRadius: 10,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              CircleAvatar(
                radius: 26,

                backgroundColor:
                const Color(
                  0xFFE8FCEB,
                ),

                child: Text(
                  '${slot.slotNumber}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  slot.spiceName.isEmpty
                      ? 'Empty Slot'
                      : slot.spiceName,

                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          TextField(
            controller: spiceController,

            decoration:
            const InputDecoration(
              labelText: 'Spice Name',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: expiryController,

            decoration:
            const InputDecoration(
              labelText: 'Expiry Date',
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [

              Expanded(
                child: ElevatedButton(
                  onPressed: () {

                    onSave(
                      spiceController.text,
                      expiryController.text,
                    );
                  },

                  child: const Text(
                    'Save',
                  ),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: ElevatedButton(
                  onPressed: onRefill,

                  child: const Text(
                    'Refill',
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