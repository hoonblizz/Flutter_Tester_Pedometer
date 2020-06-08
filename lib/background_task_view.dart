import 'package:flutter/material.dart';

class BackgroundTaskView extends StatelessWidget {
  BackgroundTaskView({@required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 15, 10, 20),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: events.length ?? 0,
        itemBuilder: (context, index) {
          String item = events[index];

          return Card(
            color: Colors.grey.shade300,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(item),
              ),
            ),
          );
        },
      ),
    );
  }
}
