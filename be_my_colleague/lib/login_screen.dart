import 'package:be_my_colleague/common.dart';
import 'package:be_my_colleague/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen();

  @override
  State<StatefulWidget> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: Column(
          children: [
            Flexible(
                flex: 9,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        Common.title,
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Align(
                        child: Text(
                          Common.copyright,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color.fromRGBO(255, 255, 255, 0.6),
                            )),
                      )
                    ],
                  ),
                )),
            Flexible(
              flex: 1,
              child: ElevatedButton(
                onPressed: () =>  Login(),
                child: Text('Login with Google'),
              ),
            ),
          ],
        ));
  }

  void Login() async {
    GoogleSignInAccount? googleUser = await GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/spreadsheets',
      ],
    )
    .signIn();

    var name = googleUser?.displayName ?? '';
    var mailAddress = googleUser?.email ?? '';

    Route(googleUser);
  }

  void Route(GoogleSignInAccount? account) {
    Navigator.pop(context);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: MyHomePage(account: account))));
  }
}
