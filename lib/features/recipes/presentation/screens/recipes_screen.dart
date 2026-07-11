import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../dashboard/presentation/controllers/machine_controller.dart';

import '../../../dispensing/presentation/screens/dispensing_screen.dart';

import '../controllers/recipe_controller.dart';

import '../widgets/recipe_card.dart';

import 'add_recipe_screen.dart';

class RecipesScreen
    extends StatelessWidget {

  const RecipesScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final recipesController =
    context.watch<
        RecipesController>();

    final machineController =
    context.read<
        MachineController>();

    final recipes =
        recipesController.recipes;

    return Scaffold(

      backgroundColor:
      const Color(0xFFF5F7FB),

      appBar: AppBar(

        backgroundColor:
        const Color(0xFF2563EB),

        elevation: 0,

        title: const Text(

          'Recipes',

          style: TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body: recipes.isEmpty

          ? Center(

        child: Column(

          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [

            Icon(
              Icons.menu_book,
              size: 90,
              color: Colors.grey
                  .shade400,
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              'No Recipes Yet',

              style: TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
                color: Colors
                    .grey.shade700,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              'Create your first spice recipe',

              style: TextStyle(
                fontSize: 16,
                color: Colors
                    .grey.shade600,
              ),
            ),
          ],
        ),
      )

          : ListView.builder(

        padding:
        const EdgeInsets.all(
          20,
        ),

        itemCount:
        recipes.length,

        itemBuilder:
            (context, index) {

          final recipe =
          recipes[index];

          return Padding(

            padding:
            const EdgeInsets.only(
              bottom: 18,
            ),

            child: RecipeCard(

              recipe: recipe,

              onDispense:
                  () async {

                await recipesController
                    .dispenseRecipe(

                  recipe: recipe,

                  machineController:
                  machineController,
                );

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (_) =>

                    const DispensingScreen(),
                  ),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton:
      FloatingActionButton(

        backgroundColor:
        const Color(0xFF2563EB),

        onPressed: () {

          Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) =>

              const AddRecipeScreen(),
            ),
          );
        },

        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}