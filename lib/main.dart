import 'package:flutter/material.dart';

import 'screens/intro_screen.dart';

void main() {
  runApp(const PingPongGame());
}

class PingPongGame extends StatelessWidget {
  const PingPongGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ping Pong Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const IntroScreen(),
    );
  }
}
