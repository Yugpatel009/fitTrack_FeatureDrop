import 'package:flutter/material.dart';
import 'package:untitled/signup%20page.dart';
import 'loginpage.dart';

void main() {
  runApp(Fittrack());
}

class Fittrack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyFirstProject(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyFirstProject extends StatelessWidget {
  final String title;

  const MyFirstProject({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        body: const Login(title: 'Flutter Demo Home Page'), // ✅ Use capitalized class name
    );
  }
}
