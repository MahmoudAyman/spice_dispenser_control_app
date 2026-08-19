import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/spice_cubit.dart';
import '../cubit/spice_state.dart';

class AddSpiceScreen extends StatefulWidget {
  const AddSpiceScreen({super.key});

  @override
  State<AddSpiceScreen> createState() => _AddSpiceScreenState();
}

class _AddSpiceScreenState extends State<AddSpiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _densityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _densityController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final density = double.tryParse(_densityController.text) ?? 0.0;
      context.read<SpiceCubit>().addNewSpice(name, density);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Spice'),
      ),
      body: BlocConsumer<SpiceCubit, SpiceState>(
        listener: (context, state) {
          if (state is SpiceLoaded) {
            Navigator.of(context).pop();
          } else if (state is SpiceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is SpiceLoading;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Spice Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _densityController,
                    decoration: const InputDecoration(labelText: 'Density (g/cm³)',),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a density';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
