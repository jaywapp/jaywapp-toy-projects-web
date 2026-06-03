import 'package:be_my_colleague/Styles.dart';
import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/dues_bank_block.dart';
import 'package:be_my_colleague/dues_block.dart';
import 'package:be_my_colleague/indicator.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:be_my_colleague/model/due.dart';
import 'package:flutter/material.dart';

class DuesScreen extends StatefulWidget {
  final DataCenter dataCenter;
  final String clubID;

  const DuesScreen(this.dataCenter, this.clubID);

  @override
  State<StatefulWidget> createState() => DuesScreenState();
}

class DuesScreenState extends State<DuesScreen> {
  Club _club = new Club(
      '',
      '',
      '',
      new DateTime(
        1000,
        1,
        1,
      ),
      1,
      '',
      '');

  @override
  void initState() {
    super.initState();
    _club = widget.dataCenter.GetClub(widget.clubID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Styles.CreateHeader(Icons.monetization_on_sharp, '회비납부내역'),
        ),
        body: Column(
          children: [
            DuesBankBlock(
              name: _club.bankName,
              account: _club.bankAccount,
            ),
            Expanded(
                child: FutureBuilder(
                    future: widget.dataCenter.GetDues(
                        widget.clubID, widget.dataCenter.account.mailAddress),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Indicator.ShowIndicator("회비 납부 내역을 불러오는 중입니다..");
                      } else {
                        var dues = snapshot?.data ?? List.empty();
                        dues.sort((a, b) => a.date.compareTo(b.date));
                        dues = List.from(dues.reversed);

                        return CreateListView(dues);
                      }
                    })),
          ],
        ));
  }

  Widget CreateListView(List<Due>? dues) {
    return ListView.builder(
      itemCount: dues?.length ?? 0,
      itemBuilder: (BuildContext ctx, int index) {
        return Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: DueBlock(due: dues?.elementAtOrNull(index)));
      },
    );
  }
}
