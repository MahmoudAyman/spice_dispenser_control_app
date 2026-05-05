import 'package:flutter/material.dart';
import 'core/utils/flavor_config.dart';

class SpiceDispenserApp extends StatelessWidget {
  const SpiceDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlavorConfig.instance.appTitle,
      debugShowCheckedModeBanner: FlavorConfig.isDev,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
      ),
      // Landing point for the app
      home: Scaffold(
        appBar: AppBar(title: Text(FlavorConfig.instance.appTitle)),
        body: const Center(
          child: Text('Spice Dispenser Base Initialized'),
        ),
      ),
    );
  }
}