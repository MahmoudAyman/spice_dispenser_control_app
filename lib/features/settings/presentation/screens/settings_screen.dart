import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/ble_service.dart';
import '../../../../../core/storage/storage_service.dart';

import '../../../bluetooth/data/models/last_connected_machine_model.dart';
import '../../../bluetooth/presentation/screens/connection_screen.dart';
import '../../../recipes/presentation/controllers/recipe_controller.dart';
import '../../../setup/presentation/screens/setup_welcome_screen.dart';
import '../../../slots/presentation/screens/container_management_screen.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {

  const SettingsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final LastConnectedMachineModel? machine =
    StorageService.getLastMachine();

    return Scaffold(

      backgroundColor: const Color(0xFFF5F7FB),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              /// HEADER

              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(

                  color: const Color(0xFF2563EB),

                  borderRadius:
                  BorderRadius.circular(28),
                ),

                child: Column(

                  children: [

                    const Icon(

                      Icons.settings,

                      color: Colors.white,

                      size: 60,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(

                      'Settings',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 32,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(

                      machine != null
                          ? 'Connected to ${machine.deviceName}'
                          : 'No Device Connected',

                      style: const TextStyle(

                        color: Colors.white70,

                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              /// DEVICE CARD

              Container(

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(24),

                  boxShadow: [

                    BoxShadow(

                      color:
                      Colors.black.withOpacity(
                        0.05,
                      ),

                      blurRadius: 12,
                    ),
                  ],
                ),

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Device Information',

                      style: TextStyle(

                        fontSize: 20,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildInfoRow(
                      'Device Name',
                      machine?.deviceName ??
                          'Unknown',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildInfoRow(
                      'Device ID',
                      machine?.deviceId ??
                          'Unknown',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildInfoRow(
                      'Firmware',
                      'v1.0.0',
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              /// CONTAINER MANAGEMENT

              const Text(
                'Container Management',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SettingsTile(
                icon: Icons.inventory_2,
                title: 'Manage Containers',
                subtitle: 'Edit spices, refill slots, sync levels',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const ContainerManagementScreen(),
                    ),
                  );
                },
              ),


              const SizedBox(
                height: 28,
              ),

              /// CONNECTION

              const Text(

                'Connection',

                style: TextStyle(

                  fontSize: 22,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SettingsTile(

                icon:
                Icons.bluetooth_disabled,

                title: 'Disconnect',

                subtitle:
                'Disconnect from current device',

                onTap: () async {

                  final confirm =
                  await _showConfirmDialog(

                    context,

                    title: 'Disconnect',

                    message:
                    'Disconnect from the current machine?',
                  );

                  if (confirm != true) {
                    return;
                  }

                  await BleService()
                      .disconnectDevice();

                  Navigator.pushAndRemoveUntil(

                    context,

                    MaterialPageRoute(

                      builder: (_) =>
                      const ConnectionScreen(),
                    ),

                        (_) => false,
                  );
                },
              ),

              SettingsTile(

                icon: Icons.sync_alt,

                title: 'Change Device',

                subtitle:
                'Connect to another machine',

                onTap: () async {

                  await BleService()
                      .disconnectDevice();

                  Navigator.pushAndRemoveUntil(

                    context,

                    MaterialPageRoute(

                      builder: (_) =>
                      const ConnectionScreen(),
                    ),

                        (_) => false,
                  );
                },
              ),

              const SizedBox(
                height: 28,
              ),

              /// MACHINE

              const Text(

                'Machine',

                style: TextStyle(

                  fontSize: 22,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SettingsTile(

                icon: Icons.restart_alt,

                title: 'Reset Setup',

                subtitle:
                'Run setup wizard again',

                onTap: () async {

                  final confirm =
                  await _showConfirmDialog(

                    context,

                    title: 'Reset Setup',

                    message:
                    'Run setup again?',
                  );

                  if (confirm != true) {
                    return;
                  }

                  await StorageService
                      .setInitialized(false);

                  Navigator.pushAndRemoveUntil(

                    context,

                    MaterialPageRoute(

                      builder: (_) =>
                      const SetupWelcomeScreen(),
                    ),

                        (_) => false,
                  );
                },
              ),

              SettingsTile(

                icon: Icons.memory,

                title: 'Firmware',

                subtitle: 'Version 1.0.0',

                onTap: () {},
              ),

              const SizedBox(
                height: 28,
              ),

              /// STORAGE

              const Text(

                'Storage',

                style: TextStyle(

                  fontSize: 22,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SettingsTile(

                icon:
                Icons.menu_book_outlined,

                title: 'Clear Recipes',

                subtitle:
                'Delete all saved recipes',

                onTap: () async {

                  final confirm =
                  await _showConfirmDialog(

                    context,

                    title: 'Clear Recipes',

                    message:
                    'Delete all recipes?',
                  );

                  if (confirm != true) {
                    return;
                  }

                  await StorageService
                      .recipesBox
                      .clear();

                  context
                      .read<RecipesController>()
                      .loadRecipes();

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(

                    const SnackBar(

                      content: Text(
                        'Recipes cleared',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 24,
              ),

              /// DANGER ZONE

              SizedBox(

                width: double.infinity,

                height: 60,

                child: ElevatedButton.icon(

                  style:
                  ElevatedButton.styleFrom(

                    backgroundColor:
                    Colors.red,

                    shape:
                    RoundedRectangleBorder(

                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  onPressed: () async {

                    final confirm =
                    await _showConfirmDialog(

                      context,

                      title: 'Clear Storage',

                      message:
                      'This will erase all app data. Continue?',
                    );

                    if (confirm != true) {
                      return;
                    }

                    await StorageService
                        .clearStorage();

                    await BleService()
                        .disconnectDevice();

                    Navigator.pushAndRemoveUntil(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                        const ConnectionScreen(),
                      ),

                          (_) => false,
                    );
                  },

                  icon: const Icon(

                    Icons.delete_forever,

                    color: Colors.white,
                  ),

                  label: const Text(

                    'CLEAR STORAGE',

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 16,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildInfoRow(
      String title,
      String value,
      ) {

    return Row(

      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

      children: [

        Text(

          title,

          style: TextStyle(

            color: Colors.grey.shade600,

            fontSize: 15,
          ),
        ),

        Flexible(

          child: Text(

            value,

            textAlign: TextAlign.end,

            style: const TextStyle(

              fontWeight:
              FontWeight.w600,

              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  static Future<bool?> _showConfirmDialog(

      BuildContext context, {

        required String title,

        required String message,
      }) {

    return showDialog<bool>(

      context: context,

      builder: (_) {

        return AlertDialog(

          title: Text(title),

          content: Text(message),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(

              onPressed: () {

                Navigator.pop(
                  context,
                  true,
                );
              },

              child: const Text(
                'Confirm',
              ),
            ),
          ],
        );
      },
    );
  }
}