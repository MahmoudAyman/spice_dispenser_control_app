import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../sync/services/spice_sync_service.dart';
import '../../data/models/spice_definition_model.dart';
import 'spice_state.dart';

class SpiceCubit extends Cubit<SpiceState> {
  final SpiceSyncService _spiceSyncService;

  SpiceCubit(this._spiceSyncService) : super(SpiceInitial());

  Future<void> fetchSpices() async {
    try {
      emit(SpiceLoading());
      final spices = await _spiceSyncService.fetchSpiceDefinitions();
      emit(SpiceLoaded(spices));
    } catch (e) {
      emit(SpiceError('Failed to fetch spices: $e'));
    }
  }

  Future<void> addNewSpice(String name, double density) async {
    try {
      emit(SpiceLoading());
      final definition = SpiceDefinition(name: name, density: density);
      final ack = await _spiceSyncService.addNewSpiceDefinition(definition);
      if (ack.isSuccess) {
        await fetchSpices();
      } else {
        emit(SpiceError('Failed to add spice: ${ack.status}'));
      }
    } catch (e) {
      emit(SpiceError('Failed to add spice: $e'));
    }
  }
}
