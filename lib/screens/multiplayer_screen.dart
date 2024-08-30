import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer; // Alias to avoid conflict with dart:math
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

class MultiplayerScreen extends StatefulWidget {
  final WebSocket webSocket;
  final String playerOneName;
  final String playerTwoName;

  const MultiplayerScreen({
    super.key,
    required this.webSocket,
    required this.playerOneName,
    required this.playerTwoName,
  });

  @override
  _MultiplayerScreenState createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  late double screenWidth;
  late double screenHeight;
  double ballX = 0;
  double ballY = 0;
  double ballSpeedX = 3;
  double ballSpeedY = 0;
  double ballSize = 0; // Ball size relative to screen width
  double circleSize = 0; // Circle size relative to screen width
  int playerOneScore = 0;
  int playerTwoScore = 0;
  late Timer timer;
  Color backgroundColor = Colors.yellow.shade50;
  bool canBounce = false;
  String lastBounce = '';
  String announcement = ''; // To display the announcement
  bool isInitialized =
      false; // Flag to ensure initialization happens after screen size is available
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _listenToWebSocket();
  }

  void _startBallMovement() {
    // Reset ball to center and set random initial direction
    ballX = screenWidth / 2 - ballSize / 2; // Center the ball horizontally
    ballY = screenHeight / 2 - ballSize / 2; // Center the ball vertically
    ballSpeedX = random.nextBool() ? 3 : -3; // Randomly choose left or right
    ballSpeedY = random.nextDouble() * 2 - 1; // Small vertical movement

    timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateBallPosition();
    });
  }

  void _listenToWebSocket() {
    widget.webSocket.messages.listen((message) {
      developer.log(
          'Received message in multiplayer: $message'); // Use the alias 'developer.log'

      if (message.contains('send-message')) {
        final Map<String, dynamic> decodedMessage = jsonDecode(message);
        if (decodedMessage['action'] == 'send-message' &&
            decodedMessage['sender'] != null) {
          final String senderName = decodedMessage['sender']['name'];
          final String swingAction = decodedMessage['message'];

          if (swingAction == 'swing') {
            if (senderName == widget.playerOneName &&
                ballX <=
                    screenWidth *
                        0.20 && // Player one's threshold (20% from the left)
                ballSpeedX < 0) {
              // Ball moving towards player one
              _onTap();
              lastBounce = 'left';
            } else if (senderName == widget.playerTwoName &&
                ballX >=
                    screenWidth *
                        0.80 && // Player two's threshold (20% from the right)
                ballSpeedX > 0) {
              // Ball moving towards player two
              _onTap();
              lastBounce = 'right';
            }
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

      // Ball bounces off the top and bottom
      if (ballY <= 0 || ballY >= screenHeight - ballSize) {
        ballSpeedY = -ballSpeedY;
        // Add randomness to vertical speed to change bounce angle
        ballSpeedY += (random.nextDouble() - 0.5) *
            2; // Random adjustment between -1 and 1
      }

      // Allow bounce when in range
      if ((ballX <= screenWidth * 0.20 && ballSpeedX < 0) ||
          (ballX >= screenWidth * 0.80 && ballSpeedX > 0)) {
        canBounce = true;
      } else {
        canBounce = false;
      }

      // Scoring Logic
      if (ballX <= 0) {
        // Player Two scores
        playerTwoScore++;
        announcement = '${widget.playerTwoName} scores!';
        _announceAndResetBall();
      } else if (ballX >= screenWidth - ballSize) {
        // Player One scores
        playerOneScore++;
        announcement = '${widget.playerOneName} scores!';
        _announceAndResetBall();
      }
    });
  }

  void _announceAndResetBall() {
    // Stop the timer and show the announcement for a brief moment before resetting the ball
    timer.cancel();
    setState(() {}); // Update state to show announcement

    Future.delayed(const Duration(seconds: 2), () {
      if (playerOneScore >= 5) {
        _showGameOverDialog(widget.playerOneName);
      } else if (playerTwoScore >= 5) {
        _showGameOverDialog(widget.playerTwoName);
      } else {
        setState(() {
          announcement = ''; // Clear the announcement
        });
        _resetBall(); // Reset ball position and speed
      }
    });
  }

  void _resetBall() {
    ballSpeedX = 3; // Reset speed to initial value
    ballSpeedY = 0; // Reset vertical speed
    _startBallMovement();
  }

  void _onTap() {
    if (canBounce) {
      setState(() {
        ballSpeedX = -ballSpeedX; // Reverse the ball direction

        // Increase speed with randomness in bounce angle
        ballSpeedY = ballSpeedY * 1.2 +
            (random.nextDouble() - 0.5) * 2; // Increase with randomness
        ballSpeedX *= 1.2; // Increase horizontal speed

        backgroundColor = Colors.yellow.shade50; // Reset background color
        canBounce = false; // Reset bounce after swing
      });
    }
  }

  void _showGameOverDialog(String winner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text(
              '$winner wins! Final Score - ${widget.playerOneName}: $playerOneScore, ${widget.playerTwoName}: $playerTwoScore'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _resetGame(); // Reset the game
              },
              child: const Text('Replay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
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
    // Reset scores and start a new game
    setState(() {
      playerOneScore = 0;
      playerTwoScore = 0;
    });
    _resetBall(); // Restart ball movement
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!isInitialized) {
            screenWidth = constraints.maxWidth;
            screenHeight = constraints.maxHeight;
            ballSize =
                screenWidth * 0.025; // Set ball size to 2.5% of screen width
            circleSize =
                screenWidth * 0.20; // Set circle size to 20% of screen width
            isInitialized = true;
            _startBallMovement(); // Start ball movement only after initializing screen dimensions
          }

          return GestureDetector(
            onTap: _onTap,
            child: Container(
              color: backgroundColor,
              child: Stack(
                children: [
                  // Center Line - Thicker for better visibility
                  Positioned(
                    top: 0,
                    left: screenWidth / 2,
                    bottom: 0,
                    child: Container(
                      width: 4, // Thicker line for center screen
                      color: Colors.grey.withOpacity(0.8),
                    ),
                  ),
                  // Center Circle for Decoration (Outlined)
                  Positioned(
                    top: screenHeight / 2 - circleSize / 2,
                    left: screenWidth / 2 - circleSize / 2,
                    child: Container(
                      width: circleSize, // Increased size
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.8),
                            width: 2), // Outlined circle
                      ),
                    ),
                  ),
                  // Player One Threshold Line
                  Positioned(
                    top: 0,
                    left: screenWidth * 0.20,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  // Player Two Threshold Line
                  Positioned(
                    top: 0,
                    right: screenWidth * 0.20,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  // Player One Name
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Text(
                      '${widget.playerOneName}: $playerOneScore',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Player Two Name
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Text(
                      '${widget.playerTwoName}: $playerTwoScore',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Announcement Text
                  if (announcement.isNotEmpty)
                    Center(
                      child: Text(
                        announcement,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
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
