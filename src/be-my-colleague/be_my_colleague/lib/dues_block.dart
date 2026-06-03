import 'package:be_my_colleague/model/due.dart';
import 'package:flutter/material.dart';

class DueBlock extends StatelessWidget {
  final Due? due;

  DueBlock({required this.due});

  @override
  Widget build(BuildContext context) {
    int year = due?.date?.year ?? 1000;
    int month = due?.date?.month ?? 1;
    return Card(
        child: Padding(padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        child:  Row(
              children: [
                Text('$year년 $month월'),
                Text('   '),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          (due?.payed ?? false) ? Icons.check : Icons.cancel,
                          color: (due?.payed ?? false) ? Colors.green : Colors.red,)
                        ],
                )),
        ],
    )));
  }
}
