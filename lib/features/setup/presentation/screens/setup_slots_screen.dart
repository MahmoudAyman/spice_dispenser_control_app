import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/protocol/responses/ack_response.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../bluetooth/presentation/screens/connection_screen.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../container_management/presentation/cubit/spice_cubit.dart';
import '../../../../features/slots/presentation/widgets/spice_selection_dialog.dart';
import '../../../container_management/data/models/spice_definition_model.dart';
import '../widgets/setup_step_indicator.dart';
import 'setup_complete_screen.dart';

class SetupSlotsScreen extends StatefulWidget {
  const SetupSlotsScreen({
    super.key,
  });

  @override
  State<SetupSlotsScreen> createState() => _SetupSlotsScreenState();
}

class _SetupSlotsScreenState extends State<SetupSlotsScreen> {
  static const int totalSlots = 20;

  final PageController _pageController = PageController();
  int _currentSlotIndex = 0;
  bool _isSyncing = false;
  bool _isHoming = false;
  String _homingStatus = 'Initializing...';
  StreamSubscription? _statusSubscription;
  StreamSubscription? _setupReadySubscription;
  Timer? _homingPollTimer;

  final List<TextEditingController> spiceControllers = List.generate(
    totalSlots,
    (index) => TextEditingController(),
  );

  final List<TextEditingController> expiryControllers = List.generate(
    totalSlots,
    (index) => TextEditingController(),
  );

  final List<DateTime?> _selectedExpiryDates = List.generate(
    totalSlots,
    (index) => null,
  );

  final List<int> fillLevels = List.generate(
    totalSlots,
    (index) => 100,
  );

  @override
  void initState() {
    super.initState();
    _checkHomingStatus();
  }

