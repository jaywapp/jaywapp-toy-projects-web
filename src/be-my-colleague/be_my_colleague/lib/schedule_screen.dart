import 'dart:ffi';

import 'package:be_my_colleague/Styles.dart';
import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/indicator.dart';
import 'package:be_my_colleague/model/schedule.dart';
import 'package:be_my_colleague/schdule_add.dart';
import 'package:be_my_colleague/schedule_block.dart';
import 'package:be_my_colleague/schedule_detail.dart';
import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  final DataCenter dataCenter;
  final String clubID;

  const ScheduleScreen(this.dataCenter, this.clubID);

  @override
  State<StatefulWidget> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  String convert(DateTime now) {
    return "${now.year.toString()}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Styles.CreateHeader(Icons.calendar_month, '일정정보'),
        ),
        body: FutureBuilder(
            future: widget.dataCenter.GetSchedules(widget.clubID),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Indicator.ShowIndicator("일정을 불러오는 중입니다..");
              } else {
                return ListView.builder(
                  itemCount: snapshot?.data?.length ?? 0,
                  itemBuilder: (BuildContext ctx, int index) {
                    var schedule = snapshot?.data?.elementAtOrNull(index);
                    return CreateBlock(schedule);
                  },
                );
              }
            }),
        floatingActionButton: FutureBuilder(
            future: widget.dataCenter.IsAdmin(widget.clubID),
            builder: (context, snapshot) {
              if (snapshot?.data ?? false) {
                return FloatingActionButton(
                  onPressed: () async {
                    var result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => new ScheduleAddBlock(
                            clubID: widget.clubID,
                            dataCenter: widget.dataCenter),
                      ),
                    );

                    setState(() {});
                  },
                  child: Icon(Icons.add),
                );
              } else {
                return SizedBox.shrink();
              }
            }));
  }

  Widget CreateBlock(Schedule? schedule) {
    return ScheduleBlock(
        onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleDetail(
                    dataCenter: widget.dataCenter,
                    clubID: widget.clubID,
                    scheduleID: schedule?.id ?? '',
                  ),
                ),
              ),
            },
        schedule: schedule);
  }
}
