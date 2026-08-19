import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../sync/services/spice_sync_service.dart';
import '../../data/models/spice_definition_model.dart';
import 'spice_state.dart';

class SpiceCubit extends Cubit<SpiceState> {
  final SpiceSyncService _spiceSyncService;
  List<SpiceDefinition>? _spices;

  SpiceCubit(this._spiceSyncService) : super(SpiceInitial());

  Future<void> fetchSpices({bool forceRefresh = false}) async {
    if (state is SpiceLoading) return;

    // 1. Try to load from memory first
    if (!forceRefresh && _spices != null && _spices!.isNotEmpty) {
      emit(SpiceLoaded(_spices!));
      return;
    }

    // 2. Try to load from local storage
    final cached = StorageService.getSpiceDefinitions();
    if (!forceRefresh && cached.isNotEmpty) {
      _spices = cached;
      emit(SpiceLoaded(cached));
      return;
    }

    // 3. Fetch from BLE and update storage
    try {
      emit(SpiceLoading());
      final spices = await _spiceSyncService.fetchSpiceDefinitions();
      _spices = spices;
      await StorageService.saveSpiceDefinitions(spices);
      emit(SpiceLoaded(spices));
    } catch (e) {
      // If we have some cached data, fall back to cached instead of showing error
      if (cached.isNotEmpty) {
        _spices = cached;
        emit(SpiceLoaded(cached));
      } else {
        emit(SpiceError('Failed to fetch spices: $e'));
      }
    }
  }

  Future<void> addNewSpice(String name, double density) async {
    try {
      emit(SpiceLoading());
      final definition = SpiceDefinition(name: name, density: density);
      final ack = await _spiceSyncService.addNewSpiceDefinition(definition);
      if (ack.isSuccess) {
        clearSpices();
        await fetchSpices();
      } else {
        emit(SpiceError('Failed to add spice: ${ack.status}'));
      }
    } catch (e) {
      emit(SpiceError('Failed to add spice: $e'));
    }
  }

  void clearSpices() {
    _spices = null;
    emit(SpiceInitial());
  }
}
