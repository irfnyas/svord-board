import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';

enum GameState { idle, playing, finished }

class Duck {
  double dx; // horizontal 0..1 (can start <0 or >1)
  double dy; // vertical 0..2 (row fraction, may be fractional)
  int hDir; // +1 →, -1 ←
  int vDir; // -1 up, 0 straight, +1 down
  Duck(
      {required this.dx,
      required this.dy,
      required this.hDir,
      required this.vDir});
}

class Explosion {
  double dx; // exact x (fraction of width)
  double dy; // exact y (0..2 range)
  int ticksLeft;
  Explosion(this.dx, this.dy, this.ticksLeft);
}

class HuntScreen extends StatefulWidget {
  final WebSocket webSocket;
  final bool autoStart; // New param to control whether game starts immediately

  const HuntScreen(
      {super.key, required this.webSocket, this.autoStart = false});

  @override
  State<HuntScreen> createState() => _HuntScreenState();
}

class _HuntScreenState extends State<HuntScreen> {
  static const int _playSeconds = 60;
  static const _spawnInterval = Duration(milliseconds: 1200);
  static const _moveInterval = Duration(milliseconds: 30);
  static const double _baseSpeedPerTick = 0.003;
  static const double _speedIncrementPerSecond = 0.00025;
  static const double _verticalFactor = 0.4;
  static const int _boomTicks = 10;
  static const double _rightOff = 1.30; // remove at 130 % width
  static const double _leftOff = -0.30; // remove at −30 % width

  final Random _rand = Random();

  GameState _state = GameState.idle;
  int _score = 0;
  int _timeLeft = _playSeconds;
  double _currentSpeedPerTick = _baseSpeedPerTick;
  final List<Duck> _ducks = [];
  final List<Explosion> _explosions = [];

  Timer? _spawnTimer;
  Timer? _moveTimer;
  Timer? _countdownTimer;
  Size? _playAreaSize;

  final List<Offset> _shootPoints =
      []; // List to hold positions of the shoot points
  static const int _shootDuration =
      20; // Number of frames the shoot point will be shown

  @override
  void initState() {
    super.initState();
    _listenToWebSocket();
    if (widget.autoStart) {
      _startGame();
    }
  }

  void _listenToWebSocket() {
    widget.webSocket.messages.listen((message) {
      try {
        final Map<String, dynamic> decodedMessage = jsonDecode(message);
        if (decodedMessage['action'] == 'send-message' &&
            decodedMessage['message'] != null &&
            decodedMessage['message'].startsWith('shoot')) {
          final parts = decodedMessage['message'].split(',');
          if (parts.length == 3) {
            final normX = double.tryParse(parts[1]);
            final normY = double.tryParse(parts[2]);
            if (normX != null && normY != null && _playAreaSize != null) {
              _handleRemoteShoot(normX, normY);
            }
          }
        }
      } catch (e) {
        // Ignore JSON errors
      }
    });
  }

  void _handleRemoteShoot(double normX, double normY) {
    if (normX < 0 || normX > 1 || normY < 0 || normY > 1) {
      debugPrint(
          'Ignored shoot command with out-of-bounds coordinates: ($normX, $normY)');
      return;
    }

    final localX = normX * _playAreaSize!.width;
    final localY = (1 - normY) * _playAreaSize!.height; // flip y axis
    final localPosition = Offset(localX, localY);

    // Add the shoot point and set a timer to remove it
    setState(() {
      _shootPoints.add(localPosition);
    });

    // Remove the shoot point after _shootDuration frames
    Future.delayed(const Duration(milliseconds: _shootDuration * 30), () {
      setState(() {
        _shootPoints.remove(localPosition);
      });
    });

    _handleTap(localPosition, _playAreaSize!);
  }

