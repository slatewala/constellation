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
  // stars stored as normalized coords [0..1] x [0..1]
  List<Offset> _stars = [];
  List<int> _pattern = [];
  List<int> _userOrder = [];
  bool _showing = true;
  bool _gameOver = false;
  int _round = 1;
  int _best = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _hideTimer?.cancel();
    final n = 5 + _round;
    // normalized: x in [0.05, 0.95], y in [0.18, 0.82]
    _stars = List.generate(n, (_) =>
      Offset(0.05 + _rng.nextDouble() * 0.90,
             0.18 + _rng.nextDouble() * 0.64));
    final patternLen = min(3 + _round, n);
    final indices = List.generate(n, (i) => i)..shuffle(_rng);
    _pattern = indices.take(patternLen).toList();
    _userOrder = [];
    _showing = true;
    _gameOver = false;
    if (mounted) setState(() {});
    _hideTimer = Timer(Duration(milliseconds: 1100 + patternLen * 280), () {
      if (!mounted) return;
      setState(() => _showing = false);
    });
  }

  void _tapStarAt(Offset localPos, Size area) {
    if (area.width == 0 || area.height == 0) return;
    if (_showing) return;
    if (_gameOver) { _newRound(); return; }
    int? hit;
    double bestDist = double.infinity;
    for (int i = 0; i < _stars.length; i++) {
      final pos = Offset(_stars[i].dx * area.width, _stars[i].dy * area.height);
      final d = (pos - localPos).distance;
      if (d < 50 && d < bestDist) { hit = i; bestDist = d; }
    }
    if (hit == null) return;
    _sfx.play(AssetSource('sfx.wav'));
    setState(() => _userOrder.add(hit!));
    final ok = _userOrder.last == _pattern[_userOrder.length - 1];
    if (!ok) {
      setState(() => _gameOver = true);
      return;
    }
    if (_userOrder.length == _pattern.length) {
      if (_round > _best) _best = _round;
      _round++;
      Timer(const Duration(milliseconds: 600), _newRound);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sfx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06081C),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final area = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerUp: (e) => _tapStarAt(e.localPosition, area),
                child: CustomPaint(
                  size: area,
                  painter: _Painter(
                    stars: _stars,
                    pattern: _pattern,
                    userOrder: _userOrder,
                    showing: _showing,
                  ),
                ),
              ),
              IgnorePointer(
                child: Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(children: [
                      Text('ROUND $_round',
                          style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(_showing
                              ? 'MEMORIZE'
                              : (_gameOver ? 'WRONG! TAP TO RETRY' : 'CONNECT'),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _gameOver
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFD166))),
                      Text('best $_best',
                          style: const TextStyle(color: Colors.white38)),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
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

  Offset _abs(int i, Size s) => Offset(stars[i].dx * s.width, stars[i].dy * s.height);

  @override
  void paint(Canvas c, Size s) {
    // background dust
    final dust = Paint()..color = Colors.white24;
    final r = Random(7);
    for (int i = 0; i < 60; i++) {
      c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
          1.5 + r.nextDouble(), dust);
    }
    // pattern lines (only while showing) or user lines
    final list = showing ? pattern : userOrder;
    final line = Paint()
      ..color = const Color(0xFF42A5F5).withOpacity(showing ? 0.85 : 0.65)
      ..strokeWidth = 3;
    for (int i = 1; i < list.length; i++) {
      c.drawLine(_abs(list[i-1], s), _abs(list[i], s), line);
    }
    // stars
    for (int i = 0; i < stars.length; i++) {
      final pos = _abs(i, s);
      final inPattern = pattern.contains(i);
      final tapped = userOrder.contains(i);
      final lit = (showing && inPattern) || tapped;
      if (lit) {
        c.drawCircle(pos, 26,
            Paint()..color = const Color(0xFFFFD166).withOpacity(0.30));
      }
      c.drawCircle(pos, lit ? 16 : 10,
          Paint()..color = lit ? const Color(0xFFFFD166) : Colors.white);
      // small black core to make them pop
      c.drawCircle(pos, lit ? 4 : 3,
          Paint()..color = lit ? const Color(0xFF6B4F00) : const Color(0xFF222222));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}
