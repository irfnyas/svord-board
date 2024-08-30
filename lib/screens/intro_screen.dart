import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

import 'game_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  WebSocket? webSocket;
  bool isConnected = false;
  String playerOneName = '';
  String playerTwoName = '';

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // Reset players
    playerOneName = '';
    playerTwoName = '';

    // Initialize WebSocket with URL
    webSocket = WebSocket(
      Uri.parse(
          'wss://jabar-chat.staging.digitalservice.id/v1/chat/ws?name=board'),
    );

    // Listen to the connection events
    webSocket!.connection.listen((event) {
      log('Connection Event: $event');
      if (event is Connected) {
        setState(() {
          isConnected = true;
        });
        _joinRoom();
      } else {
        setState(() {
          isConnected = false;
        });
      }
    });

    // Listen for messages from the server
    webSocket!.messages.listen((message) {
      log('Received message: $message');

      if (message.contains('send-message')) {
        final Map<String, dynamic> decodedMessage = jsonDecode(message);
        if (decodedMessage['action'] == 'send-message' &&
            decodedMessage['message'].toString().contains('joined the room')) {
          final String fullMessage = decodedMessage['message'].toString();
          final String playerName = fullMessage.split(' joined the room')[0];

          // Ignore specific player names
          if (playerName != 'pc' &&
              playerName != 'admin' &&
              playerName != 'board' &&
              playerName != 'null') {
            setState(() {
              if (playerOneName.isEmpty) {
                playerOneName = playerName;
              } else if (playerTwoName.isEmpty && playerName != playerOneName) {
                playerTwoName = playerName;
              }
            });
          }
        }
      }

      if (message.contains('user-left')) {
        final Map<String, dynamic> decodedMessage = jsonDecode(message);
        if (decodedMessage['action'] == 'user-left' &&
            decodedMessage['sender'] != null) {
          final String senderName = decodedMessage['sender']['name'];
          if (senderName == playerOneName) {
            setState(() {
              playerOneName = '';
            });
          } else if (senderName == playerTwoName) {
            setState(() {
              playerTwoName = '';
            });
          }
        }
      }
    });
  }

  void _joinRoom() {
    webSocket!.send(jsonEncode({'action': 'join-room', 'message': 'svord'}));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Ping Pong Game!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnected && playerOneName.isNotEmpty
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameScreen(
                            webSocket: webSocket!,
                            playerOneName: playerOneName,
                            playerTwoName: playerTwoName,
                          ),
                        ),
                      ).then((_) {
                        Future.delayed(const Duration(seconds: 1), () {
                          _connectWebSocket();
                        });
                      });
                    }
                  : null,
              child: const Text(
                'Start Game',
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isConnected
                  ? (playerOneName.isNotEmpty
                      ? (playerTwoName.isNotEmpty
                          ? 'Players $playerOneName and $playerTwoName joined. Ready to Start!'
                          : 'Player $playerOneName joined. Waiting for another player...')
                      : 'Waiting for a player to join...')
                  : 'Connecting to Server...',
              style: TextStyle(
                fontSize: 18,
                color: isConnected
                    ? (playerOneName.isNotEmpty
                        ? (playerTwoName.isNotEmpty
                            ? Colors.green
                            : Colors.orange)
                        : Colors.orange)
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
