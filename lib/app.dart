import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/ble_service.dart';
import 'core/theme/app_theme.dart';
import 'features/bluetooth/presentation/cubit/bluetooth_cubit.dart';
import 'features/bluetooth/presentation/screens/connection_screen.dart';
import 'features/container_management/presentation/cubit/spice_cubit.dart';
import 'features/sync/services/spice_sync_service.dart';

class SpiceDispenserApp extends StatelessWidget {
  const SpiceDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => BleService()),
        RepositoryProvider(
          create: (context) => SpiceSyncService(
            bleService: RepositoryProvider.of<BleService>(context),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => BluetoothCubit(
              RepositoryProvider.of<BleService>(context),
            ),
          ),
          BlocProvider(
            create: (context) => SpiceCubit(
              RepositoryProvider.of<SpiceSyncService>(context),
            ),
          ),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spice Dispenser',
      theme: AppTheme.lightTheme,
      home: ConnectionScreen(),
    );
  }
}