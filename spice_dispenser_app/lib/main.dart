import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/flavor_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dev flavor by default
  FlavorConfig.initialize(
    flavor: Flavor.dev,
    appTitle: 'Spice Dispenser (DEV)',
  );

  runApp(
    const ProviderScope(
      child: SpiceDispenserApp(),
    ),
  );
}