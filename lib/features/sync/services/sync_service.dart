import '../../../../core/services/hash_service.dart';
import '../../../../core/storage/storage_service.dart';

class SyncService {

  Future<void> syncMachineState(
      dynamic machineData,
      ) async {

    final incomingHash =
    HashService.generateHash(
      machineData,
    );

    final savedHash =
    StorageService.getMachineHash();

    if (incomingHash != savedHash) {

      /// FULL PULL

      await StorageService
          .saveMachineHash(
        incomingHash,
      );
    }
  }
}