import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../../recipes/data/models/recipe_model.dart';
import '../../../slots/presentation/screens/container_management_screen.dart';
import 'main_layout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SlotModel> slots = [];
  List<RecipeModel> recentRecipes = [];

  List<SlotModel> get _nonSkippedSlots {
    return slots.where((s) {
      final name = s.spiceName.trim();
      return name.isNotEmpty && !name.startsWith('Slot ');
    }).toList();
  }

  // Polling, live updates, and notification streams subscription hooks
  Timer? _pollingTimer;
  StreamSubscription? _slotsWatchSub;
  StreamSubscription? _recipesWatchSub;
  StreamSubscription? _alertSub;

  final List<String> _notifications = [];
  final List<String> _activeAlerts = []; // Captured live from machine over BLE STATUS
  final Set<String> _dismissedNotifications = {};
  bool _isDispensing = false;
  bool _notificationsExpanded = false;

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

    final lowLevelThreshold = StorageService.getLowLevelThreshold();

    // 2. Identify physical slots running low locally (fill level <= lowLevelThreshold%)
    for (var slot in slots) {
      final name = slot.spiceName.trim();
      final isSkipped = name.isEmpty || name.startsWith('Slot ');
      if (!isSkipped && slot.level <= lowLevelThreshold) {
        _notifications.add('Low Level: "${slot.spiceName}" in Slot ${slot.slotNumber} is running low (${slot.level}%).');
      }
    }

    // 3. Calendar arithmetic check for expired/expiring ingredients
    for (var slot in slots) {
      final name = slot.spiceName.trim();
      final isSkipped = name.isEmpty || name.startsWith('Slot ');
      if (!isSkipped) {
        if (slot.isExpired) {
          _notifications.add('Expired Spice: "${slot.spiceName}" in Slot ${slot.slotNumber} has expired on ${slot.expiryDisplayString}!');
        } else if (slot.isExpiringSoon) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch((slot.expiryEpoch ?? 0) * 1000);
          final daysLeft = expiryDate.difference(DateTime.now()).inDays;
          _notifications.add('Expiring Soon: "${slot.spiceName}" in Slot ${slot.slotNumber} expires in $daysLeft days (${slot.expiryDisplayString}).');
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
        debugPrint('Periodic Poll: requesting updated manifest and levels from machine...');
        bluetoothCubit.syncService.requestManifest().then((_) {
          bluetoothCubit.syncService.requestSync(); // Request sync (sends {"type": "get_levels"})
        }).catchError((e) {
          debugPrint('Failed background manifest/levels poll: $e');
        });
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
      _alertSub = bluetoothCubit.bleService.protocol.alertController.stream.listen((alert) {
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
                  
                  statusSubscription = bluetoothCubit.bleService.protocol.statusController.stream.listen((status) {
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
                  alertSubscription = bluetoothCubit.bleService.protocol.alertController.stream.listen((alert) {
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
        GestureDetector(
          onTap: activeNotifications.isEmpty
              ? null
              : () {
                  setState(() {
                    _notificationsExpanded = !_notificationsExpanded;
                  });
                },
          behavior: HitTestBehavior.opaque,
          child: Row(
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
                const Spacer(),
                Icon(
                  _notificationsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF64748B),
                  size: 24,
                ),
              ],
            ],
          ),
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
        else if (_notificationsExpanded) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _dismissedNotifications.addAll(activeNotifications);
                    _activeAlerts.clear();
                    _loadNotifications();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 18),
                label: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: barColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
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
              );
            },
          ),
        ]
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
                    
                    const SizedBox(height: 24),

                    // NEW: Manual Dispense Widget
                    _buildManualDispenseCard(isConnected),

                    const SizedBox(height: 32),

                    // 3. Spice Containers Section Title with Manage All action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Spice Containers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A), // Slate 900
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ContainerManagementScreen(
                                  bleService: context.read<BluetoothCubit>().bleService,
                                ),
                              ),
                            ).then((_) {
                              _loadData();
                            });
                          },
                          child: const Text(
                            'Manage All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Spice Containers Grid
                    _nonSkippedSlots.isEmpty ? _buildEmptySlotsPlaceholder() : _buildSlotsGrid(),

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
    final displayedSlots = _nonSkippedSlots;
    return SizedBox(
      height: 240,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: displayedSlots.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.66,
        ),
        itemBuilder: (context, index) {
          final slot = displayedSlots[index];
          final isLow = slot.level <= StorageService.getLowLevelThreshold();

          return Container(
            width: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slot ${slot.slotNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      if (isLow)
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                    ],
                  ),
                  Text(
                    slot.spiceName.isEmpty ? 'Empty Slot' : slot.spiceName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${slot.level}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isLow ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${(slot.level * StorageService.getMaxFillGrams() / 100.0).toStringAsFixed(0)}g',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: slot.level / 100.0,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getLevelColor(slot.level),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManualDispenseCard(bool isConnected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_outlined,
              color: Color(0xFF2563EB),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Manual Dispense',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dispense directly from any slot instantly without recipes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              if (!isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please connect to the dispenser first.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              _showManualDispenseDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? const Color(0xFF2563EB) : Colors.grey[300],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Dispense',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualDispenseDialog() {
    final nonUnconfiguredSlots = slots.where((s) => s.spiceName.trim().isNotEmpty && !s.spiceName.startsWith('Slot ')).toList();

    if (nonUnconfiguredSlots.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('No Spices Registered', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Please configure your slot containers and assign spice names before dispensing.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    SlotModel selectedSlot = nonUnconfiguredSlots.first;
    double selectedGrams = 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Manual Dispense',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // SLOT SELECTOR LABEL
                  const Text(
                    'SELECT SPICE CONTAINER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // SLOT DROPDOWN
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SlotModel>(
                        value: selectedSlot,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setSheetState(() {
                              selectedSlot = newValue;
                            });
                          }
                        },
                        items: nonUnconfiguredSlots.map((slot) {
                          return DropdownMenuItem<SlotModel>(
                            value: slot,
                            child: Text(
                              'Slot ${slot.slotNumber}: ${slot.spiceName} (${slot.level}%)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // QUANTITY LABEL
                  const Text(
                    'DISPENSE QUANTITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TACILE QUANTITY SELECTOR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuantityAdjustButton(
                        icon: Icons.remove,
                        onPressed: () {
                          if (selectedGrams > 0.5) {
                            setSheetState(() {
                              selectedGrams = (selectedGrams - 0.5);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${selectedGrams.toStringAsFixed(1)}g',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildQuantityAdjustButton(
                        icon: Icons.add,
                        onPressed: () {
                          if (selectedGrams < 20.0) {
                            setSheetState(() {
                              selectedGrams = (selectedGrams + 0.5);
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // QUICK PRESET BADGES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1.0, 2.0, 3.0, 5.0, 10.0].map((preset) {
                      final isSelected = selectedGrams == preset;
                      return ChoiceChip(
                        label: Text(
                          '${preset.toStringAsFixed(0)}g',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        onSelected: (bool selected) {
                          if (selected) {
                            setSheetState(() {
                              selectedGrams = preset;
                            });
                          }
                        },
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // DISPENSE SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // Close manual sheet first
                        Navigator.pop(sheetContext);

                        // Instantiate temporary RecipeModel to invoke dispensing sequence
                        final tempRecipe = RecipeModel(
                          id: 'manual_dispense_${DateTime.now().millisecondsSinceEpoch}',
                          name: selectedSlot.spiceName,
                          ingredients: [
                            RecipeIngredient(
                              name: selectedSlot.spiceName,
                              grams: selectedGrams,
                            ),
                          ],
                          duration: 5,
                        );

                        // Show standard live progress dialog
                        _showDispensingDialog(tempRecipe);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Dispense ${selectedSlot.spiceName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuantityAdjustButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF0F172A), size: 24),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(),
      ),
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
