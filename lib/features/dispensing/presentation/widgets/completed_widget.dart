import 'package:flutter/material.dart';

class CompletedWidget
    extends StatelessWidget {

  const CompletedWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding:
      const EdgeInsets.all(
        28,
      ),

      decoration:
      BoxDecoration(

        color:
        Colors.green
            .withOpacity(0.08),

        borderRadius:
        BorderRadius.circular(
          26,
        ),
      ),

      child: Column(

        children: [

          const Icon(

            Icons.check_circle,

            color:
            Colors.green,

            size: 90,
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(

            'Dispensing Completed Successfully',

            textAlign:
            TextAlign.center,

            style: TextStyle(

              fontSize: 24,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(

            'Your recipe has been dispensed successfully.',

            textAlign:
            TextAlign.center,

            style: TextStyle(

              color:
              Colors.grey.shade700,

              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}