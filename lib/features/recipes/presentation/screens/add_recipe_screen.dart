import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/storage_service.dart';

import '../../data/models/recipe_ingredient_model.dart';

import '../controllers/recipe_controller.dart';

class AddRecipeScreen
    extends StatefulWidget {

  const AddRecipeScreen({
    super.key,
  });

  @override
  State<AddRecipeScreen>
  createState() =>
      _AddRecipeScreenState();
}

class _AddRecipeScreenState
    extends State<
        AddRecipeScreen> {

  final TextEditingController
  nameController =
  TextEditingController();

  final List<
      RecipeIngredientModel>
  ingredients = [];

  final TextEditingController
  gramsController =
  TextEditingController();

  /// Selected spice from slots

  int? selectedSlot;

  String selectedSpiceName =
      '';

  @override
  Widget build(BuildContext context) {

    final controller =
    context.read<
        RecipesController>();

    final slots =
    StorageService.getSlots();

    return Scaffold(

      backgroundColor:
      const Color(
        0xFFF5F7FB,
      ),

      appBar: AppBar(

        backgroundColor:
        const Color(
          0xFF2563EB,
        ),

        title: const Text(

          'Create Recipe',

          style: TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(

        padding:
        const EdgeInsets.all(
          20,
        ),

        child: Column(

          children: [

            /// RECIPE NAME

            TextField(

              controller:
              nameController,

              decoration:
              InputDecoration(

                hintText:
                'Recipe Name',

                filled: true,

                fillColor:
                Colors.white,

                border:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),

                  borderSide:
                  BorderSide.none,
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            /// INGREDIENT CARD

            Container(

              padding:
              const EdgeInsets.all(
                18,
              ),

              decoration:
              BoxDecoration(

                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),

              child: Column(

                children: [

                  /// SPICE DROPDOWN

                  DropdownButtonFormField<
                      int>(

                    value:
                    selectedSlot,

                    decoration:
                    const InputDecoration(
                      labelText:
                      'Select Spice',
                    ),

                    items:
                    slots.map((slot) {

                      return DropdownMenuItem<
                          int>(

                        value:
                        slot.slotNumber,

                        child: Text(
                          'Slot ${slot.slotNumber} - ${slot.spiceName}',
                        ),
                      );

                    }).toList(),

                    onChanged:
                        (value) {

                      if (value ==
                          null) {
                        return;
                      }

                      final slot =
                      slots.firstWhere(

                            (element) =>
                        element
                            .slotNumber ==
                            value,
                      );

                      setState(() {

                        selectedSlot =
                            value;

                        selectedSpiceName =
                            slot.spiceName;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  /// GRAMS

                  TextField(

                    controller:
                    gramsController,

                    keyboardType:
                    TextInputType
                        .number,

                    decoration:
                    const InputDecoration(
                      hintText:
                      'Grams',
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  /// ADD INGREDIENT

                  SizedBox(

                    width:
                    double.infinity,

                    height: 52,

                    child:
                    ElevatedButton(

                      onPressed: () {

                        if (

                        selectedSlot ==
                            null ||

                            gramsController
                                .text
                                .isEmpty

                        ) {

                          return;
                        }

                        ingredients.add(

                          RecipeIngredientModel(

                            slot:
                            selectedSlot!,

                            grams:
                            double.parse(

                              gramsController
                                  .text,
                            ),

                            spiceName:
                            selectedSpiceName,
                          ),
                        );

                        gramsController
                            .clear();

                        setState(() {

                          selectedSlot =
                          null;

                          selectedSpiceName =
                          '';
                        });
                      },

                      child: const Text(
                        'Add Ingredient',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            /// INGREDIENTS LIST

            ...ingredients.map(

                  (ingredient) {

                return Container(

                  margin:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),

                  padding:
                  const EdgeInsets.all(
                    16,
                  ),

                  decoration:
                  BoxDecoration(

                    color:
                    Colors.white,

                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                  ),

                  child: Row(

                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                    children: [

                      Text(
                        ingredient
                            .spiceName,
                      ),

                      Text(

                        'Slot ${ingredient.slot} • ${ingredient.grams}g',
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(
              height: 40,
            ),

            /// SAVE RECIPE

            SizedBox(

              width:
              double.infinity,

              height: 58,

              child:
              ElevatedButton(

                style:
                ElevatedButton
                    .styleFrom(

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

                onPressed: () async {

                  if (

                  nameController
                      .text
                      .trim()
                      .isEmpty ||

                      ingredients
                          .isEmpty

                  ) {

                    return;
                  }

                  await controller
                      .addRecipe(

                    name:
                    nameController
                        .text
                        .trim(),

                    ingredients:
                    ingredients,
                  );

                  Navigator.pop(
                    context,
                  );
                },

                child: const Text(

                  'Save Recipe',

                  style: TextStyle(
                    color:
                    Colors.white,

                    fontWeight:
                    FontWeight.bold,

                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}