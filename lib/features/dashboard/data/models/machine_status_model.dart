class MachineStatusModel {

  final bool initialized;

  final bool connected;

  final bool dispensing;

  final int battery;

  final int progress;

  final String activeRecipe;

  final String activeIngredient;

  final String? alertCode;

  final int? alertSlot;

  /// CURRENT DISPENSING INGREDIENT

  final String currentIngredient;

  final double currentIngredientGrams;

  /// DISPENSING QUEUE

  final int activeQueueIndex;

  /// COMPLETED

  final bool dispensingCompleted;

  MachineStatusModel({

    required this.initialized,

    required this.connected,

    required this.dispensing,

    required this.battery,

    required this.progress,

    required this.activeRecipe,

    required this.activeIngredient,

    this.alertCode,

    this.alertSlot,

    required this.currentIngredient,

    required this.currentIngredientGrams,

    required this.activeQueueIndex,

    required this.dispensingCompleted,
  });

  factory MachineStatusModel.initial() {

    return MachineStatusModel(

      initialized: false,

      connected: false,

      dispensing: false,

      battery: 100,

      progress: 0,

      activeRecipe: '',

      activeIngredient: '',

      alertCode: null,

      alertSlot: null,

      currentIngredient: '',

      currentIngredientGrams: 0,

      activeQueueIndex: 0,

      dispensingCompleted: false,
    );
  }

  MachineStatusModel copyWith({

    bool? initialized,

    bool? connected,

    bool? dispensing,

    int? battery,

    int? progress,

    String? activeRecipe,

    String? activeIngredient,

    String? alertCode,

    int? alertSlot,

    String? currentIngredient,

    double? currentIngredientGrams,

    int? activeQueueIndex,

    bool? dispensingCompleted,
  }) {

    return MachineStatusModel(

      initialized:
      initialized ??
          this.initialized,

      connected:
      connected ??
          this.connected,

      dispensing:
      dispensing ??
          this.dispensing,

      battery:
      battery ??
          this.battery,

      progress:
      progress ??
          this.progress,

      activeRecipe:
      activeRecipe ??
          this.activeRecipe,

      activeIngredient:
      activeIngredient ??
          this.activeIngredient,

      alertCode:
      alertCode ??
          this.alertCode,

      alertSlot:
      alertSlot ??
          this.alertSlot,

      currentIngredient:
      currentIngredient ??
          this.currentIngredient,

      currentIngredientGrams:
      currentIngredientGrams ??
          this.currentIngredientGrams,

      activeQueueIndex:
      activeQueueIndex ??
          this.activeQueueIndex,

      dispensingCompleted:
      dispensingCompleted ??
          this.dispensingCompleted,
    );
  }

  Map<String, dynamic> toJson() {

    return {

      'initialized':
      initialized,

      'connected':
      connected,

      'dispensing':
      dispensing,

      'battery':
      battery,

      'progress':
      progress,

      'activeRecipe':
      activeRecipe,

      'activeIngredient':
      activeIngredient,

      'alertCode':
      alertCode,

      'alertSlot':
      alertSlot,

      'currentIngredient':
      currentIngredient,

      'currentIngredientGrams':
      currentIngredientGrams,

      'activeQueueIndex':
      activeQueueIndex,

      'dispensingCompleted':
      dispensingCompleted,
    };
  }

  factory MachineStatusModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return MachineStatusModel(

      initialized:
      json['initialized'] ?? false,

      connected:
      json['connected'] ?? false,

      dispensing:
      json['dispensing'] ?? false,

      battery:
      json['battery'] ?? 100,

      progress:
      json['progress'] ?? 0,

      activeRecipe:
      json['activeRecipe'] ?? '',

      activeIngredient:
      json['activeIngredient'] ?? '',

      alertCode:
      json['alertCode'],

      alertSlot:
      json['alertSlot'],

      currentIngredient:
      json['currentIngredient'] ?? '',

      currentIngredientGrams:
      (json['currentIngredientGrams'] ?? 0)
          .toDouble(),

      activeQueueIndex:
      json['activeQueueIndex'] ?? 0,

      dispensingCompleted:
      json['dispensingCompleted'] ?? false,
    );
  }
}