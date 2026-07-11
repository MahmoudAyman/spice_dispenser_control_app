import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/protocol/commands/dispense_command.dart';
import '../../../../core/protocol/commands/emergency_stop_command.dart';
import '../../../../core/protocol/responses/alert_response.dart';
import '../../../../core/protocol/responses/levels_response.dart';
import '../../../../core/protocol/responses/status_response.dart';
import '../../../../core/services/ble_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../dispensing/data/models/dispense_item_model.dart';
import '../../data/models/machine_status_model.dart';

class MachineController extends ChangeNotifier {
  final BleService bleService = BleService();

  MachineStatusModel machineState =
  MachineStatusModel.initial();

  List<SlotModel> slots = [];

  bool dispensingCompleted = false;

  int? activeDispensingSlot;

  List<int> dispensingQueue = [];

  String currentIngredient = '';

  StreamSubscription? _statusSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _levelsSub;

  MachineController() {
    _listenToProtocol();
  }

  void _listenToProtocol() {
    _statusSub = bleService
        .protocolService
        .statusController
        .stream
        .listen(handleStatusEvent);

    _alertSub = bleService
        .protocolService
        .alertController
        .stream
        .listen(handleAlertEvent);

    _levelsSub = bleService
        .protocolService
        .levelsController
        .stream
        .listen(handleLevelsEvent);
  }

  void setConnected(bool value) {
    machineState =
        machineState.copyWith(
          connected: value,
        );

    notifyListeners();
  }

  void loadSlots(List<SlotModel> loadedSlots) {
    slots = loadedSlots;
    notifyListeners();
  }

  Future<void> startDispensing({
    required List<DispenseItemModel> items,
    required String recipeName,
  }) async {
    try {
      final command = DispenseCommand(
        items: items,
      );

      await bleService.sendCommand(
        command: command.toJson(),
      );

      dispensingCompleted = false;

      dispensingQueue =
          items.map((item) => item.slot).toList();

      activeDispensingSlot =
      items.isNotEmpty ? items.first.slot : null;

      currentIngredient =
      items.isNotEmpty ? items.first.spiceName : '';

      machineState =
          machineState.copyWith(
            dispensing: true,
            progress: 0,
            activeRecipe: recipeName,
            activeIngredient: currentIngredient,
            currentIngredient: currentIngredient,
            currentIngredientGrams:
            items.isNotEmpty ? items.first.grams : 0,
            activeQueueIndex: 0,
            dispensingCompleted: false,
          );

      notifyListeners();
    } catch (e) {
      debugPrint('DISPENSE ERROR: $e');
    }
  }

  void handleStatusEvent(
      StatusResponse status,
      ) {
    final bool isBusy =
        status.state == 'busy';

    machineState =
        machineState.copyWith(
          dispensing: isBusy,
          progress: status.progress,
        );

    if (!isBusy &&
        status.progress >= 100) {
      dispensingCompleted = true;
      activeDispensingSlot = null;
      currentIngredient = '';
      dispensingQueue.clear();

      machineState =
          machineState.copyWith(
            activeIngredient: '',
            currentIngredient: '',
            currentIngredientGrams: 0,
            activeQueueIndex: 0,
            dispensingCompleted: true,
          );
    }

    notifyListeners();
  }

  void handleAlertEvent(
      AlertResponse alert,
      ) {
    machineState =
        machineState.copyWith(
          alertCode: alert.code,
          alertSlot: alert.slot,
        );

    notifyListeners();
  }

  Future<void> handleLevelsEvent(
      LevelsResponse levels,
      ) async {
    final data = levels.data;

    for (int i = 0;
    i < slots.length;
    i++) {
      final slotNumber =
          slots[i].slotNumber;

      if (data.containsKey(slotNumber)) {
        slots[i] =
            slots[i].copyWith(
              level: data[slotNumber],
            );
      }
    }

    await StorageService.saveSlots(
      slots,
    );

    notifyListeners();
  }

  Future<void> sendEmergencyStop() async {
    try {
      final command =
      EmergencyStopCommand();

      await bleService.sendCommand(
        command: command.toJson(),
      );

      resetDispensing();
    } catch (e) {
      debugPrint(
        'EMERGENCY STOP ERROR: $e',
      );
    }
  }

  void clearAlert() {
    machineState =
        machineState.copyWith(
          alertCode: null,
          alertSlot: null,
        );

    notifyListeners();
  }

  void resetDispensing() {
    dispensingCompleted = false;
    activeDispensingSlot = null;
    currentIngredient = '';
    dispensingQueue.clear();

    machineState =
        machineState.copyWith(
          dispensing: false,
          progress: 0,
          activeRecipe: '',
          activeIngredient: '',
          currentIngredient: '',
          currentIngredientGrams: 0,
          activeQueueIndex: 0,
          dispensingCompleted: false,
        );

    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _alertSub?.cancel();
    _levelsSub?.cancel();
    super.dispose();
  }
}