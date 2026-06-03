import 'dart:async';
import 'dart:convert';

import 'package:be_my_colleague/Service/MapService.dart';
import 'package:be_my_colleague/Styles.dart';
import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/indicator.dart';
import 'package:be_my_colleague/model/member.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:be_my_colleague/model/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:googleapis/iam/v1.dart';

class ScheduleDetail extends StatefulWidget {
  final DataCenter dataCenter;
  final String clubID;
  final String scheduleID;

  const ScheduleDetail(
      {super.key,
      required this.dataCenter,
      required this.clubID,
      required this.scheduleID});

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  bool isLoading = false; // 로딩 상태를 나타내는 변수

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: GetData(),
        builder: (context, snapshot) {
          return CreateWidget(snapshot?.data?.$1, snapshot?.data?.$2);
        });
  }

  Future<(Schedule, List<Member>)> GetData() async {
    List results = await Future.wait([
      widget.dataCenter.GetSchedule(widget.clubID, widget.scheduleID),
      widget.dataCenter.GetMembers(widget.clubID),
    ]);

    return (results[0] as Schedule, results[1] as List<Member>);
  }

  Widget CreateWidget(Schedule? schedule, List<Member>? members) {

    var include = schedule?.participantMails?.contains(widget.dataCenter.mailAddress) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(schedule?.name ?? '')),
      body: CreatePadding(schedule, members),
      floatingActionButton: isLoading // 로딩 중일 경우
          ? SizedBox(
              width: 150, // 버튼의 너비를 설정
              child: FloatingActionButton.extended(
                icon: SizedBox(
                    width: 24, // 인디케이터 너비
                    height: 24, // 인디케이터 높이
                    child: CircularProgressIndicator(
                      color: Colors.white, // 인디케이터 색상
                      strokeWidth: 2.0, // 인디케이터 두께
                    )),
                label: Text('반영중...'), // 로딩 중 메시지
                backgroundColor: Colors.grey, // 배경색
                onPressed: null, // 비활성화
              ),
            )
          : FloatingActionButton.extended(
              icon:
                  include ? const Icon(Icons.cancel) : const Icon(Icons.check),
              label: Text(include ? '이번 일정은 불참합니다.' : '이번 일정은 참석합니다.'),
              backgroundColor: include ? Colors.red : Colors.blue,
              foregroundColor: include ? Colors.black : Colors.white,
              onPressed: () async {
                setState(() {
                  isLoading = true; // 로딩 시작
                });

                if (include) {
                  await widget.dataCenter.Absent(
                    widget.clubID,
                    schedule,
                    widget.dataCenter.account.mailAddress,
                  );
                } else {
                  await widget.dataCenter.Attend(
                    widget.clubID,
                    schedule,
                    widget.dataCenter.account.mailAddress,
                  );
                }

                setState(() {
                  isLoading = false; // 로딩 종료
                });
              },
            ),
    );
  }

  Widget CreatePadding(Schedule? schedule, List<Member>? members) {
    var targets = (members ?? List.empty())
        .where((member) =>
            schedule?.participantMails?.contains(member.mailAddress) ?? false)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
      child: Column(
        children: [
          Styles.CreateHeader(Icons.access_time, '날짜/시간'),
          Styles.CreateContent(convert(schedule?.dateTime ?? new DateTime(1000))),
          Styles.CreateHeader(Icons.map_outlined, '장소'),
          Styles.CreateContent(schedule?.location ?? ''),
          CreateMap(schedule?.location ?? ''),
          Styles.CreateHeader(Icons.supervised_user_circle, '참여인원 (${schedule?.participantMails?.length ?? 0} / ${members?.length ?? 0})'),
          CreateParticipants(context, widget.dataCenter.account, targets),
        ],
      ),
    );
  }

  Widget CreateMap(String location) {
    return Container(
      height: 200,
      child: FutureBuilder(
          future: GetLatLng(location),
          builder: (context, snapshot) {
            return CreateSizeBoxMap(
                snapshot.data?.$1 ?? 0, snapshot.data?.$2 ?? 0, location);
          }),
    );
  }

  Widget CreateSizeBoxMap(double lat, double lng, String location) {
    final Completer<NaverMapController> mapControllerCompleter = Completer();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isValid = lat != 0 && lng != 0;

    return SizedBox(
        width: screenWidth,
        height: 200,
        child: isValid
            ? CreateNaverMap(mapControllerCompleter, lat, lng, location)
            : Flexible(flex: 1, child: Text('표시할 정보가 없습니다.')));
  }

  Future<(double, double)> GetLatLng(String location) async {
    var result = await MapService.getLatLngFromAddress(location);

    var latStr = result?.values?.elementAt(0) ?? '0';
    var lngStr = result?.values?.elementAt(1) ?? '0';

    double lat = double.parse(latStr);
    double lng = double.parse(lngStr);

    return (lat, lng);
  }

  Widget CreateNaverMap(Completer<NaverMapController> completer, double lat,
      double lng, String text) {
    return NaverMap(
      options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(lat, lng),
            zoom: 15,
            bearing: 0,
            tilt: 0,
          ),
          indoorEnable: true, // 실내 맵 사용 가능 여부 설정
          locationButtonEnable: false, // 위치 버튼 표시 여부 설정
          consumeSymbolTapEvents: false, // 심볼 탭 이벤트 소비 여부 설정
          liteModeEnable: true),
      onMapReady: (controller) async {
        // 지도 준비 완료 시 호출되는 콜백 함수
        completer.complete(controller); // Completer에 지도 컨트롤러 완료 신호 전송

        var marker = NMarker(id: '1', position: NLatLng(lat, lng));

        controller.addOverlay(marker);
        final onMarkerInfoWindow =
            NInfoWindow.onMarker(id: marker.info.id, text: text);
        marker.openInfoWindow(onMarkerInfoWindow);
      },
    );
  }

  Widget CreateParticipants(
      BuildContext context, Account account, List<Member> members) {
    List<Member> targets = [];

    for (var member in members) {
      targets.add(member);
    }

    targets.sort((a, b) => a.name.compareTo(b.name));

    return Expanded(
      child: ListView.builder(
          itemCount: targets.length,
          itemBuilder: (BuildContext ctx, int index) {
            var member = targets[index];
            var color = member.mailAddress == account.mailAddress
                ? Theme.of(context).colorScheme.primary
                : Colors.black;

            var style = TextStyle(
              fontSize: 20,
              color: color,
            );

            return Card(
                child: Padding(
                    padding: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                    child: Text(
                      member.name,
                      style: style,
                    )));
          }),
    );
  }

  String convert(DateTime now) {
    return "${now.year.toString()}년 ${now.month.toString().padLeft(2, '0')}월 ${now.day.toString().padLeft(2, '0')}일 ${now.hour.toString().padLeft(2, '0')}시${now.minute.toString().padLeft(2, '0')}분";
  }
}
