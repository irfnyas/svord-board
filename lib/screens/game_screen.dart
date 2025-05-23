import 'package:board/screens/hunt_screen.dart';
import 'package:board/screens/multiplayer_screen.dart';
import 'package:board/screens/single_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

class GameScreen extends StatelessWidget {
  final WebSocket webSocket;
  final String playerOneName;
  final String playerTwoName;
  final String gameMode;

  const GameScreen({
    super.key,
    required this.webSocket,
    required this.playerOneName,
    required this.playerTwoName,
    this.gameMode = 'single-pingpong',
  });

  @override
  Widget build(BuildContext context) {
    switch (gameMode) {
      case 'hunt':
        return HuntScreen(webSocket: webSocket, autoStart: true);
      case 'multi-pingpong':
        return MultiplayerScreen(
          webSocket: webSocket,
          playerOneName: playerOneName,
          playerTwoName: playerTwoName,
        );
      case 'single-pingpong':
      default:
        return SinglePlayerScreen(
          webSocket: webSocket,
          playerName: playerOneName,
        );
    }
  }
}
