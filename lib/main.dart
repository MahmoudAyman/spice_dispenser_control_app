import 'package:flutter/material.dart';

import 'core/storage/storage_service.dart';

import 'features/bluetooth/presentation/screens/connection_screen.dart';

void main() async {

  WidgetsFlutterBinding
      .ensureInitialized();

  await StorageService.init();

  runApp(
    const MyApp(),
  );
}

class MyApp
    extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return const MaterialApp(
      debugShowCheckedModeBanner:
      false,

      home: ConnectionScreen(),
    );
  }
}