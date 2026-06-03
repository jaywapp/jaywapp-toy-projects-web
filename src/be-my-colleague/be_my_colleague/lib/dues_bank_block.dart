import 'package:be_my_colleague/Styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DuesBankBlock extends StatelessWidget {
  final String name;
  final String account;

  DuesBankBlock({required this.name, required this.account});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.fromLTRB(15.0, 5.0, 12.0, 12.0),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(0, 5, 10, 0),
                child: Icon(Icons.comment_bank),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 3, 0, 0),
                child: Text(name, style: Styles.ContentStyle)
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(5, 3, 5, 0),
                child: Text(':', style: Styles.ContentStyle)
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                child: Text(account, style: Styles.ContentStyle)
              ),
              Expanded(
                child: 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '$name $account'))
                         .then(
                          (_) => 
                             Fluttertoast.showToast(
                            msg: '성공적으로 복사되었습니다.',
                            backgroundColor: Colors.white,
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM));
                         

                      },
                    )
                  ],
                )
                )
            ],
          ),
        ));
  }
}
