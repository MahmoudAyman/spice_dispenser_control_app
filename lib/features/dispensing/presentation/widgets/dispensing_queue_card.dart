import 'package:flutter/material.dart';

class DispensingQueueCard
    extends StatelessWidget {

  final String spiceName;

  final double grams;

  final bool active;

  final bool completed;

  const DispensingQueueCard({
    super.key,
    required this.spiceName,
    required this.grams,
    this.active = false,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {

    return AnimatedContainer(

      duration:
      const Duration(
        milliseconds: 300,
      ),

      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),

      decoration:
      BoxDecoration(

        color:
        active
            ? Colors.blue
            .withOpacity(0.08)
            : completed
            ? Colors.green
            .withOpacity(0.08)
            : Colors.white,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border: Border.all(

          color:
          active
              ? Colors.blue
              : completed
              ? Colors.green
              : Colors.grey
              .withOpacity(0.1),
        ),
      ),

      child: Row(

        children: [

          if (completed)

            const Icon(
              Icons.check,
              color: Colors.green,
            )

          else if (active)

            const Icon(
              Icons.play_arrow,
              color: Colors.blue,
            )

          else

            Icon(
              Icons.circle,
              size: 12,
              color:
              Colors.grey.shade400,
            ),

          const SizedBox(
            width: 14,
          ),

          Expanded(

            child: Text(

              spiceName,

              style: TextStyle(

                fontSize: 17,

                fontWeight:
                active
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),

          Text(

            '${grams}g',

            style:
            const TextStyle(

              fontWeight:
              FontWeight.bold,

              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}