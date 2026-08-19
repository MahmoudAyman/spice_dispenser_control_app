import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../container_management/data/models/spice_definition_model.dart';
import '../../../container_management/presentation/cubit/spice_cubit.dart';
import '../../../container_management/presentation/cubit/spice_state.dart';
import '../../../container_management/presentation/screens/add_spice_screen.dart';

class SpiceSelectionDialog extends StatefulWidget {
  const SpiceSelectionDialog({super.key});

  @override
  State<SpiceSelectionDialog> createState() => _SpiceSelectionDialogState();
}

class _SpiceSelectionDialogState extends State<SpiceSelectionDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SpiceCubit>().fetchSpices();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic vertical constraint to handle screen heights and soft keyboards safely
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicHeight = screenHeight - keyboardHeight - 340;
    final safeListHeight = dynamicHeight.clamp(110.0, 300.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF8FAFC),
      title: const Row(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 26),
          SizedBox(width: 12),
          Text(
            'Select a Spice',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.black),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      content: BlocBuilder<SpiceCubit, SpiceState>(
        builder: (context, state) {
          if (state is SpiceLoading) {
            return const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          }
          if (state is SpiceError || (state is SpiceLoaded && state.spices.isEmpty)) {
            String errorMessage = 'No default spices found on the machine.';
            if (state is SpiceError) {
              errorMessage = 'Failed to load spices: ${state.message}.';
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
                  const SizedBox(height: 10),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You can add a new spice manually below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                  ),
                ],
              ),
            );
          }
          if (state is SpiceLoaded) {
            final allSpices = state.spices;
            final filteredSpices = allSpices
                .where((s) =>
                    s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Spices...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: safeListHeight,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: filteredSpices.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching spices found.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredSpices.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]!),
                            itemBuilder: (context, index) {
                              final spice = filteredSpices[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary.withOpacity(0.08),
                                  child: const Icon(Icons.dining_outlined, size: 14, color: AppColors.primary),
                                ),
                                title: Text(
                                  spice.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                onTap: () {
                                  Navigator.of(context).pop(spice);
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text('No spices loaded.', style: TextStyle(color: Colors.grey)),
            ),
          );
        },
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Add New Spice',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AddSpiceScreen(),
            ));
          },
        ),
      ],
    );
  }
}