  void _checkHomingStatus() {
    final bluetoothCubit = context.read<BluetoothCubit>();
    final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;

    if (!isConnected) {
      _isHoming = false;
      return;
    }

    // Default to true and await confirmations
    _isHoming = true;
    _homingStatus = 'Finding home...';

    _statusSubscription = bluetoothCubit.bleService.protocol.statusController.stream.listen((status) {
      debugPrint('HOMING CHECK -> Received status update: state=${status.state}, detail=${status.detail}, msg=${status.statusMsg}');
      
      final detail = status.detail ?? '';
      final msg = status.statusMsg ?? '';

      if (status.state.toLowerCase() == 'setup') {
        final isHomingDetail = detail.contains('Finding home') || detail.contains('Initializing configuration');
        final isSetupReady = msg.contains('Setup Slot') || detail.contains('Awaiting name configuration');

        if (isHomingDetail && !isSetupReady) {
          setState(() {
            _isHoming = true;
            _homingStatus = status.detail ?? 'Finding home...';
          });
        } else {
          setState(() {
            _isHoming = false;
          });
          _cancelHomingSubscriptions();
        }
      } else {
        setState(() {
          _isHoming = false;
        });
        _cancelHomingSubscriptions();
      }
    });

    _setupReadySubscription = bluetoothCubit.bleService.protocol.setupReadyController.stream.listen((ready) {
      debugPrint('HOMING CHECK -> Received setup ready for slot: ${ready.slot}');
      if (ready.slot >= 1) {
        setState(() {
          _isHoming = false;
        });
        _cancelHomingSubscriptions();
      }
    });

    // Start periodic polling to request status every 2 seconds until homing is complete
    _homingPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        debugPrint('HOMING CHECK -> Polling status from machine...');
        bluetoothCubit.bleService.writeCommand(
          command: {'type': 'get_status'},
        );
      } catch (e) {
        debugPrint('HOMING CHECK -> Failed status poll command transmission: $e');
      }
    });

    // Request initial status immediately
    try {
      bluetoothCubit.bleService.writeCommand(
        command: {'type': 'get_status'},
      );
    } catch (e) {
      debugPrint('HOMING CHECK -> Failed to send initial get_status: $e');
    }
  }

  void _cancelHomingSubscriptions() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _setupReadySubscription?.cancel();
    _setupReadySubscription = null;
    _homingPollTimer?.cancel();
    _homingPollTimer = null;
  }

  @override
  void dispose() {
    _cancelHomingSubscriptions();
    _pageController.dispose();
    for (var controller in spiceControllers) {
      controller.dispose();
    }
    for (var controller in expiryControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate(int index) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _selectedExpiryDates[index] ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      _selectedExpiryDates[index] = date;
      expiryControllers[index].text = '${date.day}/${date.month}/${date.year}';
      setState(() {});
    }
  }

  Future<void> _handleNextOrComplete() async {
    if (_isSyncing) return;

    final spiceName = spiceControllers[_currentSlotIndex].text.trim();
    final expiryDate = expiryControllers[_currentSlotIndex].text.trim();
    final isSkipping = spiceName.isEmpty && expiryDate.isEmpty;

    setState(() {
      _isSyncing = true;
    });

    final bluetoothCubit = context.read<BluetoothCubit>();
    final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;

    // 1. BLE Machine Sync Phase
    if (isConnected) {
      try {
        final registerName = isSkipping ? 'Slot ${_currentSlotIndex + 1}' : spiceName;
        final level = isSkipping ? 0 : fillLevels[_currentSlotIndex];
        debugPrint('ONBOARDING SYNC -> Sending setup_slot_name: $registerName with level $level%');

        final AckResponse ack = await bluetoothCubit.bleService.sendCommand(
          command: {
            'type': 'setup_slot_name',
            'name': registerName,
            'level': level,
          },
          timeout: const Duration(seconds: 5),
        );

        debugPrint('ONBOARDING SYNC ACK RECEIVED: Status: ${ack.status}, Success: ${ack.isSuccess}');

        if (ack.status.toLowerCase() == 'fail') {
          // Sync rejected by MCU (e.g. duplicate name, empty name or invalid state)
          String errorMsg = 'Failed to register slot name.';
          if (ack.reason == 'duplicate_name') {
            errorMsg = '"${ack.detail ?? registerName}" is already assigned to another container. Name must be unique!';
          } else if (ack.reason == 'empty_name') {
            errorMsg = 'Slot name cannot be empty on the machine.';
          } else if (ack.reason == 'invalid_state') {
            errorMsg = 'Machine is not in configuration onboarding mode.';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(errorMsg)),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }

          setState(() {
            _isSyncing = false;
          });
          return; // Abort page transition, keep input unlocked for the same slot!
        }

        // Show success toast on registering slot name and waiting message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_currentSlotIndex < totalSlots - 1 
                ? 'Registered Slot ${_currentSlotIndex + 1}! Waiting for machine to align next container...'
                : 'Registered "$registerName" on Slot ${_currentSlotIndex + 1} successfully!'),
              backgroundColor: const Color(0xFF22C55E),
              duration: _currentSlotIndex < totalSlots - 1 ? const Duration(seconds: 5) : const Duration(seconds: 1),
            ),
          );
        }

        // Wait for ready message if there is a next slot
        if (_currentSlotIndex < totalSlots - 1) {
          final nextSlotId = _currentSlotIndex + 2;
          debugPrint('ONBOARDING SYNC -> Waiting for setup_ready_for_slot for slot ID: $nextSlotId');

          final completer = Completer<void>();
          late StreamSubscription sub;

          sub = bluetoothCubit.bleService.protocol.setupReadyController.stream.listen((ready) {
            debugPrint('ONBOARDING SYNC -> Received setup_ready_for_slot for slot: ${ready.slot}');
            if (ready.slot == nextSlotId) {
              completer.complete();
              sub.cancel();
            }
          });

          await completer.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              sub.cancel();
              throw Exception('Timeout waiting for machine to align next container.');
            },
          );
        }

      } catch (e) {
        debugPrint('Onboarding sync BLE timeout/failure: $e');
        // If connection dropped or timeout occurred, show a snackbar warning
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('BLE Sync Timeout. Transitioning offline: $e'),
              backgroundColor: Colors.amber[800],
            ),
          );
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }
    } else {
      // Simulation/Offline fallback when machine is disconnected
      final level = isSkipping ? 0 : fillLevels[_currentSlotIndex];
      debugPrint('ONBOARDING SYNC SIMULATION -> Slot ${_currentSlotIndex + 1}: ${isSkipping ? 'Empty' : spiceName} at $level%');
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // 2. Client Database Phase
    final epochSecs = isSkipping
        ? null
        : (_selectedExpiryDates[_currentSlotIndex] != null
            ? (_selectedExpiryDates[_currentSlotIndex]!.millisecondsSinceEpoch ~/ 1000)
            : null);

    final slotModel = SlotModel(
      slotNumber: _currentSlotIndex + 1,
      spiceName: isSkipping ? 'Slot ${_currentSlotIndex + 1}' : spiceName,
      expiryEpoch: epochSecs,
      level: isSkipping ? 0 : fillLevels[_currentSlotIndex],
    );

    // Save individual slot map into local Hive storage prefixed by MAC address
    final macAddress = StorageService.getLastMachine()?.deviceId;
    final prefix = macAddress != null ? '${macAddress}_' : '';
    await StorageService.slotsBox.put('${prefix}${slotModel.slotNumber}', slotModel.toJson());

    setState(() {
      _isSyncing = false;
    });

    // 3. Animation and Slide Transition Phase
    if (_currentSlotIndex < totalSlots - 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Completed the 20th and final slot setup
      await _finalizeAllSlots();
    }
  }

  Future<void> _finalizeAllSlots() async {
    // Generate full list of 20 slots based on current form controllers
    final allSlots = List.generate(totalSlots, (index) {
      final spiceName = spiceControllers[index].text.trim();
      final expiryDate = expiryControllers[index].text.trim();
      final isEmpty = spiceName.isEmpty && expiryDate.isEmpty;

      final epochSecs = isEmpty
          ? null
          : (_selectedExpiryDates[index] != null
              ? (_selectedExpiryDates[index]!.millisecondsSinceEpoch ~/ 1000)
              : null);

      return SlotModel(
        slotNumber: index + 1,
        spiceName: isEmpty ? 'Slot ${index + 1}' : spiceName,
        expiryEpoch: epochSecs,
        level: isEmpty ? 0 : fillLevels[index],
      );
    });

    debugPrint('FINALIZING SETUP -> Persisting all $totalSlots slots to database...');
    await StorageService.saveSlots(allSlots);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SetupCompleteScreen(),
      ),
    );
  }

  void _handlePrevious() {
    if (_currentSlotIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _buildHomingWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Machine Homing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _homingStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please wait while the spice dispenser aligns to Slot 1...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final progress = (_currentSlotIndex + 1) / totalSlots;

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
        backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Container Configuration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isHoming 
            ? _buildHomingWidget()
            : Column(
                children: [
                  const SizedBox(height: 10),
                  // Global Stepper Step Indicator
                  const SetupStepIndicator(
                    currentStep: 2,
                  ),
                  const SizedBox(height: 12),

                  // Card progress label and bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spice Container ${_currentSlotIndex + 1} of $totalSlots',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            Text(
                              '${((_currentSlotIndex + 1) / totalSlots * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Slide PageView representing individual cards
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Require buttons to navigate to validate syncing
                      onPageChanged: (index) {
                        setState(() {
                          _currentSlotIndex = index;
                        });
                      },
                      itemCount: totalSlots,
                      itemBuilder: (context, index) {
                        return _buildSlotConfigCard(index, screenHeight);
                      },
                    ),
                  ),
                ],
              ),
      ),
    ),
    );
  }

  Widget _buildSlotConfigCard(int index, double screenHeight) {
    final isLast = index == totalSlots - 1;
    final spiceNameController = spiceControllers[index];
    final expiryController = expiryControllers[index];

    final isFormEdited = spiceNameController.text.trim().isNotEmpty || expiryController.text.trim().isNotEmpty;
    final isFormComplete = spiceNameController.text.trim().isNotEmpty && expiryController.text.trim().isNotEmpty;
    
    // Can continue if complete, or if completely untouched (skip mode)
    final canContinue = isFormComplete || !isFormEdited;
    final buttonText = _isSyncing 
        ? 'Syncing to dispenser...' 
        : (isLast 
            ? 'Complete Setup' 
            : (isFormEdited ? 'Save & Sync Slot' : 'Skip Slot'));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spice Container',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Configure spice name and expiry',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Spice Name Field
            const Text(
              'Select a Spice',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final selectedSpice = await showDialog<SpiceDefinition>(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: context.read<SpiceCubit>(),
                    child: const SpiceSelectionDialog(),
                  ),
                );
                if (selectedSpice != null) {
                  spiceNameController.text = selectedSpice.name;
                  setState(() {});
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: spiceNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g., Smoked Paprika',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.restaurant_menu, size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Expiry Date Field
            const Text(
              'Expiry Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: expiryController,
              readOnly: true,
              onTap: () => pickDate(index),
              decoration: InputDecoration(
                hintText: 'Select Date',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.calendar_month, size: 18),
                suffixIcon: const Icon(Icons.arrow_drop_down, size: 18),
              ),
            ),
            const SizedBox(height: 8),

            // Initial Fill Level Field
            const Text(
              'Initial Fill Level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            _buildFillLevelSelector(index),
            
            // Helpful Inline Warning
            if (isFormEdited && !isFormComplete) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Please complete both fields or clear them to skip.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Wizard Action Buttons
            Row(
              children: [
                // Previous Button
                if (index > 0) ...[
                  SizedBox(
                    height: 44,
                    width: 52,
                    child: OutlinedButton(
                      onPressed: _isSyncing ? null : _handlePrevious,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.grey[300]!, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Action Button (Save & Sync / Skip Slot)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canContinue 
                            ? (isFormEdited ? const Color(0xFF2563EB) : Colors.grey[700]) 
                            : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: (canContinue && !_isSyncing) ? _handleNextOrComplete : null,
                      child: _isSyncing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isLast ? 'Finalizing...' : 'Registering...',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Text(
                              buttonText,
                              style: TextStyle(
                                color: canContinue ? Colors.white : Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFillLevelSelector(int index) {
    const levels = [25, 50, 75, 100];
    const levelLabels = ['Quarter', 'Half', '¾ Full', 'Full'];
    const levelIcons = [
      Icons.battery_1_bar,
      Icons.battery_3_bar,
      Icons.battery_5_bar,
      Icons.battery_full,
    ];

    final currentLevel = fillLevels[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(levels.length, (i) {
              final selected = currentLevel == levels[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => fillLevels[index] = levels[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: i < levels.length - 1 ? 4 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.2), blurRadius: 4)]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Icon(levelIcons[i], color: selected ? Colors.white : Colors.grey.shade600, size: 16),
                        const SizedBox(height: 2),
                        Text(
                          '${levels[i]}%',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          levelLabels[i],
                          style: TextStyle(
                            color: selected ? Colors.white70 : Colors.grey.shade500,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
