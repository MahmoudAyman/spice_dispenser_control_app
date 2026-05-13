import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/ble_service.dart';
import 'core/theme/app_theme.dart';
import 'features/bluetooth/presentation/cubit/bluetooth_cubit.dart';
import 'features/bluetooth/presentation/screens/connection_screen.dart';

class SpiceDispenserApp extends StatelessWidget {
  const SpiceDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spice Dispenser',
      theme: AppTheme.lightTheme,
      home: BlocProvider(
        create: (context) => BluetoothCubit(BleService()),
        child: ConnectionScreen(),
      ),
    );
  }
}