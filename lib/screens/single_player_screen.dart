import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

class SinglePlayerScreen extends StatefulWidget {
  final WebSocket webSocket;
  final String playerName;

  const SinglePlayerScreen({
    super.key,
    required this.webSocket,
    required this.playerName,
  });

  @override
  _SinglePlayerScreenState createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen> {
  late double screenWidth;
  late double screenHeight;
  double ballX = 0;
  double ballY = 0;
  double ballSpeedX = 3;
  double ballSpeedY = 3;
  int score = 0;
  late Timer timer;
  Color backgroundColor = Colors.yellow.shade50;
  bool canBounce = false; // Updated flag usage for bounce control

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateBallPosition();
    });
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    widget.webSocket.messages.listen((message) {
      log('Received message in single player: $message');

      if (message.contains('send-message')) {
        final Map<String, dynamic> decodedMessage = jsonDecode(message);
        if (decodedMessage['action'] == 'send-message' &&
            decodedMessage['sender'] != null) {
          final String senderName = decodedMessage['sender']['name'];
          final String swingAction = decodedMessage['message'];

          if (senderName == widget.playerName && swingAction == 'swing') {
            _onTap(); // Attempt to bounce the ball
          }
        }
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    widget.webSocket.close();
    super.dispose();
  }

  void _updateBallPosition() {
    setState(() {
      ballX += ballSpeedX;
      ballY += ballSpeedY;

      if (ballX <= 0 || ballX >= screenWidth - 20) {
        ballSpeedX = -ballSpeedX;
      }
      if (ballY <= 0) {
        ballSpeedY = -ballSpeedY;
      }

      // Check if the ball is within the bounce threshold range
      if (ballY >= screenHeight * 0.67) {
        canBounce = true; // Allow bounce when in range
      } else {
        canBounce = false; // Disable bounce when out of range
      }

      // Game Over if the ball reaches the bottom
      if (ballY >= screenHeight - 20) {
        timer.cancel();
        _showGameOverDialog();
      }
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text('Final score: $score'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              child: const Text('Restart'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to the intro screen
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      ballX = 0;
      ballY = 0;
      ballSpeedX = 3;
      ballSpeedY = 3;
      score = 0;
      backgroundColor = Colors.yellow.shade50;
      canBounce = false;
      timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        _updateBallPosition();
      });
    });
  }

  void _onTap() {
    if (canBounce) {
      setState(() {
        ballSpeedY = -ballSpeedY;
        score++;

        ballSpeedY *= 1.2; // Increase vertical speed
        ballSpeedX *= 1.2; // Increase horizontal speed

        backgroundColor = Colors.yellow.shade50; // Reset background color
        canBounce = false; // Reset bounce after swing
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          screenWidth = constraints.maxWidth;
          screenHeight = constraints.maxHeight;

          return GestureDetector(
            onTap: _onTap,
            child: Container(
              color: backgroundColor,
              child: Stack(
                children: [
                  Positioned(
                    top: screenHeight * 0.67,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.67 + 5,
                    left: screenWidth / 2 - 12,
                    child: Icon(
                      Icons.touch_app,
                      color: Colors.grey.withOpacity(0.5),
                      size: 24,
                    ),
                  ),
                  Positioned(
                    top: ballY,
                    left: ballX,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Text(
                      'Score: $score',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
