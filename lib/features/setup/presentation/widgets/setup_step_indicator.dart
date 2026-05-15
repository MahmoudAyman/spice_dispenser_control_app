import 'package:flutter/material.dart';

class SetupStepIndicator
    extends StatelessWidget {

  final int currentStep;

  const SetupStepIndicator({
    super.key,
    required this.currentStep,
  });

  Widget buildStep({
    required int step,
    required String title,
  }) {

    final bool completed =
        currentStep > step;

    final bool active =
        currentStep == step;

    return Column(
      children: [

        Container(
          width: 38,
          height: 38,

          decoration: BoxDecoration(
            color:
            completed || active
                ? const Color(
              0xFF2563EB,
            )
                : Colors.white,

            border: Border.all(
              color:
              const Color(
                0xFF2563EB,
              ),
            ),

            shape: BoxShape.circle,
          ),

          child: Center(
            child:
            completed
                ? const Icon(
              Icons.check,
              color:
              Colors.white,
              size: 18,
            )
                : Text(
              '$step',

              style: TextStyle(
                color:
                active
                    ? Colors.white
                    : const Color(
                  0xFF2563EB,
                ),

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          title,

          style: TextStyle(
            fontSize: 12,

            fontWeight:
            active
                ? FontWeight.bold
                : FontWeight.w500,

            color:
            active
                ? const Color(
              0xFF2563EB,
            )
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,

      children: [

        buildStep(
          step: 1,
          title: 'Welcome',
        ),

        Container(
          width: 50,
          height: 2,
          color:
          currentStep >= 2
              ? const Color(
            0xFF2563EB,
          )
              : Colors.grey.shade300,
        ),

        buildStep(
          step: 2,
          title: 'Slots',
        ),

        Container(
          width: 50,
          height: 2,
          color:
          currentStep >= 3
              ? const Color(
            0xFF2563EB,
          )
              : Colors.grey.shade300,
        ),

        buildStep(
          step: 3,
          title: 'Complete',
        ),
      ],
    );
  }
}