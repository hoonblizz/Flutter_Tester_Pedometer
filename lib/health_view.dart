import 'package:flutter/material.dart';

class HealthView extends StatelessWidget {
  HealthView({@required this.healthDataStringList, this.lastUpdated});

  final List<String> healthDataStringList;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {

    // Latest comes on top.
    List<String> reversedList = healthDataStringList.reversed.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(10, 20, 10, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10, 15, 10, 20),
            child: Column(
              children: [
                Text('Last Updated:'),
                Text(
                  lastUpdated,
                ),
              ],
            ),
          ),
          // Steps counted
          Divider(
            thickness: 3,
            height: 6,
          ),
          Text('Steps: '),
          SizedBox(
            height: 10,
          ),
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
        ],
      ),
    );
  }
}
