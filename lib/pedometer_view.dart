import 'package:flutter/material.dart';

class PedometerView extends StatelessWidget {
  PedometerView({@required this.stepValList, this.pedometerError});

  final List<String> stepValList;
  final List<String> pedometerError;

  @override
  Widget build(BuildContext context) {

     // Latest comes on top.
    List<String> reversedList = stepValList.reversed.toList();
    List<String> reversedErrorList = pedometerError.reversed.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(10, 20, 10, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          
          // Steps counted 
          Divider(thickness: 3, height: 6,),
          Text('Steps: '),
          SizedBox(height: 10,),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: reversedList.length ?? 0,
            itemBuilder: (context, index) {
              String stepData = reversedList[index];

              return Card(

                color: Colors.grey.shade300,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(

                    title: Text(stepData),
                    
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 30,),

          // Errors
          Divider(thickness: 3, height: 6,),
          Text('Errors: '),
          SizedBox(height: 10,),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: reversedErrorList.length ?? 0,
            itemBuilder: (context, index) {
              String errData = reversedErrorList[index];

              return Card(
                color: Colors.grey.shade300,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(

                    title: Text(errData),
                    
                  ),
                ),
              );
            },
          ),

        ],
      ),
    );
  }
}
