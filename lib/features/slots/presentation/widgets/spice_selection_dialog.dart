import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return AlertDialog(
      title: const Text('Select a Spice'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: BlocBuilder<SpiceCubit, SpiceState>(
        builder: (context, state) {
          if (state is SpiceLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SpiceError || (state is SpiceLoaded && state.spices.isEmpty)) {
            String errorMessage = 'No default spices found on the machine.';
            if (state is SpiceError) {
              errorMessage = 'Failed to load spices: ${state.message}.';
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorMessage),
                const SizedBox(height: 16),
                const Text('You can add a new spice manually.'),
              ],
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
                    labelText: 'Search Spices',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: filteredSpices.length,
                    itemBuilder: (context, index) {
                      final spice = filteredSpices[index];
                      return ListTile(
                        title: Text(spice.name),
                        onTap: () {
                          Navigator.of(context).pop(spice);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return const Center(child: Text('No spices loaded.'));
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Add New Spice'),
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
