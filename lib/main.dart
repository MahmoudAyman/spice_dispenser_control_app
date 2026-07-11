import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/storage/storage_service.dart';

import 'features/bluetooth/presentation/screens/connection_screen.dart';

import 'features/dashboard/presentation/controllers/machine_controller.dart';

import 'features/navigation/presentation/screens/bottom_navigation_screen.dart';

import 'features/recipes/presentation/controllers/recipe_controller.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.init();

  final bool isInitialized =
  StorageService
      .isMachineInitialized();

  runApp(

    MyApp(
      isInitialized:
      isInitialized,
    ),
  );
}

class MyApp
    extends StatelessWidget {

  final bool isInitialized;

  const MyApp({
    super.key,
    required this.isInitialized,
  });

  @override
  Widget build(
      BuildContext context,
      ) {

    return MultiProvider(

      providers: [

        /// MACHINE

        ChangeNotifierProvider(

          create: (_) =>
              MachineController(),
        ),

        /// RECIPES

        ChangeNotifierProvider(

          create: (_) =>

          RecipesController()

            ..loadRecipes(),
        ),
      ],

      child: MaterialApp(

        debugShowCheckedModeBanner:
        false,

        home: const ConnectionScreen(),
      ),
    );
  }
}