import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

import 'multiplayer_screen.dart';
import 'single_player_screen.dart';

class GameScreen extends StatelessWidget {
  final WebSocket webSocket;
  final String playerOneName;
  final String playerTwoName;

  const GameScreen({
    super.key,
    required this.webSocket,
    required this.playerOneName,
    required this.playerTwoName,
  });

  @override
  Widget build(BuildContext context) {
    // Decide which screen to show based on the number of players
    if (playerTwoName.isEmpty) {
      // Single Player Mode
      return SinglePlayerScreen(
        webSocket: webSocket,
        playerName: playerOneName,
      );
    } else {
      // Multiplayer Mode
      return MultiplayerScreen(
        webSocket: webSocket,
        playerOneName: playerOneName,
        playerTwoName: playerTwoName,
      );
    }
  }
}
