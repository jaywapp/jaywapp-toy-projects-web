import 'package:be_my_colleague/Service/MapService.dart';
import 'package:be_my_colleague/common.dart';
import 'package:be_my_colleague/intro_screen.dart';
import 'package:be_my_colleague/login_screen.dart';
import 'package:be_my_colleague/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: MapService.clientKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
 

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    String name = '박준영';
    String mailAddress = 'jaywapp16@gmail.com';
    bool isContinue = false;

    return MaterialApp(
        title: Common.title,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Color.fromARGB(255, 7, 110, 245),
          ),
          useMaterial3: true,
        ),
        home: 
         AnimatedSwitcher(
          duration: const Duration(milliseconds: 1000),
          child: LoginScreen()
        ));
        
        // FutureBuilder(
        //   future: Future.delayed(
        //       const Duration(seconds: 5), () => "Intro Completed."),
        //   builder: (context, snapshot) {
        //     return AnimatedSwitcher(
        //         duration: const Duration(milliseconds: 1000),
        //         child: _splashLoadingWidget(snapshot));
        //   },
        // ));
  }

  // Widget _splashLoadingWidget(AsyncSnapshot<Object?> snapshot, String name, String mailAddress) {
  //   if (snapshot.hasError) {
  //     return const Text("Error!!");
  //   } else if (snapshot.hasData) {
  //     return MyHomePage(name: name, mailAddress: mailAddress);
  //   } else {
  //     return const IntroScreen();
  //   }
  // }
}
