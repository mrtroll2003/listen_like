// main.dart
import 'package:flutter/material.dart';
// No GetX import
import 'package:listen_like/src/screens/home.dart'; // Adjust path
import 'package:listen_like/route_generator.dart'; // Import your RouteGenerator - Adjust path

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use standard MaterialApp
    return MaterialApp(
      title: 'Media Processor App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Set the initial route name
      initialRoute: '/Home',
      // Provide the route generator function
      onGenerateRoute: RouteGenerator.generateRoute,
      // You might want a home property as a fallback or if initialRoute isn't used
      // home: const HomeScreen(),
    );
  }
}