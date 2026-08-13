import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../../sync/services/recipe_sync_service.dart';
import '../../data/models/recipe_model.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late RecipeStorageService _recipeStorageService;
  List<RecipeModel> _recipes = [];
  List<SlotModel> _availableSlots = [];
  bool _isDispensing = false;

  @override
  void initState() {
    super.initState();
    _initStorage();
    _loadData();
    _cleanInvalidRecipes();
  }

  void _initStorage() {
    final bluetoothCubit = context.read<BluetoothCubit>();
    final macAddress = bluetoothCubit.bleService.connectedDevice?.remoteId.str ?? 
                       StorageService.getLastMachine()?.deviceId;
    _recipeStorageService = RecipeStorageService(macAddress);
  }

  void _loadData() {
    // Load available slots (spices) from storage
    _availableSlots = StorageService.getSlots();

    // Load recipes from storage for this specific machine (Categorized by MAC)
    _recipes = _recipeStorageService.getRecipes();
    setState(() {});
  }

  /// SELF-HEALING DATABASE MIGRATION & CLEANUP
  /// Sweeps away legacy/invalid recipes containing unregistered ingredients or old defaults
  void _cleanInvalidRecipes() async {
    final activeSpices = _availableSlots
        .where((s) => s.spiceName.trim().isNotEmpty)
        .map((s) => s.spiceName.trim().toLowerCase())
        .toSet();

    final allRecipes = _recipeStorageService.getRecipes();
    bool cleanedAny = false;

    for (var recipe in allRecipes) {
      bool hasInvalid = false;
      
      if (recipe.ingredients.isEmpty) {
        hasInvalid = true;
      } else {
        for (var ing in recipe.ingredients) {
          if (!activeSpices.contains(ing.name.trim().toLowerCase())) {
            hasInvalid = true;
            break;
          }
        }
      }

      // Detect old placeholder ids and remove them
      final isPresetId = recipe.id == 'italian_seasoning' || 
                         recipe.id == 'taco_mix' || 
                         recipe.id == 'curry_powder';

      if (hasInvalid || isPresetId) {
        await _recipeStorageService.deleteRecipe(recipe.id);
        cleanedAny = true;
        debugPrint('Self-Healing: Deleted invalid/legacy recipe: ${recipe.name}');
      }
    }

    if (cleanedAny) {
      _loadData();
    }
  }

  /// TRANSACTIONAL SYNC & DATABASE OPERATION HELPER (With automatic rollback)
  Future<void> _performDbAndSync({
    required Future<void> Function() dbOperation,
    required String successMessage,
  }) async {
    // Backup current recipe list in case rollback is needed
    final previousRecipes = List<RecipeModel>.from(_recipes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Syncing recipes with machine...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Updating dispenser local memory...',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Perform database operation locally
      await dbOperation();

      // 2. Fetch updated list
      final updatedRecipes = _recipeStorageService.getRecipes();

      // 3. Sync entire list to the connected ESP32
      final bluetoothCubit = context.read<BluetoothCubit>();
      final syncService = RecipeSyncService();
      
      final result = await syncService.syncAllRecipes(
        bleService: bluetoothCubit.bleService,
        recipes: updatedRecipes,
      );

      // Dismiss progress dialog safely
      if (mounted) {
        Navigator.pop(context);
      }

      if (result.isSuccess) {
        // Reload GUI
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(successMessage)),
                ],
              ),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } else {
        // Rollback on machine validation failure
        debugPrint('Sync failed. Reverting local recipe DB changes...');
        for (var recipe in updatedRecipes) {
          await _recipeStorageService.deleteRecipe(recipe.id);
        }
        for (var recipe in previousRecipes) {
          await _recipeStorageService.addRecipe(recipe);
        }
        _loadData();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  // Fixes the right overflow by 20 pixels issue in the dialog title
                  Expanded(
                    child: Text('Machine Refused Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.errorReason ?? 'The dispenser rejected this configuration.',
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  if (result.missingIngredient != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Missing Spice: "${result.missingIngredient}" must be physically setup on the machine first.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xDD000000)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss progress dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Revert local changes on unexpected exception
      for (var recipe in previousRecipes) {
        await _recipeStorageService.addRecipe(recipe);
      }
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error during sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteRecipe(RecipeModel recipe) {
    _performDbAndSync(
      dbOperation: () async {
        await _recipeStorageService.deleteRecipe(recipe.id);
      },
      successMessage: 'Deleted "${recipe.name}" successfully!',
    );
  }

  void _requestLevels() {
    try {
      final bluetoothCubit = context.read<BluetoothCubit>();
      final isConnected = bluetoothCubit.state is BluetoothHandshakeSuccess;
      if (isConnected && bluetoothCubit.bleService.writeCharacteristic != null) {
        debugPrint('Recipes Screen: requesting levels refresh from machine...');
        bluetoothCubit.syncService.requestSync(); // Sends {"type": "get_levels"}
      }
    } catch (e) {
      debugPrint('Failed to request levels: $e');
    }
  }

  void _showDispensingDialog(RecipeModel recipe) {
    if (_isDispensing) {
      debugPrint('Dispense already active. Double click ignored.');
      return;
    }
    _isDispensing = true;

    bool isRequesting = true;
    String? errorMessage;
    double progress = 0.0;
    String currentStatusMsg = 'Searching Spices';
    String currentDetail = 'Aligning with dispenser carousel...';
    StreamSubscription? statusSubscription;
    StreamSubscription? alertSubscription;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Helper to handle cancel/abort
            Future<void> handleAbort() async {
              statusSubscription?.cancel();
              alertSubscription?.cancel();
              Navigator.of(dialogContext).pop();
              
              // Write abort command
              try {
                final bluetoothCubit = context.read<BluetoothCubit>();
                await bluetoothCubit.bleService.sendCommand(
                  command: {'type': 'abort'},
                );
              } catch (e) {
                debugPrint('Failed to send abort: $e');
              }
              _showAbortSnackBar(recipe.name);
            }

            // Start the BLE send order if isRequesting is true and subscription is not set
            if (isRequesting && statusSubscription == null) {
              isRequesting = false; // Set immediately so we don't send multiple times
              
              final bluetoothCubit = context.read<BluetoothCubit>();
              final dispenseItems = recipe.ingredients.map((ing) {
                return {
                  'name': ing.name,
                  'grams': ing.grams,
                };
              }).toList();

              // Send the command
              bluetoothCubit.bleService.sendCommand(
                command: {
                  'type': 'dispense',
                  'items': dispenseItems,
                },
                timeout: const Duration(seconds: 4),
              ).then((ack) {
                if (ack.status == 'fail') {
                  // Failed to dispense! Check reasons (insufficient_spice, etc.)
                  String errorText = 'The machine refused to dispense this recipe.';
                  if (ack.reason == 'insufficient_spice') {
                    final missingSpice = ack.detail ?? 'unknown spice';
                    errorText = 'Insufficient Spice! "${missingSpice}" is running low or is below the required amount in the machine.';
                  } else if (ack.reason != null) {
                    errorText = 'Rejected by machine: ${ack.reason}';
                    if (ack.detail != null) {
                      errorText += ' (${ack.detail})';
                    }
                  }
                  
                  setDialogState(() {
                    errorMessage = errorText;
                  });
                } else {
                  // Successfully ACKed! Start listening to physical status stream
                  debugPrint('Dispense command accepted! Listening to live progress stream...');
                  
                  statusSubscription = bluetoothCubit.bleService.protocolService.statusController.stream.listen((status) {
                    debugPrint('Dispense Live Progress: state=${status.state}, progress=${status.progress}');
                    
                    setDialogState(() {
                      progress = status.progress / 100.0;
                      if (status.statusMsg != null && status.statusMsg!.isNotEmpty) {
                        currentStatusMsg = status.statusMsg!;
                      }
                      if (status.detail != null && status.detail!.isNotEmpty) {
                        currentDetail = status.detail!;
                      }
                    });

                    // Check if complete
                    if (status.state.toLowerCase() == 'idle' && status.progress >= 100) {
                      statusSubscription?.cancel();
                      alertSubscription?.cancel();
                      Navigator.of(dialogContext).pop();
                      
                      _showSuccessSnackBar(recipe.name);
                      
                      // Refresh physical levels dynamically
                      _requestLevels();
                    }
                  });

                  // Listen to alert stream in case of mismatch/error
                  alertSubscription = bluetoothCubit.bleService.protocolService.alertController.stream.listen((alert) {
                    debugPrint('Alert received during dispense: ${alert.code}, blocking=${alert.blocking}');
                    
                    if (!alert.blocking) {
                      // SCENARIO B: A passive background warning.
                      // Do NOT disrupt the current layout or dialog. Simply show a brief SnackBar warning!
                      String spiceName = 'Slot ${alert.slot}';
                      try {
                        final slot = _availableSlots.firstWhere((s) => s.slotNumber == alert.slot);
                        if (slot.spiceName.isNotEmpty) {
                          spiceName = slot.spiceName;
                        }
                      } catch (_) {}
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Note: "$spiceName" is running low (below 15%).')),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return; // Keep listening, do not close or fail the dialog!
                    }

                    // SCENARIO A: An active blocking error occurred. Halt dispensing and show error modal.
                    String text = 'Machine Alert during dispense: ${alert.code}';
                    if (alert.code == 'low_spice') {
                      text = 'Dispensing Error: Low spice level detected during operation on slot ${alert.slot}.';
                    } else if (alert.code == 'wrong_spice') {
                      text = 'Dispensing Error: TCS3200 sensor detected correct spice mismatch at slot ${alert.slot}!';
                    } else if (alert.code == 'missing_ingredient') {
                      text = 'Dispensing Terminated: Required spice could not be found at slot ${alert.slot}.';
                    }

                    statusSubscription?.cancel();
                    alertSubscription?.cancel();
                    
                    setDialogState(() {
                      errorMessage = text;
                    });
                  });
                }
              }).catchError((e) {
                setDialogState(() {
                  errorMessage = 'Connection Error: Failed to write dispense command to machine.';
                });
              });
            }

            // BUILD DIALOG WIDGET
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error Screen inside the Dialog
                    if (errorMessage != null) ...[
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                      const SizedBox(height: 20),
                      const Text(
                        'Dispense Failed',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            statusSubscription?.cancel();
                            alertSubscription?.cancel();
                            Navigator.of(dialogContext).pop();
                            
                            // Re-request levels to update screen map in case levels changed
                            _requestLevels();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ]
                    // Connection / Sending command phase
                    else if (statusSubscription == null) ...[
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text(
                        'Connecting with Dispenser...',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Waiting for machine response...',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                    ]
                    // Dispensing state with active real progress
                    else ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        currentStatusMsg,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentDetail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: handleAbort,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Abort Dispensing',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isDispensing = false;
      statusSubscription?.cancel();
      alertSubscription?.cancel();
    });
  }

  void _showSuccessSnackBar(String recipeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispensed $recipeName successfully!')),
          ],
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAbortSnackBar(String recipeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispensing $recipeName aborted!')),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Recipes',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeFormScreen(),
                ),
              ).then((_) => _loadData());
            },
            tooltip: 'Create Custom Recipe',
          ),
        ],
      ),
      body: _recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu_outlined, size: 64, color: AppColors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Recipes Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create custom spice mixes to dispense them instantly.',
                    style: TextStyle(fontSize: 14, color: AppColors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecipeFormScreen(),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Your First Recipe', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              recipe.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${recipe.duration}s',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recipe.ingredients.map((ingredient) {
                          return Chip(
                            label: Text(
                              '${ingredient.name} (${ingredient.grams}g)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            backgroundColor: AppColors.primary.withOpacity(0.85),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDispensingDialog(recipe),
                              icon: const Icon(Icons.play_arrow, color: Colors.white),
                              label: const Text(
                                'Dispense Mix',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // EDIT ICON BUTTON (Pushes RecipeFormScreen full route)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeFormScreen(recipe: recipe),
                                ),
                              ).then((_) => _loadData());
                            },
                            tooltip: 'Edit Recipe',
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Recipe?'),
                                  content: Text('Are you sure you want to delete "${recipe.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteRecipe(recipe);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// DEDICATED RECIPE CARD HELPER MODEL
class _SpiceEntry {
  SlotModel? selectedSlot;
  final TextEditingController gramsController;

  _SpiceEntry({
    this.selectedSlot,
    required String grams,
  }) : gramsController = TextEditingController(text: grams);
}

/// FIGMA COMPLIANT RECIPE CREATE & EDIT SCREEN
/// Full-screen layout that perfectly implements /ref/create_edit_recipe.png
class RecipeFormScreen extends StatefulWidget {
  final RecipeModel? recipe;

  const RecipeFormScreen({super.key, this.recipe});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _nameController = TextEditingController();
  final List<_SpiceEntry> _spiceEntries = [];
  List<SlotModel> _availableSlots = [];
  late RecipeStorageService _recipeStorageService;
  bool _isEdit = false;
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.recipe != null;
    _initStorage();
    _loadSlots();
    _prepopulateForm();
  }

  void _initStorage() {
    final bluetoothCubit = context.read<BluetoothCubit>();
    final macAddress = bluetoothCubit.bleService.connectedDevice?.remoteId.str ?? 
                       StorageService.getLastMachine()?.deviceId;
    _recipeStorageService = RecipeStorageService(macAddress);
  }

  void _loadSlots() {
    _availableSlots = StorageService.getSlots();
  }

  void _prepopulateForm() {
    if (_isEdit && widget.recipe != null) {
      _nameController.text = widget.recipe!.name;
      
      // Load selected ingredients to entries
      for (var ing in widget.recipe!.ingredients) {
        // Try to find the matching SlotModel by spice name
        SlotModel? matchingSlot;
        try {
          matchingSlot = _availableSlots.firstWhere(
            (s) => s.spiceName.trim().toLowerCase() == ing.name.trim().toLowerCase(),
          );
        } catch (_) {
          matchingSlot = null;
        }

        // If not found in physical slots, make a dummy virtual SlotModel representing offline spice
        matchingSlot ??= SlotModel(
          slotNumber: 0,
          spiceName: ing.name,
          expiryEpoch: null,
          level: 100,
        );

        _spiceEntries.add(
          _SpiceEntry(
            selectedSlot: matchingSlot,
            grams: ing.grams.toString(),
          ),
        );
      }
    } else {
      // Create mode starts with 1 empty spice entry
      _spiceEntries.add(_SpiceEntry(grams: '5'));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    for (var entry in _spiceEntries) {
      entry.gramsController.dispose();
    }
    super.dispose();
  }

  double _calculateTotalWeight() {
    double total = 0.0;
    for (var entry in _spiceEntries) {
      final grams = double.tryParse(entry.gramsController.text) ?? 0.0;
      total += grams;
    }
    return total;
  }

  int _calculateDistinctSpicesCount() {
    return _spiceEntries
        .where((e) => e.selectedSlot != null && e.selectedSlot!.spiceName.isNotEmpty)
        .map((e) => e.selectedSlot!.spiceName.trim().toLowerCase())
        .toSet()
        .length;
  }

  void _showSummaryAndConfirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Duplicate Name Validation for the same machine
    final existingRecipes = _recipeStorageService.getRecipes();
    final nameLower = name.toLowerCase();
    
    final hasDuplicate = existingRecipes.any((r) {
      final isSameRecipe = _isEdit && r.id == widget.recipe?.id;
      return !isSameRecipe && r.name.toLowerCase() == nameLower;
    });

    if (hasDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A recipe named "$name" already exists for this machine. Please use a unique name.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_spiceEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one spice'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Validation checks
    for (int i = 0; i < _spiceEntries.length; i++) {
      final entry = _spiceEntries[i];
      if (entry.selectedSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a spice slot for spice ${i + 1}'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final gramsStr = entry.gramsController.text.trim();
      final grams = double.tryParse(gramsStr);
      if (grams == null || grams <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid weight in grams for spice ${i + 1}'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    // Duplicate detection
    final selectedSlots = _spiceEntries.map((e) => e.selectedSlot!.slotNumber).toList();
    if (selectedSlots.toSet().length < selectedSlots.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot select the same slot multiple times in a recipe'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // All valid! Now show the summary modal/dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final totalWeight = _calculateTotalWeight();
        final duration = totalWeight.ceil() < 5 ? 5 : totalWeight.ceil();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E52E8), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEdit ? 'Update Summary' : 'Recipe Summary',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Recipe Name
                const Text(
                  'Recipe Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Ingredients List
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _spiceEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _spiceEntries[index];
                      final slot = entry.selectedSlot;
                      final grams = double.tryParse(entry.gramsController.text) ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. Slot ${slot?.slotNumber ?? "N/A"}: ${slot?.spiceName ?? "Unknown"}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${grams.toStringAsFixed(1)} g',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                
                // Summary Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Weight',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${totalWeight.toStringAsFixed(1)} g',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E52E8),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Est. Duration',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '$duration seconds',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Back to Edit',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close summary dialog
                          _saveAndSyncRecipe(); // Call the actual save logic
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E52E8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEdit ? 'Sync Changes' : 'Confirm & Sync',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// TRANSACTIONAL SYNC & SAVE WITH AUTOMATIC DB ROLLBACK ON FAILURE
  Future<void> _saveAndSyncRecipe() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Duplicate Name Validation for the same machine
    final existingRecipes = _recipeStorageService.getRecipes();
    final nameLower = name.toLowerCase();
    
    final hasDuplicate = existingRecipes.any((r) {
      final isSameRecipe = _isEdit && r.id == widget.recipe?.id;
      return !isSameRecipe && r.name.toLowerCase() == nameLower;
    });

    if (hasDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A recipe named "$name" already exists for this machine. Please use a unique name.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_spiceEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one spice'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Validation checks
    for (int i = 0; i < _spiceEntries.length; i++) {
      final entry = _spiceEntries[i];
      if (entry.selectedSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a spice slot for row ${i + 1}'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final gramsStr = entry.gramsController.text.trim();
      final grams = double.tryParse(gramsStr);
      if (grams == null || grams <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid weight in grams for row ${i + 1}'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    // Duplicate detection
    final selectedSlots = _spiceEntries.map((e) => e.selectedSlot!.slotNumber).toList();
    if (selectedSlots.toSet().length < selectedSlots.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot select the same slot multiple times in a recipe'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Map entries to RecipeIngredient models
    final List<RecipeIngredient> recipeIngredients = _spiceEntries.map((e) {
      return RecipeIngredient(
        name: e.selectedSlot!.spiceName,
        grams: double.parse(e.gramsController.text),
      );
    }).toList();

    // Auto-calculate duration linearly based on grams (e.g. 1g = 1s, minimum 5 seconds)
    final totalGrams = _calculateTotalWeight();
    final duration = totalGrams.ceil() < 5 ? 5 : totalGrams.ceil();

    final savedRecipe = RecipeModel(
      id: widget.recipe?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      ingredients: recipeIngredients,
      duration: duration,
    );

    // Save previous recipes for rollback
    final previousRecipes = _recipeStorageService.getRecipes();

    // Show Progress dialogue
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Syncing recipes with machine...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifying ingredients on-device...',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Perform database operation locally (Optimistic)
      if (_isEdit) {
        await _recipeStorageService.updateRecipe(savedRecipe);
      } else {
        await _recipeStorageService.addRecipe(savedRecipe);
      }

      // 2. Fetch updated list
      final updatedRecipes = _recipeStorageService.getRecipes();

      // 3. Sync to machine
      final bluetoothCubit = context.read<BluetoothCubit>();
      final syncService = RecipeSyncService();
      final result = await syncService.syncAllRecipes(
        bleService: bluetoothCubit.bleService,
        recipes: updatedRecipes,
      );

      // Dismiss progress loader
      if (mounted) {
        Navigator.pop(context);
      }

      if (result.isSuccess) {
        // Success! Pop back to Recipes list and show notification
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_isEdit 
                        ? 'Updated "${savedRecipe.name}" and synced with dispenser!' 
                        : 'Created "${savedRecipe.name}" and synced with dispenser!'),
                  ),
                ],
              ),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } else {
        // Validation Error! ROLLBACK local database changes instantly
        debugPrint('Machine rejected recipe. Rolling back database changes...');
        for (var recipe in updatedRecipes) {
          await _recipeStorageService.deleteRecipe(recipe.id);
        }
        for (var recipe in previousRecipes) {
          await _recipeStorageService.addRecipe(recipe);
        }

        // Show detailed failure alert
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Machine Refused Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.errorReason ?? 'The dispenser rejected this configuration.',
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  if (result.missingIngredient != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Missing Spice: "${result.missingIngredient}" must be physically setup on the machine first.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xDD000000)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back and Fix', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss progress loader
      if (mounted) {
        Navigator.pop(context);
      }

      // Revert local changes on unexpected exception
      for (var recipe in previousRecipes) {
        await _recipeStorageService.addRecipe(recipe);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error during sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown choices: active physical slot names configured on device
    final activeSlots = _availableSlots
        .where((s) => s.spiceName.trim().isNotEmpty)
        .toList();

    // Fallback choices if empty to maintain onboarding usability
    final List<SlotModel> dropdownSlots = activeSlots.isNotEmpty
        ? activeSlots
        : List.generate(
            9,
            (idx) {
              final presetsList = ['Oregano', 'Basil', 'Rosemary', 'Thyme', 'Chili Powder', 'Cumin', 'Paprika', 'Garlic Powder', 'Turmeric'];
              return SlotModel(
                slotNumber: idx + 1,
                spiceName: presetsList[idx],
                expiryEpoch: null,
                level: 100,
              );
            },
          );

    final totalWeight = _calculateTotalWeight();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // PREMIUM LIGHT GRAY-BLUE FROM FIGMA
      body: Column(
        children: [
          // CUSTOM BLUE APP HEADER TO MATCH FIGMA IMAGE PERFECTLY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, right: 20, top: 48, bottom: 20),
            color: const Color(0xFF1E52E8), // Primary Blue from figma
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit Recipe' : 'Create Recipe',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_spiceEntries.isEmpty ? 0 : _currentPageIndex + 1} of ${_spiceEntries.length} Spices (${_calculateDistinctSpicesCount()} unique)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // FIGMA COMPLIANT SAVE BUTTON (WHITE BACKGROUND, DISK ICON, BLUE TEXT)
                ElevatedButton.icon(
                  onPressed: _showSummaryAndConfirm,
                  icon: const Icon(Icons.save, color: Color(0xFF1E52E8), size: 18),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF1E52E8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          
          // SCROLLABLE FORM BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CARD 1: RECIPE NAME SECTION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipe Name',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'e.g., Spaghetti Mix',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // ROW 2: SPICES HEADER WITH + ADD SPICE BUTTON
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Spices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _spiceEntries.add(_SpiceEntry(grams: '5'));
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_pageController.hasClients) {
                              _pageController.animateToPage(
                                _spiceEntries.length - 1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: const Text(
                          'Add Spice',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E52E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),

                  // SPICE HORIZONTAL NAVIGATION CHIPS
                  if (_spiceEntries.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_spiceEntries.length, (idx) {
                          final isSelected = _currentPageIndex == idx;
                          final entry = _spiceEntries[idx];
                          final slotName = entry.selectedSlot?.spiceName.isNotEmpty == true 
                              ? entry.selectedSlot!.spiceName 
                              : 'New Spice';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                            child: ChoiceChip(
                              label: Text(
                                '${idx + 1}: $slotName',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF1E52E8),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF1E52E8) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) {
                                _pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // PAGEVIEW CONTAINER FOR SPICE ENTRIES
                  if (_spiceEntries.isEmpty)
                    Container(
                      width: double.infinity,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Text(
                        'No spices added yet. Tap "Add Spice" above.',
                        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 255,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _spiceEntries.length,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPageIndex = idx;
                          });
                        },
                        itemBuilder: (context, idx) {
                          final entry = _spiceEntries[idx];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E52E8).withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CARD HEADER: TITLE & DELETE
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Spice ${idx + 1} of ${_spiceEntries.length}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Color(0xFF1E52E8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
                                      onPressed: () {
                                        setState(() {
                                          _spiceEntries.removeAt(idx);
                                          // Keep current page index bounded
                                          if (_currentPageIndex >= _spiceEntries.length && _spiceEntries.isNotEmpty) {
                                            _currentPageIndex = _spiceEntries.length - 1;
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 12, color: Color(0xFFE2E8F0)),
                                
                                // SPICE SLOT SELECTION DROPDOWN
                                const Text(
                                  'Spice Slot',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<SlotModel>(
                                  value: entry.selectedSlot,
                                  isExpanded: true,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black, fontSize: 14),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                    ),
                                  ),
                                  items: dropdownSlots.map((slot) {
                                    final displayText = slot.slotNumber == 0 
                                        ? slot.spiceName // Offline fallback
                                        : 'Slot ${slot.slotNumber}: ${slot.spiceName}';
                                    return DropdownMenuItem<SlotModel>(
                                      value: slot,
                                      child: Text(
                                        displayText,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      entry.selectedSlot = val;
                                    });
                                  },
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // QUANTITY (GRAMS) WITH TACTILE INCREMENT/DECREMENT
                                const Text(
                                  'Quantity (grams)',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B), size: 24),
                                      onPressed: () {
                                        final val = double.tryParse(entry.gramsController.text) ?? 5.0;
                                        if (val > 0.5) {
                                          setState(() {
                                            entry.gramsController.text = (val - 0.5).toStringAsFixed(1);
                                          });
                                        }
                                      },
                                    ),
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: TextField(
                                          controller: entry.gramsController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                            ),
                                          ),
                                          onChanged: (_) {
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1E52E8), size: 24),
                                      onPressed: () {
                                        final val = double.tryParse(entry.gramsController.text) ?? 5.0;
                                        setState(() {
                                          entry.gramsController.text = (val + 0.5).toStringAsFixed(1);
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'g',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF64748B), size: 20),
                          onPressed: _currentPageIndex > 0 ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } : null,
                        ),
                        Text(
                          'Swipe or tap chips to navigate',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
                          onPressed: _currentPageIndex < _spiceEntries.length - 1 ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } : null,
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // BOTTOM CARD: DYNAMIC TOTAL WEIGHT DISPLAY
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // Light blue background from figma
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Weight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A), // Dark blue from figma
                          ),
                        ),
                        Text(
                          '${totalWeight.toStringAsFixed(1)} g',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E52E8), // Primary Blue from figma
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
