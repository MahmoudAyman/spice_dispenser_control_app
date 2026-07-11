import 'package:flutter/material.dart';

import '../../../../core/storage/storage_service.dart';

import '../../../container_management/data/models/slot_model.dart';

import '../widgets/setup_step_indicator.dart';

import 'setup_complete_screen.dart';

class SetupSlotsScreen extends StatefulWidget {
  const SetupSlotsScreen({
    super.key,
  });

  @override
  State<SetupSlotsScreen> createState() =>
      _SetupSlotsScreenState();
}

class _SetupSlotsScreenState
    extends State<SetupSlotsScreen> {
  final List<TextEditingController>
  spiceControllers = List.generate(
    6,
        (_) => TextEditingController(),
  );

  final List<TextEditingController>
  expiryControllers = List.generate(
    6,
        (_) => TextEditingController(),
  );

  bool valid = false;

  void validateFields() {
    bool allFilled = true;

    for (int i = 0; i < 6; i++) {
      if (spiceControllers[i]
          .text
          .trim()
          .isEmpty ||
          expiryControllers[i]
              .text
              .trim()
              .isEmpty) {
        allFilled = false;
      }
    }

    setState(() {
      valid = allFilled;
    });
  }

  Future<void> pickDate(
      int index,
      ) async {
    final date =
    await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: DateTime.now(),
    );

    if (date != null) {
      expiryControllers[index].text =
      '${date.day}/${date.month}/${date.year}';

      validateFields();
    }
  }

  Future<void> saveSlots() async {
    final slots = List.generate(
      6,
          (index) => SlotModel(
        slotNumber: index + 1,

        spiceName:
        spiceControllers[index]
            .text
            .trim(),

        expiryDate:
        expiryControllers[index]
            .text
            .trim(),

        level: 100,

        /// السعة الافتراضية بالجرام
        capacity: 200,

        /// أول مرة مفيش تاريخ refill
        lastRefillDate: '',
      ),
    );

    debugPrint(
      'SAVING SLOTS...',
    );

    await StorageService.saveSlots(
      slots,
    );

    final savedSlots =
    StorageService.getSlots();

    debugPrint(
      'SAVED SLOTS: ${savedSlots.length}',
    );

    for (final slot
    in savedSlots) {
      debugPrint(
        'Slot ${slot.slotNumber}: '
            '${slot.spiceName} '
            'Level=${slot.level}%',
      );
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const SetupCompleteScreen(),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller
    in spiceControllers) {
      controller.dispose();
    }

    for (final controller
    in expiryControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF4F7FB),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF2563EB),

        elevation: 0,

        centerTitle: true,

        title: const Text(
          'Initial Setup',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding:
        const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),

            const SetupStepIndicator(
              currentStep: 2,
            ),

            const SizedBox(
              height: 24,
            ),

            Expanded(
              child:
              ListView.builder(
                itemCount: 6,

                itemBuilder:
                    (context, index) {
                  return Container(
                    margin:
                    const EdgeInsets
                        .only(
                      bottom: 20,
                    ),

                    padding:
                    const EdgeInsets
                        .all(20),

                    decoration:
                    BoxDecoration(
                      color:
                      Colors.white,

                      borderRadius:
                      BorderRadius
                          .circular(
                        28,
                      ),
                    ),

                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,

                              backgroundColor:
                              const Color(
                                0xFFEAF2FF,
                              ),

                              child: Text(
                                '${index + 1}',
                              ),
                            ),

                            const SizedBox(
                              width: 16,
                            ),

                            const Text(
                              'Spice Container',

                              style:
                              TextStyle(
                                fontSize:
                                20,

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        TextField(
                          controller:
                          spiceControllers[
                          index],

                          onChanged: (_) {
                            validateFields();
                          },

                          decoration:
                          InputDecoration(
                            hintText:
                            'Spice Name',

                            filled: true,

                            fillColor:
                            const Color(
                              0xFFF4F7FB,
                            ),

                            border:
                            OutlineInputBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                18,
                              ),

                              borderSide:
                              BorderSide
                                  .none,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextField(
                          controller:
                          expiryControllers[
                          index],

                          readOnly: true,

                          onTap: () {
                            pickDate(
                              index,
                            );
                          },

                          decoration:
                          InputDecoration(
                            hintText:
                            'Expiry Date',

                            suffixIcon:
                            const Icon(
                              Icons
                                  .calendar_month,
                            ),

                            filled: true,

                            fillColor:
                            const Color(
                              0xFFF4F7FB,
                            ),

                            border:
                            OutlineInputBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                18,
                              ),

                              borderSide:
                              BorderSide
                                  .none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SizedBox(
              width:
              double.infinity,

              height: 60,

              child:
              ElevatedButton(
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  valid
                      ? const Color(
                    0xFF2563EB,
                  )
                      : Colors
                      .grey,
                ),

                onPressed:
                valid
                    ? saveSlots
                    : null,

                child: const Text(
                  'Continue',

                  style: TextStyle(
                    color:
                    Colors.white,

                    fontSize: 18,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}