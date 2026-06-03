import 'package:be_my_colleague/model/schedule.dart';
import 'package:flutter/material.dart';

class ScheduleBlock extends StatelessWidget {
  final Schedule? schedule;
  final VoidCallback onTap;

  ScheduleBlock({required this.schedule, required this.onTap});

  String convert(DateTime now) {
    return "${now.year.toString()}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    double nameFontSize = 20;
    double locationFontSize = 15;
    double dateTimeFontSize = 15;
    double participantFontSize = 20;

    FontWeight nameFontWeight = FontWeight.bold;
    FontWeight locationFontWeight = FontWeight.bold;
    FontWeight dateTimeFontWeight = FontWeight.bold;
    FontWeight participantFontWeight = FontWeight.bold;

    Color nameColor = Colors.black;
    Color locationColor = const Color.fromARGB(143, 51, 51, 51);
    Color dateTimeColor = const Color.fromARGB(255, 19, 1, 121);
    Color participantColor = Colors.black;

    return Card(
        elevation: 2,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
                child: Row(
                  children: [
                    Flexible(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(convert(schedule?.dateTime ?? new DateTime(1000)),
                                style: TextStyle(
                                  fontSize: dateTimeFontSize,
                                  fontWeight: dateTimeFontWeight,
                                  color: dateTimeColor,
                                )),
                          ]),
                          Row(children: [
                            Text(
                              schedule?.name ?? '',
                              style: TextStyle(
                                fontSize: nameFontSize,
                                fontWeight: nameFontWeight,
                                color: nameColor,
                              ),
                            ),
                          ]),
                          Row(
                            children: [
                              Text(
                                  schedule?.location ?? '',
                                  style: TextStyle(
                                    fontSize: locationFontSize,
                                    fontWeight: locationFontWeight,
                                    color: locationColor,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((schedule?.participantMails?.length?.toString() ?? '0') + '명',
                            style: TextStyle(
                              fontSize: participantFontSize,
                              fontWeight: participantFontWeight,
                              color: participantColor,
                            ))
                      ],
                    )),
                  ],
                )
              )
            )
      );
  }
}
