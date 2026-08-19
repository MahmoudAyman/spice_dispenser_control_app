import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../bluetooth/presentation/screens/connection_screen.dart';
import '../../../container_management/presentation/cubit/spice_cubit.dart';
import '../widgets/setup_step_indicator.dart';
import 'setup_slots_screen.dart';

class SetupWelcomeScreen extends StatefulWidget {
  const SetupWelcomeScreen({
    super.key,
  });

  @override
  State<SetupWelcomeScreen> createState() => _SetupWelcomeScreenState();
}

class _SetupWelcomeScreenState extends State<SetupWelcomeScreen> {
  bool loading = false;

  Future<void> continueSetup() async {
    setState(() {
      loading = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(
          milliseconds: 400,
        ),
        pageBuilder: (_, __, ___) => const SetupSlotsScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return BlocListener<BluetoothCubit, BluetoothState>(
      listener: (context, state) {
        if (state is! BluetoothHandshakeSuccess) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
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
              currentStep: 1,
            ),

            const SizedBox(height: 40),

            Expanded(
              child: Container(
                width: double.infinity,

                padding:
                const EdgeInsets.all(
                  28,
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
                          0xFFEAF2FF,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          32,
                        ),
                      ),

                      child: const Icon(
                        Icons.inventory_2,
                        size: 100,
                        color:
                        Color(
                          0xFF2563EB,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    const Text(
                      'Welcome!',
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
                      'Let’s setup your smart spice dispenser.',
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
                    : continueSetup,

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
                  'Continue',

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
    );
  }
}