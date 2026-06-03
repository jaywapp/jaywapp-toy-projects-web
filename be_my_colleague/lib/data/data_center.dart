import 'dart:ffi';

import 'package:be_my_colleague/model/due.dart';
import 'package:be_my_colleague/model/enums.dart';
import 'package:be_my_colleague/model/member.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:be_my_colleague/model/schedule.dart';
import 'package:be_my_colleague/submodules/jaywapp-dart-google-sheet/google-sheet-manager.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DataCenter {
  GoogleSignInAccount? googleAccount;

  Account account = new Account('', '');
  List<Club> clubs = [];

  String name = '';
  String mailAddress = '';

  DataCenter(GoogleSignInAccount? googleUser) {
    googleAccount = googleUser;

    name = googleUser?.displayName ?? '';
    mailAddress = googleUser?.email ?? '';

    account = new Account(name, mailAddress);

    clubs = [
      new Club('1Op1lymJ1oDr8IazasJpq3UDUtUTfysVzGsa-sJlQIPI', '경충FC',
          '풋살을 즐겁게 하자', new DateTime(2011, 08, 16), 1, '신한', '110-152-149740')
    ];
  }

  String GetMail(){
    return googleAccount?.email ?? '';
  }

  Future<List<Member>> GetMembers(String clubID) async {
    if (googleAccount == null) return List.empty();

    var manager = new GoogleSheetManager(googleAccount, clubID);

    List<Member> result = [];

    try {
      var values = await manager.GetActiveValues('회원');
      var length = values?.length ?? 0;

      if (length >= 2) {
        for (int i = 1; i < length; i++) {
          var row = values?.elementAtOrNull(i) ?? List.empty();
          result.add(Member.FromRow(row));
        }
      }
    } catch (e) {}

    return result;
  }

  Future<int> GetMemberCount(String clubID) async {
    if (googleAccount == null) return 0;

    var manager = new GoogleSheetManager(googleAccount, clubID);
    var values = await manager.GetActiveValues('회원');

    return values?.length ?? 0;
  }

  Future<int> GetPostsCount(String clubID) async {
    if (googleAccount == null) return 0;

    var manager = new GoogleSheetManager(googleAccount, clubID);
    var values = await manager.GetActiveValues('공지사항');

    return values?.length ?? 0;
  }

  Future<List<Schedule>> GetSchedules(String clubID) async {
    if (googleAccount == null) return List.empty();

    var manager = new GoogleSheetManager(googleAccount, clubID);

    List<Schedule> result = [];

    try {
      var values = await manager.GetActiveValues('일정');
      var length = values?.length ?? 0;

      if (length >= 2) {
        for (int i = 1; i < length; i++) {
          var row = values?.elementAtOrNull(i) ?? List.empty();
          result.add(Schedule.FromRow(row));
        }
      }
    } catch (e) {}

    return result;
  }

  Future<List<Due>> GetDues(String clubID, String mailAddress) async {
    var manager = new GoogleSheetManager(googleAccount, clubID);
    List<Due> result = [];

    try {
      var values = await manager.GetActiveValues('회비');

      if (values != null) {
        List<Object?> headers = values.elementAtOrNull(0) ?? List.empty();
        var length = headers?.length ?? 0;

        for (var row in values) {
          var name = (row.elementAtOrNull(0) as String) ?? '';

          if (name == account.name) {
            for (int j = 1; j < length; j++) {
              var due = new Due(DateTime.parse((headers[j] as String) ?? ''),
                  (row[j] as String) == '납부');

              result.add(due);
            }
          }
        }
      }
    } catch (e) {}

    return result;
  }

  Future<void> AddSchdule(String clubID, Schedule schedule) async {
    var manager = new GoogleSheetManager(googleAccount, clubID);
    var rows = schedule.ToRow();

     try {
      await manager.Appand('일정', rows);
     }
     catch (e) {}
  }

  Future<void> Absent(
      String clubID, Schedule? schedule, String mailAddress) async {
    var manager = new GoogleSheetManager(googleAccount, clubID);
    var sheetName = '일정';

    try {
      var idx = await manager.GetIndex(sheetName, 1, schedule?.id);
      if (idx == -1) return;
      var row = schedule?.ToRowWhenRemove(mailAddress) ?? List.empty();
      await manager.Update(sheetName, idx, row);
    } catch (e) {}
  }

  Future<void> Attend(
      String clubID, Schedule? schedule, String mailAddress) async {
    var manager = new GoogleSheetManager(googleAccount, clubID);
    var sheetName = '일정';

    try {
      var idx = await manager.GetIndex(sheetName, 1, schedule?.id);
      if (idx == -1) return;
      var row = schedule?.ToRowWhenAdd(mailAddress) ?? List.empty();
      await manager.Update(sheetName, idx, row);
    } catch (e) {}
  }

  List<Club> GetClubs() {
    return clubs;
  }

  Club GetClub(String clubID) {
    return clubs.firstWhere((c) => c.id == clubID);
  }

  Future<Schedule> GetSchedule(String clubID, String scheduleID) async {
    var schedules = await GetSchedules(clubID);
    var schedule = schedules.firstWhere((o) => o.id == scheduleID);

    return schedule;
  }

  Future<DateTime> GetJoinTime(String clubId) async {
    var time = await GetMembers(clubId);
    return time.firstWhere((m) => m.mailAddress == account.mailAddress).created;
  }

  Future<bool> IsAdmin(String clubID) async {

    var members = await GetMembers(clubID);
    var target = members.firstWhere((m) => m.mailAddress == mailAddress);

    var result = target.permission == Permission.president
              || target.permission == Permission.vicePresident
              || target.permission == Permission.secretary;

    return result;
  }
}
