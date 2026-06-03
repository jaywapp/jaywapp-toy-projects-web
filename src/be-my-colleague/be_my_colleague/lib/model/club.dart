import 'package:be_my_colleague/model/Member.dart';
import 'package:be_my_colleague/model/schedule.dart';

class Club {
  String id = '';
  String name = '';
  String description = '';  
  DateTime created = new DateTime(1000, 1, 1, 0, 0, 0, 0, 0);
  int dueDay = 1;
  String bankAccount = '';
  String bankName = '';

  Club(this.id, this.name, this.description, this.created, this.dueDay, this.bankName, this.bankAccount);
}
