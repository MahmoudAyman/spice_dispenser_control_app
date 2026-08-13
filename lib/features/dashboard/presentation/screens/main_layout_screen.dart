import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../bluetooth/presentation/screens/connection_screen.dart';
import '../../../recipes/presentation/screens/recipes_screen.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../../sync/services/recipe_sync_service.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => MainLayoutScreenState();
}

class MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Always sync recipes with the machine on app startup/initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRecipesToMachine();
    });
  }

  void _syncRecipesToMachine() {
    try {
      final bluetoothCubit = context.read<BluetoothCubit>();
      final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;
      if (isConnected && bluetoothCubit.bleService.writeCharacteristic != null) {
        final macAddress = bluetoothCubit.bleService.connectedDevice?.remoteId.str ?? 
                           StorageService.getLastMachine()?.deviceId;
        debugPrint('MainLayout: Auto-syncing recipes with machine for MAC: $macAddress...');
        final recipeStorageService = RecipeStorageService(macAddress);
        final recipes = recipeStorageService.getRecipes();
        final syncService = RecipeSyncService();
        syncService.syncAllRecipes(
          bleService: bluetoothCubit.bleService,
          recipes: recipes,
        ).then((result) {
          debugPrint('MainLayout: Auto-sync recipes completed. Success: ${result.isSuccess}');
        }).catchError((e) {
          debugPrint('MainLayout: Auto-sync recipes error: $e');
        });
      }
    } catch (e) {
      debugPrint('MainLayout: Failed to execute recipes auto-sync: $e');
    }
  }

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      try {
        final bluetoothCubit = context.read<BluetoothCubit>();
        final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;
        if (isConnected && bluetoothCubit.bleService.writeCharacteristic != null) {
          debugPrint('MainLayout: Tab switch refresh -> Pulling manifest and levels...');
          bluetoothCubit.syncService.requestManifest().then((_) {
            bluetoothCubit.syncService.requestSync();
          }).catchError((e) {
            debugPrint('MainLayout: Tab switch refresh error: $e');
          });
        }
      } catch (e) {
        debugPrint('MainLayout: Failed tab switch refresh: $e');
      }
    } else if (index == 1) {
      debugPrint('MainLayout: Navigated to Recipes -> Triggering recipe list refresh on machine...');
      _syncRecipesToMachine();
    }
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    RecipesScreen(),
    SettingsScreen(),
  ];

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
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: setTab,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.receipt_long_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.receipt_long),
              ),
              label: 'Recipes',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    ),
    );
  }
}
