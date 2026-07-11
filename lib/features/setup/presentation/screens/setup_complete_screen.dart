import 'package:flutter/material.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../navigation/presentation/screens/bottom_navigation_screen.dart';
import '../widgets/setup_step_indicator.dart';

class SetupCompleteScreen extends StatefulWidget {
  const SetupCompleteScreen({
    super.key,
  });

  @override
  State<SetupCompleteScreen> createState() =>
      _SetupCompleteScreenState();
}

class _SetupCompleteScreenState
    extends State<SetupCompleteScreen> {
  bool loading = false;

  Future<void> finishSetup() async {
    setState(() {
      loading = true;
    });

    debugPrint(
      'SETUP COMPLETE -> SAVING INITIALIZED FLAG',
    );

    await StorageService.setInitialized(
      true,
    );

    debugPrint(
      'INITIALIZED FLAG SAVED SUCCESSFULLY',
    );

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const BottomNavigationScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight =
        MediaQuery.of(context).size.height;

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

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),

          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
              screenHeight - 140,
            ),

            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),

                  const SetupStepIndicator(
                    currentStep: 3,
                  ),

                  const SizedBox(
                    height: 40,
                  ),

                  Expanded(
                    child: Container(
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
                          32,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors
                                .black
                                .withOpacity(
                              0.05,
                            ),

                            blurRadius: 12,
                            offset:
                            const Offset(
                              0,
                              4,
                            ),
                          ),
                        ],
                      ),

                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                        children: [
                          Container(
                            width: 150,
                            height: 150,

                            decoration:
                            const BoxDecoration(
                              color: Color(
                                0xFFE9FFF0,
                              ),

                              shape:
                              BoxShape
                                  .circle,
                            ),

                            child:
                            const Icon(
                              Icons.check,
                              size: 90,
                              color:
                              Colors
                                  .green,
                            ),
                          ),

                          const SizedBox(
                            height: 32,
                          ),

                          const Text(
                            'Setup Complete!',
                            textAlign:
                            TextAlign
                                .center,

                            style:
                            TextStyle(
                              fontSize:
                              30,

                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          const Text(
                            'Your smart spice dispenser is ready to use.\nAll settings have been saved successfully.',

                            textAlign:
                            TextAlign
                                .center,

                            style:
                            TextStyle(
                              color:
                              Colors
                                  .grey,

                              fontSize:
                              16,

                              height:
                              1.5,
                            ),
                          ),

                          const SizedBox(
                            height: 28,
                          ),

                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal:
                              16,
                              vertical: 14,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFFF3F7FF,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                18,
                              ),
                            ),

                            child: Row(
                              children: const [
                                Icon(
                                  Icons
                                      .storage_rounded,
                                  color:
                                  Color(
                                    0xFF2563EB,
                                  ),
                                ),

                                SizedBox(
                                  width:
                                  12,
                                ),

                                Expanded(
                                  child:
                                  Text(
                                    'Local database initialized successfully.',
                                    style:
                                    TextStyle(
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 24,
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
                        const Color(
                          0xFF2563EB,
                        ),

                        elevation: 0,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            18,
                          ),
                        ),
                      ),

                      onPressed:
                      loading
                          ? null
                          : finishSetup,

                      child:
                      loading
                          ? const SizedBox(
                        width:
                        24,
                        height:
                        24,

                        child:
                        CircularProgressIndicator(
                          color:
                          Colors
                              .white,

                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'Go To Dashboard',

                        style:
                        TextStyle(
                          color:
                          Colors
                              .white,

                          fontSize:
                          18,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}