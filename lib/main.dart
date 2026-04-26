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
  // normalized 0..1 coords
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
    _generate();
    // schedule first reveal-end after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleHide());
  }

  void _generate() {
    // gentle curve:
    //   round 1: 4 stars, pattern 2
    //   round 2: 5 stars, pattern 3
    //   round 3: 6 stars, pattern 3
    //   round 4: 7 stars, pattern 4
    //   round 5: 8 stars, pattern 4
    //   round n>=6: stars 3+n, pattern 1 + (n+1)/2 (capped)
    final n = 3 + _round;
    final patternLen = min(1 + ((_round + 1) ~/ 2) + (_round > 6 ? _round - 6 : 0), n);
    // spread stars on a gentle grid so they don't overlap
    _stars = _spreadStars(n);
    final indices = List.generate(n, (i) => i)..shuffle(_rng);
    _pattern = indices.take(patternLen).toList();
    _userOrder = [];
    _showing = true;
    _gameOver = false;
  }

  List<Offset> _spreadStars(int n) {
    // jittered grid: pick cells from a 4xN grid, then jitter
    final cols = 4;
    final rows = (n / cols).ceil() + 1;
    final cells = <Offset>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = (c + 0.5) / cols;
        final cy = 0.18 + (r + 0.5) / rows * 0.65;
        cells.add(Offset(cx, cy));
      }
    }
    cells.shuffle(_rng);
    return cells.take(n).map((p) => Offset(
      (p.dx + (_rng.nextDouble() - 0.5) * 0.12).clamp(0.06, 0.94),
      (p.dy + (_rng.nextDouble() - 0.5) * 0.08).clamp(0.18, 0.82),
    )).toList();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // generous early, tightens with rounds
    final perItem = max(280, 480 - _round * 20);
    final d = 1100 + _pattern.length * perItem;
    _hideTimer = Timer(Duration(milliseconds: d), () {
      if (!mounted) return;
      setState(() => _showing = false);
    });
  }

  void _newRound() {
    setState(_generate);
    _scheduleHide();
  }

  void _tapStarAt(Offset localPos, Size area) {
    if (area.width == 0 || area.height == 0) return;
    if (_gameOver) { _newRound(); return; }
    if (_showing) return;
    int? hit;
    double bestDist = double.infinity;
    for (int i = 0; i < _stars.length; i++) {
      final pos = Offset(_stars[i].dx * area.width, _stars[i].dy * area.height);
      final d = (pos - localPos).distance;
      if (d < 56 && d < bestDist) { hit = i; bestDist = d; }
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
            return Stack(
              fit: StackFit.expand,
              children: [
                // game canvas + tap layer
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
                // HUD overlay (no pointer interception)
                Positioned(
                  top: 16, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Column(children: [
                      Text('ROUND $_round',
                          style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(_showing
                              ? 'MEMORIZE'
                              : (_gameOver ? 'WRONG · TAP TO RETRY' : 'CONNECT'),
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _gameOver
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFD166))),
                      Text('best $_best',
                          style: const TextStyle(color: Colors.white38)),
                    ]),
                  ),
                ),
              ],
            );
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

  Offset _abs(int i, Size s) =>
      Offset(stars[i].dx * s.width, stars[i].dy * s.height);

  @override
  void paint(Canvas c, Size s) {
    // background dust (always renders so screen is never blank)
    final dust = Paint()..color = Colors.white24;
    final r = Random(7);
    for (int i = 0; i < 70; i++) {
      c.drawCircle(
          Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
          1.0 + r.nextDouble() * 1.5, dust);
    }
    if (stars.isEmpty) return;
    // lines: showing pattern OR user-drawn
    final list = showing ? pattern : userOrder;
    final line = Paint()
      ..color = const Color(0xFF42A5F5).withOpacity(showing ? 0.9 : 0.65)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i < list.length; i++) {
      c.drawLine(_abs(list[i-1], s), _abs(list[i], s), line);
    }
    // stars
    for (int i = 0; i < stars.length; i++) {
      final pos = _abs(i, s);
      final inPattern = pattern.contains(i);
      final tapped = userOrder.contains(i);
      final lit = (showing && inPattern) || tapped;
      // halo
      if (lit) {
        c.drawCircle(pos, 30,
            Paint()..color = const Color(0xFFFFD166).withOpacity(0.30));
      }
      c.drawCircle(pos, lit ? 18 : 12,
          Paint()..color = lit ? const Color(0xFFFFD166) : Colors.white);
      c.drawCircle(pos, lit ? 6 : 4,
          Paint()..color = lit ? const Color(0xFF6B4F00) : const Color(0xFF222244));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}
