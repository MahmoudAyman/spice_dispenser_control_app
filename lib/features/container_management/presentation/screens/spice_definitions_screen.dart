import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/spice_cubit.dart';
import '../cubit/spice_state.dart';
import 'add_spice_screen.dart';

class SpiceDefinitionsScreen extends StatefulWidget {
  const SpiceDefinitionsScreen({super.key});

  @override
  State<SpiceDefinitionsScreen> createState() => _SpiceDefinitionsScreenState();
}

class _SpiceDefinitionsScreenState extends State<SpiceDefinitionsScreen> {
  @override
  void initState() {
    super.initState();
    final spiceCubit = context.read<SpiceCubit>();
    if (spiceCubit.state is! SpiceLoaded && spiceCubit.state is! SpiceLoading) {
      spiceCubit.fetchSpices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spice Definitions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddSpiceScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SpiceCubit, SpiceState>(
        builder: (context, state) {
          if (state is SpiceLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SpiceError) {
            return Center(child: Text(state.message));
          }
          if (state is SpiceLoaded) {
            final spices = state.spices;
            return ListView.builder(
              itemCount: spices.length,
              itemBuilder: (context, index) {
                final spice = spices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(spice.name),
                    subtitle: Text('Density: ${spice.density} g/ml'),
                  ),
                );
              },
            );
          }
          return const Center(child: Text('No spice definitions found.'));
        },
      ),
    );
  }
}
