import 'package:flutter/material.dart';

import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../recipes/presentation/screens/recipes_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class BottomNavigationScreen
    extends StatefulWidget {

  const BottomNavigationScreen({
    super.key,
  });

  @override
  State<BottomNavigationScreen>
  createState() =>
      _BottomNavigationScreenState();
}

class _BottomNavigationScreenState
    extends State<
        BottomNavigationScreen> {

  int currentIndex = 0;

  final List<Widget> screens = [

    const DashboardScreen(),

    const RecipesScreen(),

    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),

      bottomNavigationBar:
      NavigationBar(

        selectedIndex:
        currentIndex,

        onDestinationSelected:
            (index) {

          setState(() {

            currentIndex =
                index;
          });
        },

        height: 75,

        backgroundColor:
        Colors.white,

        elevation: 10,

        destinations: const [

          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),

            selectedIcon: Icon(
              Icons.home,
            ),

            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.menu_book_outlined,
            ),

            selectedIcon: Icon(
              Icons.menu_book,
            ),

            label: 'Recipes',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),

            selectedIcon: Icon(
              Icons.settings,
            ),

            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// TEMP RECIPES SCREEN



/// TEMP SETTINGS SCREEN

