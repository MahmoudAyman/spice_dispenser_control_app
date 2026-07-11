import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../dashboard/presentation/controllers/machine_controller.dart';

class DispensingScreen
    extends StatelessWidget {

  const DispensingScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final controller =
    context.watch<MachineController>();

    final machineState =
        controller.machineState;

    final progress =
        machineState.progress;

    final completed =
        !machineState.dispensing &&
            progress >= 100;

    return Scaffold(

      backgroundColor:
      const Color(0xFFF3F7FC),

      body: Column(

        children: [

          /// TOP HEADER

          Container(

            width: double.infinity,

            padding:
            const EdgeInsets.only(
              top: 70,
              left: 24,
              right: 24,
              bottom: 34,
            ),

            decoration:
            const BoxDecoration(

              color:
              Color(0xFF2563EB),

              borderRadius:
              BorderRadius.only(

                bottomLeft:
                Radius.circular(
                  30,
                ),

                bottomRight:
                Radius.circular(
                  30,
                ),
              ),
            ),

            child: Column(

              children: [

                Icon(

                  completed
                      ? Icons.check_circle
                      : Icons.blender,

                  color:
                  Colors.white,

                  size: 36,
                ),

                const SizedBox(
                  height: 14,
                ),

                Text(

                  completed
                      ? 'Completed'
                      : 'Dispensing',

                  style:
                  const TextStyle(

                    color:
                    Colors.white,

                    fontSize: 32,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(

                  machineState
                      .activeRecipe,

                  style:
                  TextStyle(

                    color:
                    Colors.white
                        .withOpacity(
                      0.9,
                    ),

                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          Expanded(

            child: SingleChildScrollView(

              padding:
              const EdgeInsets.all(
                24,
              ),

              child: Column(

                children: [

                  /// MAIN CARD

                  Container(

                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets.all(
                      28,
                    ),

                    decoration:
                    BoxDecoration(

                      color:
                      Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        34,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black
                              .withOpacity(
                            0.05,
                          ),

                          blurRadius:
                          20,

                          offset:
                          const Offset(
                            0,
                            10,
                          ),
                        ),
                      ],
                    ),

                    child: Column(

                      children: [

                        /// PROGRESS

                        SizedBox(

                          width: 220,
                          height: 220,

                          child: Stack(

                            alignment:
                            Alignment.center,

                            children: [

                              SizedBox(

                                width: 220,
                                height: 220,

                                child:
                                CircularProgressIndicator(

                                  value:
                                  progress /
                                      100,

                                  strokeWidth:
                                  14,

                                  backgroundColor:
                                  Colors.blue
                                      .withOpacity(
                                    0.08,
                                  ),
                                ),
                              ),

                              Column(

                                mainAxisAlignment:
                                MainAxisAlignment.center,

                                children: [

                                  Text(

                                    '$progress%',

                                    style:
                                    const TextStyle(

                                      fontSize:
                                      42,

                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 6,
                                  ),

                                  Text(

                                    completed
                                        ? 'Finished'
                                        : 'Complete',

                                    style:
                                    TextStyle(

                                      color:
                                      Colors.grey
                                          .shade700,

                                      fontSize:
                                      16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 40,
                        ),

                        /// CURRENT DISPENSING

                        Container(

                          width:
                          double.infinity,

                          padding:
                          const EdgeInsets.all(
                            22,
                          ),

                          decoration:
                          BoxDecoration(

                            color:
                            Colors.blue
                                .withOpacity(
                              0.05,
                            ),

                            borderRadius:
                            BorderRadius.circular(
                              24,
                            ),

                            border: Border.all(

                              color:
                              Colors.blue
                                  .withOpacity(
                                0.15,
                              ),
                            ),
                          ),

                          child: Column(

                            children: [

                              Text(

                                completed
                                    ? 'Dispensing Completed'
                                    : 'Currently dispensing',

                                style:
                                TextStyle(

                                  color:
                                  Colors.grey
                                      .shade700,

                                  fontSize:
                                  15,
                                ),
                              ),

                              const SizedBox(
                                height: 14,
                              ),

                              Text(

                                machineState
                                    .activeRecipe,

                                textAlign:
                                TextAlign.center,

                                style:
                                const TextStyle(

                                  fontSize:
                                  30,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 30,
                        ),

                        /// COMPLETED WIDGET

                        if (completed)

                          Container(

                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets.all(
                              26,
                            ),

                            decoration:
                            BoxDecoration(

                              color:
                              Colors.green
                                  .withOpacity(
                                0.08,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                24,
                              ),
                            ),

                            child: Column(

                              children: [

                                const Icon(

                                  Icons.check_circle,

                                  color:
                                  Colors.green,

                                  size: 80,
                                ),

                                const SizedBox(
                                  height: 18,
                                ),

                                const Text(

                                  'Dispensing Completed Successfully',

                                  textAlign:
                                  TextAlign.center,

                                  style:
                                  TextStyle(

                                    fontSize:
                                    22,

                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  /// EMERGENCY BUTTON

                  if (!completed)

                    Column(

                      children: [

                        SizedBox(

                          width:
                          double.infinity,

                          height: 64,

                          child:
                          ElevatedButton.icon(

                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              Colors.red,

                              elevation:
                              0,

                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(
                                  22,
                                ),
                              ),
                            ),

                            onPressed: () async {

                              await controller
                                  .sendEmergencyStop();
                            },

                            icon:
                            const Icon(

                              Icons.stop_circle,

                              color:
                              Colors.white,
                            ),

                            label:
                            const Text(

                              'EMERGENCY STOP',

                              style:
                              TextStyle(

                                color:
                                Colors.white,

                                fontWeight:
                                FontWeight.bold,

                                fontSize:
                                20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        Text(

                          'Tap to abort dispensing immediately',

                          style:
                          TextStyle(

                            color:
                            Colors.grey
                                .shade600,

                            fontSize:
                            15,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}