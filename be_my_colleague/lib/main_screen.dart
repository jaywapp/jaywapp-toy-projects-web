import 'dart:convert';
import 'dart:ffi';
import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/dues_screen.dart';
import 'package:be_my_colleague/home_screen.dart';
import 'package:be_my_colleague/members_screen.dart';
import 'package:be_my_colleague/model/Member.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:be_my_colleague/model/enums.dart';
import 'package:be_my_colleague/model/schedule.dart';
import 'package:be_my_colleague/more_screen.dart';
import 'package:be_my_colleague/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_sign_in/google_sign_in.dart'; // 로컬 assets를 읽기 위해 필요

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.account});

  final GoogleSignInAccount? account;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const _navItems = [
  BottomNavigationBarItem(
    icon: Icon(Icons.home_filled),
    label: '홈',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.supervised_user_circle_sharp),
    label: '회원정보',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.calendar_month),
    label: '일정',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.attach_money),
    label: '회비',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.more_horiz),
    label: '더보기',
  ),
];

class _MyHomePageState extends State<MyHomePage> {
  int _bottomItemIndex = 0;

  List<Club> _clubs = [];
  Club _selectedClub = new Club('', '', '', new DateTime(2011, 08, 16), 1, '', '');

  DataCenter _dataCenter = new DataCenter(null);

  void changeClub(Club club) {
    setState(() {
      _selectedClub = club;
    });
    Navigator.pop(context); // Drawer 닫기
  }

  @override
  void initState() {
    super.initState();

    _dataCenter = new DataCenter(widget.account);
    _clubs = _dataCenter.GetClubs();
    _selectedClub = _clubs.first;
  }

  Widget getScreen(int idx) {
    if (idx == 0) {
      return HomeScreen(_dataCenter, _selectedClub.id);
    } else if (idx == 1) {
      return MembersScreen(_dataCenter, _selectedClub.id);
    } else if (idx == 2) {
      return ScheduleScreen(_dataCenter, _selectedClub.id);
    } else if (idx == 3) {
      return DuesScreen(_dataCenter, _selectedClub.id);
    } else if (idx == 4) {
      return MoreScreen(_dataCenter, _selectedClub.id);
    } else {
      throw Exception('Unknown screen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_selectedClub.name),
        actions: [
          IconButton(icon: Icon(Icons.account_box_rounded), onPressed: null),
        ],
      ),
      body: getScreen(_bottomItemIndex),
      drawer: Drawer(
        child: ListView.builder(
            itemCount: _clubs.length + 1,
            itemBuilder: (BuildContext ctx, int index) {
              if (index == 0) {
                return CreateDrawerHeader(_dataCenter.account);
              } else {
                return ListTile(
                  leading: Icon(
                    Icons.home,
                    color: Colors.grey[850],
                  ),
                  title: Text(_clubs[index - 1].name),
                  onTap: () {
                    changeClub(_clubs[index - 1]);
                  },
                );
              }
            }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _bottomItemIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.black,
        onTap: (int index) {
          setState(() {
            _bottomItemIndex = index;
          });
        },
      ),
    );
  }

  UserAccountsDrawerHeader CreateDrawerHeader(Account account) {
    return UserAccountsDrawerHeader(
      accountName: Text(
        account.name,
        style: TextStyle(
          letterSpacing: 1.0,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      accountEmail: Text(
        account.mailAddress,
        style: TextStyle(
          letterSpacing: 0.7,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40.0),
          bottomRight: Radius.circular(40.0),
        ),
      ),
    );
  }
}
