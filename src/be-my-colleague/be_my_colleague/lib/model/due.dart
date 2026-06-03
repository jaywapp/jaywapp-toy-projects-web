import 'package:flutter/material.dart';

class Due {
  DateTime date = new DateTime(1000, 1, 1);
  bool payed = false;

  Due(this.date, this.payed);

  // Due.FromRow(List<Object?> row){
  //    var dateStr = (headers[j] as String) ?? '';
  //             var value = (row[j] as String) ?? '';
  //             var date = DateTime.parse(dateStr ?? '');
  // }
}