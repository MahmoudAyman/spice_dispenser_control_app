class SyncCommand {

  final String type;

  SyncCommand()
      : type = 'sync';

  Map<String, dynamic> toJson() {

    return {
      'type': type,
    };
  }
}