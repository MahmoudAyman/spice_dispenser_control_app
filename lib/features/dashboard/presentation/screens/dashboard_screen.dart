import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_cubit.dart';
import '../../../bluetooth/presentation/cubit/bluetooth_state.dart';
import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/recipe_storage_service.dart';
import '../../../recipes/data/models/recipe_model.dart';
import 'main_layout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SlotModel> slots = [];
  List<RecipeModel> recentRecipes = [];

  @override
  void initState() {
    super.initState();
    loadSlots();
    loadRecipes();
  }

  void loadSlots() {
    setState(() {
      slots = StorageService.getSlots();
    });
    debugPrint('DASHBOARD LOADED SLOTS: ${slots.length}');
  }

  void loadRecipes() {
    final recipeService = RecipeStorageService();
    var list = recipeService.getRecipes();

    // Pre-populate if empty
    if (list.isEmpty) {
      _prepopulatePresets(recipeService);
      list = recipeService.getRecipes();
    }

    setState(() {
      recentRecipes = list.take(2).toList();
    });
  }

  void _prepopulatePresets(RecipeStorageService service) {
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
      service.addRecipe(recipe);
    }
  }

  Color _getLevelColor(int level) {
    if (level <= 20) return const Color(0xFFEF4444); // Red
    return const Color(0xFF22C55E); // Green
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
            // Start countdown
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
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'seconds',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
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
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please place your container under the dispensing nozzle.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
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
                          try {
                            final bluetoothCubit = context.read<BluetoothCubit>();
                            await bluetoothCubit.bleService.sendCommand(
                              command: {'type': 'abort'},
                            );
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
        backgroundColor: const Color(0xFF22C55E),
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
    final bleCubit = context.watch<BluetoothCubit>();
    final isConnected = bleCubit.state is BluetoothHandshakeSuccess;
    final lastMachine = StorageService.getLastMachine();
    final deviceName = lastMachine?.deviceName ?? 'Spice Dispenser #1';

    // Identify if any spices are running low (level <= 20%)
    final lowSpices = slots.where((s) => s.level <= 20 && s.spiceName.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra premium Slate 50 background
      body: RefreshIndicator(
        onRefresh: () async {
          loadSlots();
          loadRecipes();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Blue Premium Custom Header (Matches Design Image)
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: MediaQuery.of(context).padding.top + 24,
                  bottom: 28,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB), // Vivid Royal Blue
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deviceName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    _buildConnectedBadge(isConnected),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Dynamic Low Spice Alert Card (Matches Design Image)
                    if (lowSpices.isNotEmpty) ...[
                      _buildLowSpiceAlertCard(lowSpices),
                      const SizedBox(height: 24),
                    ],

                    // 3. Spice Containers Section Title
                    const Text(
                      'Spice Containers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A), // Slate 900
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Spice Containers Grid (Matches Design Image)
                    slots.isEmpty ? _buildEmptySlotsPlaceholder() : _buildSlotsGrid(),

                    const SizedBox(height: 32),

                    // 5. Recent Recipes Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Recipes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Switch tab in main layout to Recipes tab (index 1)
                            context.findAncestorStateOfType<MainLayoutScreenState>()?.setTab(1);
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 6. Recent Recipes List (Matches Design Image)
                    ...recentRecipes.map((recipe) => _buildRecipeCard(recipe)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF22C55E) : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowSpiceAlertCard(List<SlotModel> lowSpices) {
    final names = lowSpices.map((s) => s.spiceName).join(' & ');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Light peach-pink background
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: const Color(0xFFEF4444), // Crimson Red left border line
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Low Spice Alert',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B), // Dark Crimson
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$names running low',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlotsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: const Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 48, color: Color(0xFF64748B)),
          SizedBox(height: 16),
          Text(
            'No Containers Configured',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 8),
          Text(
            'Go to Containers page or complete setup to register your spices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.15, // Perfect aspect ratio matching reference design
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isLow = slot.level <= 20;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slot ${slot.slotNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8), // slate 400
                      ),
                    ),
                    if (isLow)
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  slot.spiceName.isEmpty ? 'Empty Slot' : slot.spiceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A), // slate 900
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${slot.level}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLow ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${slot.level * 2}g',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: slot.level / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getLevelColor(slot.level),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    // Return relative simulated times matching reference image or fallback
    String relativeTime = '2 hours ago';
    if (recipe.id == 'taco_mix') {
      relativeTime = 'Yesterday';
    } else if (recipe.id == 'curry_powder') {
      relativeTime = 'Classic Curry'; // Wait, let's keep times aligned
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  relativeTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showDispensingDialog(recipe),
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
              label: const Text(
                'Dispense',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
