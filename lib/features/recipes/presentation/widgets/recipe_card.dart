import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dashboard/presentation/controllers/machine_controller.dart';

import '../../data/models/recipe_model.dart';

import '../../../dispensing/presentation/screens/dispensing_screen.dart';

import '../controllers/recipe_controller.dart';

class RecipeCard
    extends StatelessWidget {

  final RecipeModel recipe;

  final VoidCallback?
  onDispense;

  const RecipeCard({

    super.key,

    required this.recipe,

    this.onDispense,
  });

  @override
  Widget build(BuildContext context) {

    final recipesController =
    context.read<
        RecipesController>();

    final machineController =
    context.read<
        MachineController>();

    return Container(

      padding:
      const EdgeInsets.all(
        20,
      ),

      decoration:
      BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          26,
        ),

        boxShadow: [

          BoxShadow(
            color: Colors.black
                .withOpacity(
              0.04,
            ),

            blurRadius: 14,
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment
            .start,

        children: [

          Row(

            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,

            children: [

              Expanded(

                child: Text(

                  recipe.name,

                  style:
                  const TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              IconButton(

                onPressed: () async {

                  await recipesController
                      .deleteRecipe(
                    recipe.id,
                  );
                },

                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Wrap(

            spacing: 10,
            runSpacing: 10,

            children:

            recipe.ingredients.map(

                  (ingredient) {

                return Container(

                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),

                  decoration:
                  BoxDecoration(

                    color:
                    const Color(
                      0xFFE8F0FF,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                  ),

                  child: Text(

                    '${ingredient.spiceName} • ${ingredient.grams}g',

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(
            height: 22,
          ),

          SizedBox(

            width: double.infinity,
            height: 54,

            child:
            ElevatedButton.icon(

              style:
              ElevatedButton.styleFrom(

                backgroundColor:
                const Color(
                  0xFF2563EB,
                ),

                shape:
                RoundedRectangleBorder(

                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                ),
              ),

              onPressed:
              onDispense ??
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

              icon: const Icon(
                Icons.play_arrow,
                color: Colors.white,
              ),

              label: const Text(

                'Dispense',

                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}