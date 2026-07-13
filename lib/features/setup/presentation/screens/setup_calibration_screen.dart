import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../bluetooth/presentation/screens/connection_screen.dart';
import 'setup_complete_screen.dart';

class SetupCalibrationScreen
    extends StatefulWidget {

  const SetupCalibrationScreen({
    super.key,
  });

  @override
  State<SetupCalibrationScreen>
  createState() =>
      _SetupCalibrationScreenState();
}

class _SetupCalibrationScreenState
    extends State<
        SetupCalibrationScreen> {

  double threshold = 50;

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

        title: const Text(
          'Calibration',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      body: Padding(
        padding:
        const EdgeInsets.all(24),

        child: Column(
          children: [

            const SizedBox(height: 20),

            Container(
              width: double.infinity,

              padding:
              const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                BorderRadius.circular(
                  28,
                ),

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
                children: [

                  const Icon(
                    Icons.tune,
                    size: 90,
                    color: Color(0xFF2563EB),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Global Threshold',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Adjust the spice dispensing sensitivity.',
                    textAlign:
                    TextAlign.center,

                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    threshold
                        .toInt()
                        .toString(),

                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Slider(
                    value: threshold,

                    min: 0,
                    max: 100,

                    onChanged: (value) {

                      setState(() {

                        threshold =
                            value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

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

                onPressed: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const SetupCompleteScreen(),
                    ),
                  );
                },

                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
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
    ),
    );
  }
}