import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../slots/presentation/screens/container_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoConnectEnabled = true;

  @override
  void initState() {
    super.initState();
    _autoConnectEnabled = StorageService.isAutoConnectEnabled();
  }

  void _triggerFactoryReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Machine Factory Reset?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will permanently erase all configuration, calibrations, and saved spices from BOTH the physical machine and your phone. The machine will reboot instantly.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close confirm dialog
                _executeFactoryReset(context);
              },
              child: const Text('Factory Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeFactoryReset(BuildContext context) async {
    BuildContext? dialogContextRef;

    // Show Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        dialogContextRef = dialogContext;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Text(
                  'Wiping machine database & restarting...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Give dialog transition a moment to register on the Navigator
    await Future.delayed(const Duration(milliseconds: 300));

    final bleCubit = context.read<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;

    if (isConnected) {
      try {
        debugPrint('SETTINGS -> Transmitting {"type": "factory_reset"} over BLE...');
        // Send command to ESP32: {"type": "factory_reset"}
        await bleCubit.bleService.sendCommand(
          command: {'type': 'factory_reset'},
        );
        debugPrint('FACTORY RESET COMMAND ACKNOWLEDGED BY ESP32!');
      } catch (e) {
        debugPrint('Factory reset command transmission failed: $e');
      }
    } else {
      // Simulate physical machine wipe delay offline
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    // Clean up all local phone databases and Hive storage
    await StorageService.clearStorage();

    // Remove loading overlay and route user back to onboarding SetupWelcomeScreen
    if (context.mounted) {
      if (dialogContextRef != null && Navigator.canPop(dialogContextRef!)) {
        Navigator.of(dialogContextRef!).pop(); // Dismiss loading spinner dialog safely
      }
      bleCubit.disconnect();
    }
  }

  void _showMaxFillDialog(BuildContext context) {
    final currentMaxFill = StorageService.getMaxFillGrams();
    final controller = TextEditingController(text: currentMaxFill.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.scale, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Text(
                'Max Container Capacity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set the maximum capacity of your physical spice containers in grams.',
                style: TextStyle(fontSize: 14, color: AppColors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max Capacity (grams)',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                final input = controller.text.trim();
                final value = double.tryParse(input);
                if (value == null || value <= 0.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid capacity'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                
                Navigator.pop(context); // Close dialog
                await _updateMaxFill(value);
              },
              child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateMaxFill(double value) async {
    // Show Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(width: 24),
            Expanded(
              child: Text(
                'Updating dispenser capacity...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    final bleCubit = context.read<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;

    if (isConnected) {
      try {
        debugPrint('SETTINGS -> Sending set_max_fill command: $value grams');
        final ack = await bleCubit.bleService.sendCommand(
          command: {
            'type': 'set_max_fill',
            'max_fill': value,
          },
        );
        debugPrint('set_max_fill ACK: ${ack.status}, max_fill: ${ack.maxFill}');
      } catch (e) {
        debugPrint('Failed to send set_max_fill over BLE: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update machine. Setting locally: $e'), backgroundColor: Colors.amber[800]),
          );
        }
      }
    }

    // Save locally
    await StorageService.setMaxFillGrams(value);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      setState(() {}); // Rebuild to update visual label
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Container capacity updated to ${value.toStringAsFixed(0)}g successfully!'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleCubit = context.watch<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;
    final lastMachine = StorageService.getLastMachine();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Device Info Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isConnected 
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? AppColors.primary : Colors.grey,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastMachine?.deviceName ?? 'No Device Paired',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isConnected ? 'Connected & Synced' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? AppColors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. Settings Sections
            _buildSectionTitle('App Settings'),
            const SizedBox(height: 10),
            _buildSettingsGroup([
              _buildSettingsTile(
                icon: Icons.kitchen,
                color: Colors.blueAccent,
                title: 'Manage Containers',
                subtitle: 'Configure spices, levels and expiry dates',
                  onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContainerManagementScreen(
                        bleService: context.read<BluetoothCubit>().bleService,
                      ),
                    ),
                  );
                },
              ),
              _buildSwitchTile(
                icon: Icons.sync,
                color: Colors.teal,
                title: 'Auto-connect',
                subtitle: 'Auto-connect to favorite device on scan',
                value: _autoConnectEnabled,
                onChanged: (value) async {
                  await StorageService.setAutoConnect(value);
                  setState(() {
                    _autoConnectEnabled = value;
                  });
                },
              ),
              _buildSettingsTile(
                icon: Icons.scale,
                color: Colors.purpleAccent,
                title: 'Max Container Capacity',
                subtitle: 'Current: ${StorageService.getMaxFillGrams().toStringAsFixed(0)}g',
                onTap: () => _showMaxFillDialog(context),
              ),
              _buildSettingsTile(
                icon: Icons.bluetooth,
                color: AppColors.primary,
                title: 'Pair New Device',
                subtitle: 'Scan and pair a different dispenser',
                onTap: () {
                  context.read<BluetoothCubit>().disconnect();
                },
              ),
            ]),
            const SizedBox(height: 28),

            _buildSectionTitle('Maintenance'),
            const SizedBox(height: 10),
            _buildSettingsGroup([
              _buildSettingsTile(
                icon: Icons.restart_alt,
                color: Colors.orangeAccent,
                title: 'Machine Factory Reset',
                subtitle: 'Wipe physical LittleFS and reboot ESP32',
                onTap: () => _triggerFactoryReset(context),
              ),
              _buildSettingsTile(
                icon: Icons.delete_forever,
                color: Colors.redAccent,
                title: 'Clear Application Data',
                subtitle: 'Reset dispenser configuration and setup',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Reset All Data?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                        'This will delete all saved spices, configurations, and paired machine connections from your phone. You will need to complete the setup again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await StorageService.clearStorage();
                            if (context.mounted) {
                              context.read<BluetoothCubit>().disconnect();
                            }
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Spice Dispenser Controller v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tiles.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
        itemBuilder: (context, index) => tiles[index],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey,
          ),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey,
          ),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}
