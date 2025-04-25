import 'package:listen_like/src/models/route_argument.dart';
// import 'package:ez_docs/src/screens/Chatbot/chatbot.dart';
// import 'package:ez_docs/src/screens/Translation/translate.dart';
// import 'package:ez_docs/src/screens/Translation/translateResult.dart';
import 'package:flutter/material.dart';
import 'package:listen_like/src/screens/home.dart';
// import 'package:ez_docs/src/screens/Summary/sum.dart';
import 'package:listen_like/src/screens/result.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // ignore: unused_local_variable
    final args = settings.arguments;
    switch (settings.name) {
      case '/Home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/Result':
        return MaterialPageRoute(builder: (_) => ResultScreen(routeArgument: args as RouteArgument));
      
      default:
      // If there is no such named route in the switch statement, e.g. /third
        return MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: Text('Route Error'))));
    }
  }
}