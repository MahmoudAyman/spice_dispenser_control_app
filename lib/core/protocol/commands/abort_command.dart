class AbortCommand {

  final String type;

  AbortCommand()
      : type = 'abort';

  Map<String, dynamic> toJson() {

    return {
      'type': type,
    };
  }
}