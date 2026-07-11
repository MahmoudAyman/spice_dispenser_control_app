import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/ble_service.dart';

import '../../../../../core/services/uuid_service.dart';

import '../../../../../core/storage/storage_service.dart';


import '../../../navigation/presentation/screens/bottom_navigation_screen.dart';
import '../../../setup/presentation/screens/setup_welcome_screen.dart';

import '../cubit/bluetooth_cubit.dart';

import '../cubit/bluetooth_state.dart';

import '../widgets/device_card.dart';

class ConnectionScreen
    extends StatelessWidget {

  const ConnectionScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return BlocProvider(
      create: (_) =>
      BluetoothCubit(
        BleService(),
      )
        ..tryAutoReconnect(),

      child: BlocListener<
          BluetoothCubit,
          BluetoothState>(
        listener:
            (context, state) {

          if (state
          is BluetoothHandshakeSuccess) {

            final initialized =
            StorageService
                .isInitialized();

            if (initialized) {

              Navigator.pushReplacement(
                context,

                MaterialPageRoute(
                  builder: (_) =>
                  const BottomNavigationScreen(),
                ),
              );

            } else {

              Navigator.pushReplacement(
                context,

                MaterialPageRoute(
                  builder: (_) =>
                  const SetupWelcomeScreen(),
                ),
              );
            }
          }

          if (state
          is BluetoothHandshakeFailed) {

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content: Text(
                  'Authentication Failed',
                ),
              ),
            );
          }
        },

        child: Scaffold(
          backgroundColor:
          const Color(
            0xFFF1F5F9,
          ),

          body: SafeArea(
            child: Column(
              children: [

                /// HEADER
                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 30,
                  ),

                  decoration:
                  const BoxDecoration(
                    color:
                    Color(
                      0xFF2563EB,
                    ),
                  ),

                  child:
                  const Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                        children: [

                          Icon(
                            Icons
                                .bluetooth,

                            color:
                            Colors
                                .white,
                          ),

                          SizedBox(
                            width:
                            12,
                          ),

                          Text(
                            'Spice Dispenser',

                            style:
                            TextStyle(
                              color:
                              Colors
                                  .white,

                              fontSize:
                              32,

                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        height: 10,
                      ),

                      Center(
                        child: Text(
                          'Connect to your device',

                          style:
                          TextStyle(
                            color:
                            Colors
                                .white70,

                            fontSize:
                            16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// SCAN BAR
                Container(
                  color:
                  Colors.white,

                  padding:
                  const EdgeInsets.all(
                    16,
                  ),

                  child: Row(
                    children: [

                      const Icon(
                        Icons.bluetooth,

                        color:
                        Colors.grey,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                        BlocBuilder<
                            BluetoothCubit,
                            BluetoothState>(
                          builder:
                              (
                              context,
                              state,
                              ) {

                            if (state
                            is BluetoothLoading) {

                              return const Text(
                                'Scanning...',

                                style:
                                TextStyle(
                                  fontSize:
                                  16,

                                  fontWeight:
                                  FontWeight
                                      .w500,
                                ),
                              );
                            }

                            if (state
                            is BluetoothConnecting ||

                                state
                                is BluetoothAutoConnecting) {

                              return const Text(
                                'Authenticating...',

                                style:
                                TextStyle(
                                  fontSize:
                                  16,

                                  fontWeight:
                                  FontWeight
                                      .w500,
                                ),
                              );
                            }

                            return const Text(
                              'Ready to scan',

                              style:
                              TextStyle(
                                fontSize:
                                16,

                                fontWeight:
                                FontWeight
                                    .w500,
                              ),
                            );
                          },
                        ),
                      ),

                      BlocBuilder<
                          BluetoothCubit,
                          BluetoothState>(
                        builder:
                            (
                            context,
                            state,
                            ) {

                          final isScanning =
                              state
                              is BluetoothLoading ||

                                  state
                                  is BluetoothAutoConnecting;

                          return SizedBox(
                            height: 50,

                            child:
                            ElevatedButton(
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                isScanning
                                    ? Colors
                                    .grey
                                    : const Color(
                                  0xFF2563EB,
                                ),

                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    12,
                                  ),
                                ),
                              ),

                              onPressed:
                              isScanning
                                  ? null
                                  : () async {

                                final uuid =
                                await UuidService
                                    .getUuid();

                                print(
                                  'USER UUID: $uuid',
                                );

                                final lastMachine =
                                StorageService
                                    .getLastMachine();

                                print(
                                  'LAST MACHINE: ${lastMachine?.deviceName}',
                                );

                                context
                                    .read<
                                    BluetoothCubit>()
                                    .scanDevices();
                              },

                              child: Row(
                                mainAxisSize:
                                MainAxisSize
                                    .min,

                                children: [

                                  if (isScanning)
                                    const SizedBox(
                                      width:
                                      18,

                                      height:
                                      18,

                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth:
                                        2,

                                        color:
                                        Colors
                                            .white,
                                      ),
                                    ),

                                  if (isScanning)
                                    const SizedBox(
                                      width:
                                      10,
                                    ),

                                  Text(
                                    isScanning
                                        ? 'Scanning...'
                                        : 'Scan',

                                    style:
                                    const TextStyle(
                                      color:
                                      Colors
                                          .white,

                                      fontWeight:
                                      FontWeight
                                          .bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                /// TITLE
                const Padding(
                  padding:
                  EdgeInsets.only(
                    top: 24,
                    left: 20,
                    right: 20,
                    bottom: 12,
                  ),

                  child: Row(
                    children: [

                      Text(
                        'Available Devices',

                        style:
                        TextStyle(
                          fontSize: 30,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ],
                  ),
                ),

                /// DEVICES LIST
                Expanded(
                  child:
                  BlocBuilder<
                      BluetoothCubit,
                      BluetoothState>(
                    builder:
                        (
                        context,
                        state,
                        ) {

                      if (state
                      is BluetoothLoading) {

                        return const Center(
                          child:
                          CircularProgressIndicator(),
                        );
                      }

                      if (state
                      is BluetoothConnecting ||

                          state
                          is BluetoothAutoConnecting) {

                        return const Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                            children: [

                              CircularProgressIndicator(),

                              SizedBox(
                                height:
                                20,
                              ),

                              Text(
                                'Authenticating Device...',

                                style:
                                TextStyle(
                                  fontSize:
                                  18,

                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state
                      is BluetoothLoaded) {

                        if (state
                            .devices
                            .isEmpty) {

                          return const Center(
                            child: Text(
                              'No Devices Found',
                            ),
                          );
                        }

                        return ListView
                            .builder(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal:
                            20,
                          ),

                          itemCount:
                          state
                              .devices
                              .length,

                          itemBuilder:
                              (
                              context,
                              index,
                              ) {

                            return DeviceCard(
                              device:
                              state
                                  .devices[
                              index],

                              onTap:
                                  () {

                                context
                                    .read<
                                    BluetoothCubit>()
                                    .connectToDevice(
                                  state
                                      .devices[
                                  index],
                                );
                              },
                            );
                          },
                        );
                      }

                      if (state
                      is BluetoothError) {

                        return Center(
                          child: Text(
                            state
                                .message,
                          ),
                        );
                      }

                      return const SizedBox();
                    },
                  ),
                ),

                /// FOOTER
                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.all(
                    20,
                  ),

                  color:
                  Colors.white,

                  child:
                  const Text(
                    'Make sure your Spice Dispenser is powered on and within range',

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      Colors.grey,

                      fontSize:
                      14,
                    ),
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