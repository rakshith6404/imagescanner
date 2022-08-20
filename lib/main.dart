import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imageScanner/Main_page/First_page.dart';
import 'package:imageScanner/Main_page/introduction_screen.dart';
import 'package:imageScanner/Main_page/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

int? initScreen;

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences preferences=await SharedPreferences.getInstance();
  initScreen = await preferences.getInt('initScreen');
  await preferences.setInt('initScreen', 1);
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.pink[50],
      ),

      initialRoute: initScreen == 0  || initScreen==null ? 'onBoard' : 'home',
      routes: {
        'home' : (context) => LoginScreen(),
        'onBoard':(context) => IntroScreen(),
      },
    );
  }
}