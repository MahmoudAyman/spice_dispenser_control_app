import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../../recipes/data/models/recipe_model.dart';
import 'main_layout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SlotModel> slots = [];
  List<RecipeModel> recentRecipes = [];

  // Polling, live updates, and notification streams subscription hooks
  Timer? _pollingTimer;
  StreamSubscription? _slotsWatchSub;
  StreamSubscription? _recipesWatchSub;
  StreamSubscription? _alertSub;

  final List<String> _notifications = [];
  final List<String> _activeAlerts = []; // Captured live from machine over BLE STATUS
  final Set<String> _dismissedNotifications = {};
  bool _isDispensing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPeriodicPolling();
    _startListeners();
  }

  void _loadData() {
    setState(() {
      slots = StorageService.getSlots();
      
      // Load stored recipes segmented by the connected MAC address
      final recipeService = RecipeStorageService();
      recentRecipes = recipeService.getRecipes().take(2).toList();
      
      _loadNotifications();
    });
    debugPrint('Dashboard: loaded ${slots.length} slots and ${recentRecipes.length} recipes.');
  }

  /// SMART CLIENT ALERTS & WARNINGS CALCULATOR
  /// Centralized system executing local levels & calendar arithmetic expiry warnings
  void _loadNotifications() {
    _notifications.clear();

    // 1. Add active live machine alerts first (e.g. low_spice alarms caught via notify)
    _notifications.addAll(_activeAlerts);

    // 2. Identify physical slots running low locally (fill level <= 20%)
    for (var slot in slots) {
      if (slot.level <= 20 && slot.spiceName.trim().isNotEmpty) {
        _notifications.add('Low Level: "${slot.spiceName}" in Slot ${slot.slotNumber} is running low (${slot.level}%).');
      }
    }

    // 3. Calendar arithmetic check for expired/expiring ingredients
    final now = DateTime.now();
    for (var slot in slots) {
      if (slot.spiceName.trim().isNotEmpty && slot.expiryDate.trim().isNotEmpty) {
        try {
          final parts = slot.expiryDate.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              final expiryDate = DateTime(year, month, day);

              if (expiryDate.isBefore(now)) {
                _notifications.add('Expired Spice: "${slot.spiceName}" in Slot ${slot.slotNumber} has expired on ${slot.expiryDate}!');
              } else if (expiryDate.difference(now).inDays <= 7) {
                final daysLeft = expiryDate.difference(now).inDays;
                _notifications.add('Expiring Soon: "${slot.spiceName}" in Slot ${slot.slotNumber} expires in $daysLeft days (${slot.expiryDate}).');
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to run expiry calendar arithmetic for slot ${slot.slotNumber}: $e');
        }
      }
    }
  }

  /// START PERIODIC POLLING FOR MANIFEST CHANGES
  void _startPeriodicPolling() {
    // Poll levels immediately on loading
    _requestLevels();

    // Setup periodic polling timer (Poll machine LittleFS capacity updates every 10 seconds)
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _requestLevels();
    });
  }

  void _requestLevels() {
    try {
      final bluetoothCubit = context.read<BluetoothCubit>();
      final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;
      if (isConnected && bluetoothCubit.bleService.writeCharacteristic != null) {
        debugPrint('Periodic Poll: requesting updated levels from machine LittleFS...');
        bluetoothCubit.syncService.requestSync(); // Request sync (sends {"type": "get_levels"})
      }
    } catch (e) {
      debugPrint('Polling request failed: $e');
    }
  }

  /// START LIVE STREAM LISTENERS
  void _startListeners() {
    // 1. Listen to background Hive storage updates to slotsBox
    _slotsWatchSub = StorageService.slotsBox.watch().listen((event) {
      debugPrint('Reactive update: slotsBox changed! Reloading dashboard...');
      _loadData();
    });

    // 2. Listen to background Hive storage updates to recipesBox
    _recipesWatchSub = StorageService.recipesBox.watch().listen((event) {
      debugPrint('Reactive update: recipesBox changed! Reloading dashboard recipes...');
      _loadData();
    });

    // 3. Listen to machine alerts caught over STATUS characteristic notification streams
    try {
      final bluetoothCubit = context.read<BluetoothCubit>();
      _alertSub = bluetoothCubit.bleService.protocolService.alertController.stream.listen((alert) {
        debugPrint('Dashboard Stream Alert: code ${alert.code} at slot ${alert.slot}');

        String spiceName = 'Slot ${alert.slot}';
        try {
          final slot = slots.firstWhere((s) => s.slotNumber == alert.slot);
          if (slot.spiceName.isNotEmpty) {
            spiceName = slot.spiceName;
          }
        } catch (_) {}

        String text = '';
        if (alert.code == 'low_spice') {
          text = 'Machine Alert: "$spiceName" in Slot ${alert.slot} is running low/empty during dispensing!';
        } else if (alert.code == 'wrong_spice') {
          text = 'Verification Mismatch! Incorrect spice detected at Slot ${alert.slot} ($spiceName)!';
        } else if (alert.code == 'missing_ingredient') {
          text = 'Dispensing Terminated: Required spice "$spiceName" (Slot ${alert.slot}) could not be located!';
        } else {
          text = 'Alert from dispenser: Code ${alert.code} in slot ${alert.slot}';
        }

        // Add to alerts list dynamically
        if (!_activeAlerts.contains(text)) {
          setState(() {
            _activeAlerts.add(text);
            _loadNotifications();
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to attach alert streams: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _slotsWatchSub?.cancel();
    _recipesWatchSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  Color _getLevelColor(int level) {
    if (level <= 20) return const Color(0xFFEF4444); // Red
    return const Color(0xFF22C55E); // Green
  }

  void _showDispensingDialog(RecipeModel recipe) {
    if (_isDispensing) {
      debugPrint('Dispense already active. Double click ignored.');
      return;
    }
    _isDispensing = true;

    bool isRequesting = true;
    String? errorMessage;
    double progress = 0.0;
    String currentStatusMsg = 'Searching Spices';
    String currentDetail = 'Aligning with dispenser carousel...';
    StreamSubscription? statusSubscription;
    StreamSubscription? alertSubscription;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Helper to handle cancel/abort
            Future<void> handleAbort() async {
              statusSubscription?.cancel();
              alertSubscription?.cancel();
              Navigator.of(dialogContext).pop();
              
              // Write abort command
              try {
                final bluetoothCubit = context.read<BluetoothCubit>();
                await bluetoothCubit.bleService.sendCommand(
                  command: {'type': 'abort'},
                );
              } catch (e) {
                debugPrint('Failed to send abort command: $e');
              }
              _showAbortSnackBar(recipe.name);
            }

            // Start the BLE send order if isRequesting is true and subscription is not set
            if (isRequesting && statusSubscription == null) {
              isRequesting = false; // Set immediately so we don't send multiple times
              
              final bluetoothCubit = context.read<BluetoothCubit>();
              final dispenseItems = recipe.ingredients.map((ing) {
                return {
                  'name': ing.name,
                  'grams': ing.grams,
                };
              }).toList();

              bluetoothCubit.bleService.sendCommand(
                command: {
                  'type': 'dispense',
                  'items': dispenseItems,
                },
              ).then((ack) {
                if (ack.status == 'fail') {
                  String errText = 'The dispenser rejected this dispense command.';
                  if (ack.reason == 'insufficient_spice') {
                    final missingSpice = ack.detail ?? 'unknown';
                    errText = 'Insufficient Spice! "${missingSpice}" is running low or empty on the machine.';
                  } else if (ack.reason != null) {
                    errText = 'Error: ${ack.reason}';
                  }
                  
                  setDialogState(() {
                    errorMessage = errText;
                  });
                } else {
                  // Successfully ACKed! Start listening to physical status stream
                  debugPrint('Dispense command accepted! Listening to live progress stream...');
                  
                  statusSubscription = bluetoothCubit.bleService.protocolService.statusController.stream.listen((status) {
                    debugPrint('Dispense Live Progress: state=${status.state}, progress=${status.progress}');
                    
                    setDialogState(() {
                      progress = status.progress / 100.0;
                      if (status.statusMsg != null && status.statusMsg!.isNotEmpty) {
                        currentStatusMsg = status.statusMsg!;
                      }
                      if (status.detail != null && status.detail!.isNotEmpty) {
                        currentDetail = status.detail!;
                      }
                    });

                    // Check if complete
                    if (status.state.toLowerCase() == 'idle' && status.progress >= 100) {
                      statusSubscription?.cancel();
                      alertSubscription?.cancel();
                      Navigator.of(dialogContext).pop();
                      
                      _showSuccessSnackBar(recipe.name);
                      
                      // Refresh physical levels dynamically
                      _requestLevels();
                    }
                  });

                  // Listen to alert stream in case of mismatch/error
                  alertSubscription = bluetoothCubit.bleService.protocolService.alertController.stream.listen((alert) {
                    debugPrint('Alert received during dispense: ${alert.code}, blocking=${alert.blocking}');
                    
                    if (!alert.blocking) {
                      // SCENARIO B: A passive background warning.
                      // Do NOT disrupt the current layout or dialog. Simply show a brief SnackBar warning!
                      String spiceName = 'Slot ${alert.slot}';
                      try {
                        final slot = slots.firstWhere((s) => s.slotNumber == alert.slot);
                        if (slot.spiceName.isNotEmpty) {
                          spiceName = slot.spiceName;
                        }
                      } catch (_) {}
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Note: "$spiceName" is running low (below 15%).')),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return; // Keep listening, do not close or fail the dialog!
                    }

                    // SCENARIO A: An active blocking error occurred. Halt dispensing and show error modal.
                    String text = 'Machine Alert during dispense: ${alert.code}';
                    if (alert.code == 'low_spice') {
                      text = 'Dispensing Error: Low spice level detected during operation on slot ${alert.slot}.';
                    } else if (alert.code == 'wrong_spice') {
                      text = 'Dispensing Error: TCS3200 sensor detected correct spice mismatch at slot ${alert.slot}!';
                    } else if (alert.code == 'missing_ingredient') {
                      text = 'Dispensing Terminated: Required spice could not be found at slot ${alert.slot}.';
                    }

                    statusSubscription?.cancel();
                    alertSubscription?.cancel();
                    
                    setDialogState(() {
                      errorMessage = text;
                    });
                  });
                }
              }).catchError((e) {
                setDialogState(() {
                  errorMessage = 'Connection Error: Failed to write dispense command to machine.';
                });
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error Screen inside the Dialog
                    if (errorMessage != null) ...[
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                      const SizedBox(height: 20),
                      const Text(
                        'Dispense Failed',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            statusSubscription?.cancel();
                            alertSubscription?.cancel();
                            Navigator.of(dialogContext).pop();
                            
                            // Re-request levels to update screen map in case levels changed
                            _requestLevels();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ]
                    // Connection / Sending command phase
                    else if (statusSubscription == null) ...[
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text(
                        'Connecting with Dispenser...',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Waiting for machine response...',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                    ]
                    // Dispensing state with active real progress
                    else ...[
                      const SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'dispensing',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        currentStatusMsg,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentDetail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: handleAbort,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Abort Dispensing',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isDispensing = false;
      statusSubscription?.cancel();
      alertSubscription?.cancel();
    });
  }

  void _showSuccessSnackBar(String recipeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispensed $recipeName successfully!')),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAbortSnackBar(String recipeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispensing $recipeName aborted!')),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// NO-OVERFLOW CENTRALIZED NOTIFICATIONS PANEL WIDGET
  Widget _buildNotificationsSection(List<String> activeNotifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Color(0xFF0F172A), size: 22),
            const SizedBox(width: 8),
            const Text(
              'Alerts & Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (activeNotifications.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activeNotifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (activeNotifications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All Spices are Fresh & Fully Loaded!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeNotifications.length,
            itemBuilder: (context, idx) {
              final text = activeNotifications[idx];
              
              // Dynamic coloring (Red for critical / Expired, Amber for Warning)
              final isCritical = text.contains('Alert') || text.contains('Expired') || text.contains('Terminated') || text.contains('Mismatch');
              final bgColor = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
              final barColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
              final textColor = isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E);
              final icon = isCritical ? Icons.error_outline_rounded : Icons.warning_amber_rounded;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: barColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(icon, color: barColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: barColor.withOpacity(0.8), size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _dismissedNotifications.add(text);
                                    _activeAlerts.remove(text);
                                    _loadNotifications();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleCubit = context.watch<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;
    final lastMachine = StorageService.getLastMachine();
    final deviceName = lastMachine?.deviceName ?? 'Spice Dispenser #1';

    // Build lists of non-dismissed alerts
    final activeNotifications = _notifications
        .where((n) => !_dismissedNotifications.contains(n))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      body: RefreshIndicator(
        onRefresh: () async {
          _requestLevels();
          _loadData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Blue Premium Custom Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: MediaQuery.of(context).padding.top + 24,
                  bottom: 28,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB), // Vivid Royal Blue
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deviceName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    _buildConnectedBadge(isConnected),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Centralized Warnings & Alerts panel (Central command for levels, live alerts and expiries)
                    _buildNotificationsSection(activeNotifications),
                    
                    const SizedBox(height: 32),

                    // 3. Spice Containers Section Title
                    const Text(
                      'Spice Containers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A), // Slate 900
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Spice Containers Grid
                    slots.isEmpty ? _buildEmptySlotsPlaceholder() : _buildSlotsGrid(),

                    const SizedBox(height: 32),

                    // 5. Recent Recipes Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Recipes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Switch tab in main layout to Recipes tab (index 1)
                            context.findAncestorStateOfType<MainLayoutScreenState>()?.setTab(1);
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 6. Segmented Recent Recipes list
                    if (recentRecipes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu_outlined, color: Colors.grey[400], size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'No custom mixes found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Go to the Recipes tab to create your first mix!',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...recentRecipes.map((recipe) => _buildRecipeCard(recipe)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF22C55E) : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlotsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: const Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 48, color: Color(0xFF64748B)),
          SizedBox(height: 16),
          Text(
            'No Containers Configured',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 8),
          Text(
            'Go to Containers page or complete setup to register your spices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isLow = slot.level <= 20;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slot ${slot.slotNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (isLow)
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  slot.spiceName.isEmpty ? 'Empty Slot' : slot.spiceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${slot.level}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLow ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${slot.level * 2}g',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: slot.level / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getLevelColor(slot.level),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: recipe.ingredients.take(3).map((ing) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${ing.name} (${ing.grams}g)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showDispensingDialog(recipe),
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
              label: const Text(
                'Dispense',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
