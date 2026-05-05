enum Flavor { dev, mock, prod }

class FlavorConfig {
  final Flavor flavor;
  final String appTitle;

  static FlavorConfig? _instance;

  FlavorConfig._internal(this.flavor, this.appTitle);

  static void initialize({required Flavor flavor, required String appTitle}) {
    _instance = FlavorConfig._internal(flavor, appTitle);
  }

  static FlavorConfig get instance => _instance!;
  
  static bool get isDev => _instance?.flavor == Flavor.dev;
  static bool get isMock => _instance?.flavor == Flavor.mock;
}