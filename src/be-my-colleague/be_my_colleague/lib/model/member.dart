import 'package:be_my_colleague/model/enums.dart';
import 'package:flutter/material.dart';

class Member {
  String name = '';
  String mailAddress = '';
  String phoneNumber = '';
  DateTime birth = new DateTime(1000, 1, 1);
  DateTime created = new DateTime(1000, 1, 1);
  Permission permission = Permission.normal;

  Member(this.name, this.mailAddress, this.phoneNumber, this.birth, this.created, this.permission);

  Member.FromRow(List<Object?> row) {
    this.name = (row.elementAtOrNull(0) as String) ?? '';
    this.mailAddress = (row.elementAtOrNull(1) as String) ?? '';
    this.phoneNumber = (row.elementAtOrNull(2) as String) ?? '';
    var birthStr = (row.elementAtOrNull(3) as String) ?? '';
    var joinStr = (row.elementAtOrNull(4) as String) ?? '';
    var perStr = (row.elementAtOrNull(5) as String) ?? '';

    this.birth = DateTime.parse(birthStr ?? '');
    this.created = DateTime.parse(joinStr ?? '');
    this.permission = PermissionExt.Parse(perStr);
  }
}
