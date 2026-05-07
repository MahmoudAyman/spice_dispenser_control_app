import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/ble_service.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../cubit/bluetooth_cubit.dart';
import '../cubit/bluetooth_state.dart';
import '../widgets/device_card.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BluetoothCubit(
        BleService(),
      ),
      child: BlocListener<
          BluetoothCubit,
          BluetoothState>(
        listener: (context, state) {
          if (state
          is BluetoothHandshakeSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const DashboardScreen(),
              ),
            );
          }

          if (state
          is BluetoothHandshakeFailed) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Handshake Failed',
                ),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title:
            const Text('Spice Dispenser'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .read<BluetoothCubit>()
                          .scanDevices();
                    },
                    child: const Text('Scan'),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: BlocBuilder<
                      BluetoothCubit,
                      BluetoothState>(
                    builder: (context, state) {
                      if (state
                      is BluetoothLoading) {
                        return const Center(
                          child:
                          CircularProgressIndicator(),
                        );
                      }

                      if (state
                      is BluetoothConnecting) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Connecting...'),
                            ],
                          ),
                        );
                      }

                      if (state
                      is BluetoothLoaded) {
                        return ListView.builder(
                          itemCount:
                          state.devices.length,
                          itemBuilder:
                              (context, index) {
                            return DeviceCard(
                              device:
                              state.devices[index],
                              onTap: () {
                                context
                                    .read<
                                    BluetoothCubit>()
                                    .connectToDevice(
                                  state.devices[index],
                                );
                              },
                            );
                          },
                        );
                      }

                      if (state
                      is BluetoothError) {
                        return Center(
                          child:
                          Text(state.message),
                        );
                      }

                      return const Center(
                        child: Text(
                          'Ready to scan',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}