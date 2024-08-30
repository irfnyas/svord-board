import 'dart:async';
import 'dart:convert';

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
  double ballSize = 0; // Ball size relative to screen width
  int score = 0;
  late Timer timer;
  Color backgroundColor = Colors.yellow.shade50;
  bool canBounce = true; // Flag to control if the ball can bounce
  bool hasBounced = false; // Flag to indicate if the ball has just bounced

  @override
  void initState() {
    super.initState();
    _listenToWebSocket(); // Listen for WebSocket messages
    timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateBallPosition();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    widget.webSocket.close();
    super.dispose();
  }

  void _listenToWebSocket() {
    widget.webSocket.messages.listen((message) {
      // Log the received message
      print('Received message in single player: $message');

      // Handle WebSocket messages with 'send-message' action
      if (message.contains('send-message')) {
        try {
          final Map<String, dynamic> decodedMessage = jsonDecode(message);
          if (decodedMessage['action'] == 'send-message' &&
              decodedMessage['sender'] != null &&
              decodedMessage['sender']['name'] == widget.playerName &&
              decodedMessage['message'] == 'swing') {
            // Simulate tap on screen if the message is from the player and action is "swing"
            _onTap();
          }
        } catch (e) {
          print(
              'Error decoding message: $e'); // Error handling if JSON parsing fails
        }
      }
    });
  }

  void _updateBallPosition() {
    setState(() {
      ballX += ballSpeedX;
      ballY += ballSpeedY;

      // Ball collision with the screen borders
      if (ballX <= 0 || ballX >= screenWidth - ballSize) {
        ballSpeedX = -ballSpeedX;
      }
      if (ballY <= 0) {
        ballSpeedY = -ballSpeedY;
      }

      // Check if the ball is within the 66% threshold area
      if (ballY >= screenHeight * 0.66 && !hasBounced) {
        backgroundColor =
            Colors.red.shade50; // Change color when it's time to tap
        canBounce = true; // Allow bounce when in the tap area
      } else if (ballY < screenHeight * 0.66) {
        // Reset color and bounce flag if the ball is above the threshold
        backgroundColor = Colors.yellow.shade50;
        hasBounced = false; // Reset bounce flag
      }

      // Ball reaches the bottom of the screen
      if (ballY >= screenHeight - ballSize) {
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
          content: Text('Your score: $score'),
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
      canBounce = true; // Reset bounce control
      hasBounced = false; // Reset bounce flag
      timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        _updateBallPosition();
      });
    });
  }

  void _onTap() {
    // Allow the bounce only if the ball is at or below 66% of the screen height and canBounce is true
    if (ballY >= screenHeight * 0.66 && canBounce) {
      setState(() {
        // Reverse the ball's Y direction to simulate a bounce
        ballSpeedY = -ballSpeedY;
        score++;

        // Increase the speed of the ball by 1.2 after each bounce
        ballSpeedY *= 1.2; // Increase vertical speed by 20%
        ballSpeedX *= 1.2; // Increase horizontal speed by 20%

        backgroundColor =
            Colors.yellow.shade50; // Immediately reset background color
        canBounce =
            false; // Disable further bounces until the ball goes above 66%
        hasBounced = true; // Set flag to indicate the ball has bounced
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
          ballSize =
              screenWidth * 0.025; // Set ball size to 2.5% of screen width

          return GestureDetector(
            onTap: _onTap,
            child: Container(
              color: backgroundColor, // Set background color
              child: Stack(
                children: [
                  // Horizontal line marking the 66% threshold
                  Positioned(
                    top: screenHeight * 0.66,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: Colors.grey
                          .withOpacity(0.5), // Soft grey line with transparency
                    ),
                  ),
                  // Icon below the threshold line indicating to tap
                  Positioned(
                    top: screenHeight * 0.66 +
                        5, // Slightly below the threshold line
                    left: screenWidth / 2 - 12, // Center the icon
                    child: Icon(
                      Icons.touch_app, // Hand tap icon
                      color: Colors.grey.withOpacity(0.5), // Soft grey color
                      size: 24,
                    ),
                  ),
                  // Ball
                  Positioned(
                    top: ballY,
                    left: ballX,
                    child: Container(
                      width: ballSize,
                      height: ballSize,
                      decoration: const BoxDecoration(
                        color: Colors.blue, // Change ball color to blue
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Score
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
