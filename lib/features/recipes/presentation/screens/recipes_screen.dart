import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../data/models/recipe_model.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final RecipeStorageService _recipeStorageService = RecipeStorageService();
  List<RecipeModel> _recipes = [];
  List<SlotModel> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load available slots (spices) from storage
    _availableSlots = StorageService.getSlots();

    // Load recipes from storage
    List<RecipeModel> savedRecipes = _recipeStorageService.getRecipes();

    // If no recipes exist, let's pre-populate with some beautiful preset recipes
    if (savedRecipes.isEmpty) {
      _prepopulatePresets();
      savedRecipes = _recipeStorageService.getRecipes();
    }

    setState(() {
      _recipes = savedRecipes;
    });
  }

  void _prepopulatePresets() {
    final presets = [
      RecipeModel(
        id: 'italian_seasoning',
        name: 'Italian Herbs',
        ingredients: ['Oregano', 'Basil', 'Rosemary', 'Thyme'],
        duration: 5,
      ),
      RecipeModel(
        id: 'taco_mix',
        name: 'Taco Seasoning',
        ingredients: ['Chili Powder', 'Cumin', 'Paprika', 'Onion Powder'],
        duration: 8,
      ),
      RecipeModel(
        id: 'curry_powder',
        name: 'Curry Blend',
        ingredients: ['Turmeric', 'Coriander', 'Cumin', 'Ginger'],
        duration: 10,
      ),
    ];

    for (var recipe in presets) {
      // Only include ingredients if they are available in the setup or fallback to presets
      _recipeStorageService.addRecipe(recipe);
    }
  }

  Future<void> _deleteRecipe(String id) async {
    await _recipeStorageService.deleteRecipe(id);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted successfully')),
      );
    }
  }

  void _showDispensingDialog(RecipeModel recipe) {
    int duration = recipe.duration;
    double progress = 1.0;
    bool aborted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start a timer to update countdown
            Future.delayed(const Duration(seconds: 1), () {
              if (!dialogContext.mounted || aborted) return;
              if (duration > 0) {
                setDialogState(() {
                  duration--;
                  progress = duration / recipe.duration;
                });
              } else {
                Navigator.of(dialogContext).pop();
                _showSuccessSnackBar(recipe.name);
              }
            });

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
                    const SizedBox(height: 10),
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$duration',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            const Text(
                              'seconds',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Dispensing ${recipe.name}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please place your container under the dispensing nozzle.',
                      style: TextStyle(
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
                        onPressed: () async {
                          aborted = true;
                          Navigator.of(dialogContext).pop();
                          // Send Abort Command to Machine if connected
                          try {
                            final bluetoothCubit = context.read<BluetoothCubit>();
                            if (bluetoothCubit.state is BluetoothHandshakeSuccess || 
                                bluetoothCubit.bleService.writeCharacteristic != null) {
                              await bluetoothCubit.bleService.sendCommand(
                                command: {'type': 'abort'},
                              );
                            }
                          } catch (e) {
                            debugPrint('Failed to send abort command: $e');
                          }
                          _showAbortSnackBar(recipe.name);
                        },
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
                ),
              ),
            );
          },
        );
      },
    );

    // Send Dispense Command to ESP32 Machine if connected
    try {
      final bluetoothCubit = context.read<BluetoothCubit>();
      if (bluetoothCubit.state is BluetoothHandshakeSuccess || 
          bluetoothCubit.bleService.writeCharacteristic != null) {
        bluetoothCubit.bleService.sendCommand(
          command: {
            'type': 'dispense',
            'recipe_id': recipe.id,
            'duration': recipe.duration,
          },
        ).then((ack) {
          debugPrint('Dispense Ack Received: ${ack.isSuccess}');
        });
      }
    } catch (e) {
      debugPrint('Failed to send dispense command: $e');
    }
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

  void _showCreateRecipeDialog() {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '5');
    final selectedSpices = <String>{};

    // Filter available slots to those that actually have a spice name filled in
    final activeSpices = _availableSlots
        .where((s) => s.spiceName.trim().isNotEmpty)
        .map((s) => s.spiceName.trim())
        .toList();

    // If no spices have been set up yet, use a standard preset list
    final spicesToChoose = activeSpices.isNotEmpty 
        ? activeSpices 
        : ['Oregano', 'Basil', 'Rosemary', 'Thyme', 'Chili Powder', 'Cumin', 'Paprika', 'Garlic Powder', 'Turmeric'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Create Custom Recipe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Recipe Name',
                        hintText: 'e.g., Spaghetti Mix',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.restaurant_menu),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Dispense Duration (seconds)',
                        hintText: 'e.g., 5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.timer_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Ingredients:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.black),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spicesToChoose.map((spice) {
                        final isSelected = selectedSpices.contains(spice);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(spice),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedSpices.add(spice);
                              } else {
                                selectedSpices.remove(spice);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final duration = int.tryParse(durationController.text.trim()) ?? 5;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a recipe name')),
                      );
                      return;
                    }

                    if (selectedSpices.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one ingredient')),
                      );
                      return;
                    }

                    final newRecipe = RecipeModel(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      ingredients: selectedSpices.toList(),
                      duration: duration,
                    );

                    _recipeStorageService.addRecipe(newRecipe);
                    _loadData();
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created "$name" successfully!'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
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
            onPressed: _showCreateRecipeDialog,
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
                              ingredient,
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
                          const SizedBox(width: 12),
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
                                        _deleteRecipe(recipe.id);
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
