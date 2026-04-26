import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const ConstellationApp());

class ConstellationApp extends StatelessWidget {
  const ConstellationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Constellation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const GamePage(),
      );
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _sfx = AudioPlayer();
  final _rng = Random();
  List<Offset> _stars = [];
  List<int> _pattern = [];
  List<int> _userOrder = [];
  bool _showing = true;
  bool _gameOver = false;
  int _round = 1;
  int _best = 0;
  Size _size = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_size == Size.zero) {
      _size = MediaQuery.of(context).size;
      if (_stars.isEmpty) _newRound();
    }
  }

  void _newRound() {
    final s = _size == Size.zero ? MediaQuery.of(context).size : _size;
    _size = s;
    final n = 5 + _round; // total stars on screen
    _stars = List.generate(n, (_) =>
      Offset(40 + _rng.nextDouble() * (s.width - 80),
             140 + _rng.nextDouble() * (s.height - 280)));
    final patternLen = min(3 + _round, n);
    final indices = List.generate(n, (i) => i)..shuffle(_rng);
    _pattern = indices.take(patternLen).toList();
    _userOrder = [];
    _showing = true;
    _gameOver = false;
    setState(() {});
    Future.delayed(Duration(milliseconds: 1200 + patternLen * 250), () {
      if (!mounted) return;
      setState(() => _showing = false);
    });
  }

  void _tapStar(int i) {
    if (_showing || _gameOver) {
      if (_gameOver) _newRound();
      return;
    }
    _sfx.play(AssetSource('sfx.wav'));
    setState(() => _userOrder.add(i));
    final ok = _userOrder.length <= _pattern.length &&
        _userOrder.last == _pattern[_userOrder.length - 1];
    if (!ok) {
      setState(() => _gameOver = true);
      return;
    }
    if (_userOrder.length == _pattern.length) {
      if (_round > _best) _best = _round;
      _round++;
      Future.delayed(const Duration(milliseconds: 600), _newRound);
    }
  }

  @override
  void dispose() {
    _sfx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06081C),
      body: SafeArea(
        child: Stack(children: [
          GestureDetector(
            onTapUp: (d) {
              for (int i = 0; i < _stars.length; i++) {
                if ((_stars[i] - d.localPosition).distance < 36) {
                  _tapStar(i);
                  break;
                }
              }
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: _Painter(
                stars: _stars,
                pattern: _pattern,
                userOrder: _userOrder,
                showing: _showing,
              ),
            ),
          ),
          Positioned(
            top: 30, left: 0, right: 0,
            child: Column(children: [
              Text('ROUND $_round',
                  style: const TextStyle(color: Colors.white60)),
              Text(_showing ? 'MEMORIZE' : (_gameOver ? 'TAP ANY STAR' : 'CONNECT'),
                  style: TextStyle(
                      fontSize: 26,
                      color: _gameOver
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFFFFD166))),
              Text('best $_best', style: const TextStyle(color: Colors.white38)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final List<Offset> stars;
  final List<int> pattern, userOrder;
  final bool showing;
  _Painter({required this.stars, required this.pattern,
            required this.userOrder, required this.showing});
  @override
  void paint(Canvas c, Size s) {
    // background dust stars
    final dust = Paint()..color = Colors.white24;
    final r = Random(7);
    for (int i = 0; i < 60; i++) {
      c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
          1.5 + r.nextDouble(), dust);
    }
    // stars
    for (int i = 0; i < stars.length; i++) {
      final inPattern = pattern.contains(i);
      final lit = (showing && inPattern) || userOrder.contains(i);
      final p = Paint()..color = lit ? const Color(0xFFFFD166) : Colors.white;
      c.drawCircle(stars[i], lit ? 14 : 8, p);
      if (lit) {
        c.drawCircle(stars[i], 22,
            Paint()..color = const Color(0xFFFFD166).withOpacity(0.25));
      }
    }
    // lines: showing pattern OR user-drawn so far
    final line = Paint()
      ..color = const Color(0xFF42A5F5).withOpacity(showing ? 0.8 : 0.6)
      ..strokeWidth = 3;
    final list = showing ? pattern : userOrder;
    for (int i = 1; i < list.length; i++) {
      c.drawLine(stars[list[i-1]], stars[list[i]], line);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}