  void _startGame() {
    setState(() {
      _state = GameState.playing;
      _score = 0;
      _timeLeft = _playSeconds;
      _currentSpeedPerTick = _baseSpeedPerTick;
      _ducks.clear();
      _explosions.clear();
    });

    _spawnTimer?.cancel();
    _moveTimer?.cancel();
    _countdownTimer?.cancel();

    _spawnTimer = Timer.periodic(_spawnInterval, (_) => _spawnDuck());
    _moveTimer = Timer.periodic(_moveInterval, (_) => _gameTick());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        final elapsed = _playSeconds - _timeLeft;
        _currentSpeedPerTick =
            _baseSpeedPerTick + elapsed * _speedIncrementPerSecond;
        if (_timeLeft <= 0) _finishGame();
      });
    });
  }

  void _finishGame() {
    _spawnTimer?.cancel();
    _moveTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _state = GameState.finished;
      _ducks.clear();
      _explosions.clear();
    });
  }

  void _spawnDuck() {
    final fromLeft = _rand.nextBool();
    final startDx = fromLeft ? _leftOff : _rightOff;
    final hDir = fromLeft ? 1 : -1;

    final startRow = _rand.nextInt(3);
    final vOptions = [0, -1, 1]..removeWhere(
        (v) => (startRow == 0 && v == -1) || (startRow == 2 && v == 1));
    final vDir = vOptions[_rand.nextInt(vOptions.length)];

    _ducks.add(
        Duck(dx: startDx, dy: startRow.toDouble(), hDir: hDir, vDir: vDir));
  }

  void _gameTick() {
    setState(() {
      for (final d in _ducks) {
        d.dx += d.hDir * _currentSpeedPerTick;
        d.dy += d.vDir * _currentSpeedPerTick * _verticalFactor;
        if (d.dy < 0) {
          d.dy = 0;
          d.vDir = 0;
        } else if (d.dy > 2) {
          d.dy = 2;
          d.vDir = 0;
        }
      }
      _ducks.removeWhere((d) =>
          (d.hDir == 1 && d.dx > _rightOff) ||
          (d.hDir == -1 && d.dx < _leftOff));

      for (final e in _explosions) {
        e.ticksLeft--;
      }
      _explosions.removeWhere((e) => e.ticksLeft <= 0);
    });
  }

  void _handleTap(Offset pos, Size area) {
    if (_state != GameState.playing) return;
    final cellW = area.width / 3;
    final cellH = area.height / 3;
    final tapCol = (pos.dx / cellW).floor().clamp(0, 2);
    final tapRow = (pos.dy / cellH).floor().clamp(0, 2);

    int hitIdx = -1;
    for (var i = 0; i < _ducks.length; i++) {
      final d = _ducks[i];
      final centerDx = d.dx + (1 / 6);
      final centerDy = d.dy + 0.5;
      final centerCol = (centerDx.clamp(0, 0.999) * 3).floor();
      final centerRow = centerDy.clamp(0, 2.999).floor();
      if (centerCol == tapCol && centerRow == tapRow) {
        hitIdx = i;
        break;
      }
    }

    if (hitIdx != -1) {
      setState(() {
        final duck = _ducks.removeAt(hitIdx);
        _score++;
        _explosions.add(Explosion(duck.dx, duck.dy, _boomTicks));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_state == GameState.playing
            ? 'Score: $_score'
            : 'Duck Hunt Prototype'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _playAreaSize = Size(constraints.maxWidth, constraints.maxHeight);
          final cellW = _playAreaSize!.width / 3;
          final cellH = _playAreaSize!.height / 3;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _handleTap(details.localPosition, _playAreaSize!),
            child: Stack(
              children: [
                IgnorePointer(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio:
                          _playAreaSize!.width / _playAreaSize!.height,
                    ),
                    itemCount: 9,
                    itemBuilder: (_, __) => Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.lightBlue.shade100.withOpacity(0.1)),
                      ),
                    ),
                  ),
                ),
                ..._ducks.map((d) => Positioned(
                      left: d.dx * _playAreaSize!.width,
                      top: d.dy * cellH,
                      width: cellW,
                      height: cellH,
                      child: const Center(
                          child: Text('🦆', style: TextStyle(fontSize: 32))),
                    )),
                ..._explosions.map((e) => Positioned(
                      left: e.dx * _playAreaSize!.width,
                      top: e.dy * cellH,
                      width: cellW,
                      height: cellH,
                      child: const Center(
                          child: Text('💥', style: TextStyle(fontSize: 32))),
                    )),
                // Draw the red circles for the shoot points
                ..._shootPoints.map((shootPoint) => Positioned(
                      left: shootPoint.dx - 10, // Adjust for the circle radius
                      top: shootPoint.dy - 10,
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                      ),
                    )),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Text('Time: $_timeLeft',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
