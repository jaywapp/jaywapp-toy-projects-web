import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:flutter/material.dart';

class MoreScreen extends StatefulWidget {
  final DataCenter dataCenter;
  final String clubID;

  const MoreScreen(this.dataCenter, this.clubID);

  @override
  State<StatefulWidget> createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Text('more');
  }
}
