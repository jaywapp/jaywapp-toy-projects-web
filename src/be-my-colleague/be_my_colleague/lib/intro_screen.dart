import 'package:flutter/material.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    var screenHeight = MediaQuery.of(context).size.height;
    var screenWidth = MediaQuery.of(context).size.width;

    return new Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "너 내 동료가 돼라",
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
             Align(
                  child: Text("© Copyright 2024, BlueHeart",
                      style: TextStyle(
                        fontSize: 15, color: Color.fromRGBO(255, 255, 255, 0.6),)
                  ),
                )
          ],
        ),
      ),
    );
  }
}
