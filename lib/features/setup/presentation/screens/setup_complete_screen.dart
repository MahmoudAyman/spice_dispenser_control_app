import 'package:flutter/material.dart';

import '../../../../core/storage/storage_service.dart';

import '../../../dashboard/presentation/screens/dashboard_screen.dart';

import '../widgets/setup_step_indicator.dart';

class SetupCompleteScreen
    extends StatefulWidget {

  const SetupCompleteScreen({
    super.key,
  });

  @override
  State<SetupCompleteScreen>
  createState() =>
      _SetupCompleteScreenState();
}

class _SetupCompleteScreenState
    extends State<
        SetupCompleteScreen> {

  bool loading = false;

  Future<void> finishSetup()
  async {

    setState(() {
      loading = true;
    });

    await StorageService
        .setInitialized(true);

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const DashboardScreen(),
      ),

          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

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
        const EdgeInsets.all(24),

        child: Column(
          children: [

            const SizedBox(height: 20),

            const SetupStepIndicator(
              currentStep: 3,
            ),

            const SizedBox(height: 40),

            Expanded(
              child: Container(
                width: double.infinity,

                padding:
                const EdgeInsets.all(
                  32,
                ),

                decoration:
                BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    32,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(
                        0.05,
                      ),

                      blurRadius: 12,
                    ),
                  ],
                ),

                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,

                  children: [

                    Container(
                      width: 180,
                      height: 180,

                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFFE9FFF0,
                        ),

                        shape:
                        BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.check,
                        size: 100,
                        color:
                        Colors.green,
                      ),
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    const Text(
                      'Setup Complete!',
                      textAlign:
                      TextAlign.center,

                      style: TextStyle(
                        fontSize: 34,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Your smart spice dispenser is ready to use.',

                      textAlign:
                      TextAlign.center,

                      style: TextStyle(
                        color:
                        Colors.grey,

                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 60,

              child: ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF2563EB,
                  ),

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
                  width: 24,
                  height: 24,

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
    );
  }
}