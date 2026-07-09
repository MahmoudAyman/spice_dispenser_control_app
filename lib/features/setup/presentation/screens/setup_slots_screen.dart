import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/protocol/responses/ack_response.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
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

  final List<TextEditingController> spiceControllers = List.generate(
    totalSlots,
    (index) => TextEditingController(),
  );

  final List<TextEditingController> expiryControllers = List.generate(
    totalSlots,
    (index) => TextEditingController(),
  );

  @override
  void dispose() {
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
      initialDate: DateTime.now(),
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
        debugPrint('ONBOARDING SYNC -> Sending setup_slot_name: $registerName');

        final AckResponse ack = await bluetoothCubit.bleService.sendCommand(
          command: {
            'type': 'setup_slot_name',
            'name': registerName,
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

        // Show success toast on registering slot name
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registered "$registerName" on Slot ${_currentSlotIndex + 1} successfully!'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 1),
            ),
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
      debugPrint('ONBOARDING SYNC SIMULATION -> Slot ${_currentSlotIndex + 1}: ${isSkipping ? 'Empty' : spiceName}');
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // 2. Client Database Phase
    final slotModel = SlotModel(
      slotNumber: _currentSlotIndex + 1,
      spiceName: isSkipping ? '' : spiceName,
      expiryDate: isSkipping ? '' : expiryDate,
      level: isSkipping ? 0 : 100, // Skipped slots have level 0%, configured slots 100%
    );

    // Save individual slot map into local Hive storage
    await StorageService.slotsBox.put(slotModel.slotNumber, slotModel.toJson());

    setState(() {
      _isSyncing = false;
    });

    // 3. Animation and Slide Transition Phase
    if (_currentSlotIndex < totalSlots - 1) {
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

      return SlotModel(
        slotNumber: index + 1,
        spiceName: isEmpty ? '' : spiceName,
        expiryDate: isEmpty ? '' : expiryDate,
        level: isEmpty ? 0 : 100,
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final progress = (_currentSlotIndex + 1) / totalSlots;

    return Scaffold(
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
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Global Stepper Step Indicator
            const SetupStepIndicator(
              currentStep: 2,
            ),
            const SizedBox(height: 24),

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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      Text(
                        '${((_currentSlotIndex + 1) / totalSlots * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spice Container',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Configure spice name and expiry',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Spice Name Field
            const Text(
              'Spice Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: spiceNameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g., Smoked Paprika',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.restaurant_menu, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // Expiry Date Field
            const Text(
              'Expiry Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expiryController,
              readOnly: true,
              onTap: () => pickDate(index),
              decoration: InputDecoration(
                hintText: 'Select Date',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.calendar_month, size: 20),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
            ),
            
            // Helpful Inline Warning
            if (isFormEdited && !isFormComplete) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please complete both fields or clear them to skip.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 36),

            // Wizard Action Buttons
            Row(
              children: [
                // Previous Button
                if (index > 0) ...[
                  SizedBox(
                    height: 56,
                    width: 64,
                    child: OutlinedButton(
                      onPressed: _isSyncing ? null : _handlePrevious,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Action Button (Save & Sync / Skip Slot)
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canContinue 
                            ? (isFormEdited ? const Color(0xFF2563EB) : Colors.grey[700]) 
                            : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: (canContinue && !_isSyncing) ? _handleNextOrComplete : null,
                      child: _isSyncing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isLast ? 'Finalizing Setup...' : 'Registering Slot...',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Text(
                              buttonText,
                              style: TextStyle(
                                color: canContinue ? Colors.white : Colors.grey[500],
                                fontSize: 16,
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
}
