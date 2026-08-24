/// Throwaway comparison probe for PROPOSAL-009.
///
/// Not part of the product: no route reaches it, and `main_probe.dart` is a
/// separate entry point (`flutter run -t lib/main_probe.dart`). It exists to
/// answer one question by eye — does mesh deformation of a single frame read as
/// smoother than 8 fps frame stepping, without looking rubbery?
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../sprite/pet_sprite.dart';
import '../sprite/sprite_atlas.dart';

/// Per-frame durations from the v2 pet contract
/// (`~/.codex/skills/hatch-pet/references/animation-rows.md`).
///
/// The app currently plays every row at a flat 8 fps — 125 ms a frame — which
/// flattens the rhythm the contract designs: idle is meant to hold still, blink
/// twice quickly, then hold still again. Even frame timing turns the blink into
/// the same speed as the breathing and removes both pauses.
const Map<String, List<int>> v2FrameDurationsMs = <String, List<int>>{
  'idle': <int>[280, 110, 110, 140, 140, 320],
  'running-right': <int>[120, 120, 120, 120, 120, 120, 120, 220],
  'running-left': <int>[120, 120, 120, 120, 120, 120, 120, 220],
  'waving': <int>[140, 140, 140, 280],
  'jumping': <int>[140, 140, 140, 140, 280],
  'failed': <int>[140, 140, 140, 140, 140, 140, 140, 240],
  'waiting': <int>[150, 150, 150, 150, 150, 260],
  'running': <int>[120, 120, 120, 120, 120, 220],
  'review': <int>[150, 150, 150, 150, 150, 280],
};

/// Frame-steps an atlas row using the contract's own per-frame durations
/// instead of a flat frame rate.
class ContractPacedSprite extends StatefulWidget {
  const ContractPacedSprite({
    super.key,
    required this.atlas,
    this.stateName = 'idle',
  });

  final LoadedSpriteAtlas atlas;
  final String stateName;

  @override
  State<ContractPacedSprite> createState() => _ContractPacedSpriteState();
}

class _ContractPacedSpriteState extends State<ContractPacedSprite>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final durations =
        v2FrameDurationsMs[widget.stateName] ??
        List<int>.filled(
          widget.atlas.definition.sequence(widget.stateName).frameCount,
          125,
        );
    final total = durations.reduce((a, b) => a + b);
    var remainder = (elapsed.inMilliseconds % total).toDouble();
    var next = 0;
    for (var i = 0; i < durations.length; i++) {
      if (remainder < durations[i]) {
        next = i;
        break;
      }
      remainder -= durations[i];
    }
    if (next != _frame && mounted) setState(() => _frame = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PetSprite(
    atlas: widget.atlas,
    stateName: widget.stateName,
    fixedFrame: _frame,
  );
}

/// Smooth 0→1 ramp between [edge0] and [edge1]; used to give each body region
/// a soft influence falloff so neighbouring regions never tear.
double smoothStep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class MeshParams {
  const MeshParams({
    this.breathAmplitude = 0.014,
    this.breathPeriod = 3.2,
    this.swayAmplitude = 0.006,
    this.swayPeriod = 5.7,
    this.headAmplitude = 0.010,
    this.headLag = 0.42,
    this.earAmplitude = 0.014,
    this.earPeriod = 2.3,
    this.regional = true,
    this.columns = 10,
    this.rows = 14,
  });

  /// Fraction of the pet's height the chest travels at the top of a breath.
  final double breathAmplitude;

  /// Seconds per breath. A resting small dog sits around 3 s.
  final double breathPeriod;

  /// Fraction of width the body drifts sideways.
  final double swayAmplitude;

  /// Deliberately not a multiple of [breathPeriod]; matching periods make the
  /// motion read as mechanical.
  final double swayPeriod;

  /// Head travel as a fraction of height. The head also traces a small arc
  /// rather than moving straight up — living things do not move on rails.
  final double headAmplitude;

  /// Seconds the head trails the chest by. This lag *is* the aliveness: rigid
  /// in-phase motion is what makes the whole-body version read as scaling.
  final double headLag;

  /// Ear swing, left and right in opposite phase.
  final double earAmplitude;
  final double earPeriod;

  /// Off = one breath applied to the whole body (the first probe's behaviour),
  /// on = per-region drivers with phase offsets.
  final bool regional;

  final int columns;
  final int rows;

  MeshParams copyWith({
    double? breathAmplitude,
    double? breathPeriod,
    double? swayAmplitude,
    double? headAmplitude,
    double? headLag,
    double? earAmplitude,
    bool? regional,
    int? columns,
  }) => MeshParams(
    breathAmplitude: breathAmplitude ?? this.breathAmplitude,
    breathPeriod: breathPeriod ?? this.breathPeriod,
    swayAmplitude: swayAmplitude ?? this.swayAmplitude,
    swayPeriod: swayPeriod,
    headAmplitude: headAmplitude ?? this.headAmplitude,
    headLag: headLag ?? this.headLag,
    earAmplitude: earAmplitude ?? this.earAmplitude,
    earPeriod: earPeriod,
    regional: regional ?? this.regional,
    columns: columns ?? this.columns,
    rows: columns == null ? rows : (columns * 1.4).round(),
  );
}

/// Per-vertex offset for the resting animation.
///
/// The whole point of this function is that different parts of the body are
/// driven by different waves. One wave over the whole silhouette reads as the
/// image being scaled; separate waves with phase offsets read as breathing.
Offset restingOffset({
  required MeshParams params,
  required double seconds,
  required double u,
  required double v,
  required Size dest,
}) {
  // Feet stay planted: everything fades out over the bottom quarter.
  final planted = 1 - smoothStep(0.72, 1.0, v);
  if (planted <= 0) return Offset.zero;

  final chest = math.sin(seconds * 2 * math.pi / params.breathPeriod);

  if (!params.regional) {
    final lift = (1 - v) * planted;
    return Offset(
      params.breathAmplitude * 0.6 * dest.width * (u - 0.5) * lift * chest,
      -params.breathAmplitude * dest.height * lift * chest,
    );
  }

  // Regions overlap deliberately — soft weights, no seams.
  final headW = smoothStep(0.46, 0.06, v) * planted;
  final bodyW = smoothStep(0.86, 0.30, v) * planted;
  // Ears sit high and to the sides of the head.
  final earW = headW * smoothStep(0.16, 0.42, (u - 0.5).abs());

  // Chest expands: rises a little, widens a little.
  var dx = params.breathAmplitude * 0.6 * dest.width * (u - 0.5) * bodyW * chest;
  var dy = -params.breathAmplitude * dest.height * bodyW * chest;

  // Head trails the chest and travels on an arc (x is a quarter-phase behind
  // y), so it nods rather than pistons.
  final lagged = seconds - params.headLag;
  final headY = math.sin(lagged * 2 * math.pi / params.breathPeriod);
  final headX = math.sin(
    lagged * 2 * math.pi / params.breathPeriod - math.pi / 2,
  );
  dy += -params.headAmplitude * dest.height * headW * headY;
  dx += params.headAmplitude * 0.5 * dest.width * headW * headX;

  // Ears swing in opposite phase to each other, on their own slower period.
  final side = (u - 0.5).sign;
  final ear = math.sin(
    seconds * 2 * math.pi / params.earPeriod + (side < 0 ? 0 : math.pi),
  );
  dx += params.earAmplitude * dest.width * earW * ear;
  dy += params.earAmplitude * 0.35 * dest.height * earW * ear.abs();

  // Slow whole-body drift, longest period of all, so nothing ever looks locked.
  final drift = math.sin(seconds * 2 * math.pi / params.swayPeriod);
  dx += params.swayAmplitude * dest.width * (1 - v) * (1 - v) * planted * drift;

  return Offset(dx, dy);
}

/// Lays a vertex grid over one atlas cell and drives the vertices with sine
/// waves. The bottom row is pinned so the pet's feet stay planted.
class MeshPetPainter extends CustomPainter {
  const MeshPetPainter({
    required this.shader,
    required this.source,
    required this.seconds,
    required this.params,
  });

  final ui.ImageShader shader;
  final ui.Rect source;
  final double seconds;
  final MeshParams params;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    final dest = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );

    final cols = params.columns;
    final rows = params.rows;

    final pointCount = (cols + 1) * (rows + 1);
    final positions = Float32List(pointCount * 2);
    final texCoords = Float32List(pointCount * 2);

    var i = 0;
    for (var row = 0; row <= rows; row++) {
      final v = row / rows;
      for (var col = 0; col <= cols; col++) {
        final u = col / cols;
        final offset = restingOffset(
          params: params,
          seconds: seconds,
          u: u,
          v: v,
          dest: dest.size,
        );

        positions[i] = dest.left + u * dest.width + offset.dx;
        positions[i + 1] = dest.top + v * dest.height + offset.dy;
        texCoords[i] = source.left + u * source.width;
        texCoords[i + 1] = source.top + v * source.height;
        i += 2;
      }
    }

    final indices = Uint16List(cols * rows * 6);
    var k = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final topLeft = row * (cols + 1) + col;
        final topRight = topLeft + 1;
        final bottomLeft = topLeft + cols + 1;
        final bottomRight = bottomLeft + 1;
        indices[k++] = topLeft;
        indices[k++] = topRight;
        indices[k++] = bottomLeft;
        indices[k++] = topRight;
        indices[k++] = bottomRight;
        indices[k++] = bottomLeft;
      }
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint()..shader = shader);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(covariant MeshPetPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.params != params ||
      oldDelegate.source != source ||
      oldDelegate.shader != shader;
}

class MeshPet extends StatefulWidget {
  const MeshPet({super.key, required this.atlas, required this.params});

  final LoadedSpriteAtlas atlas;
  final MeshParams params;

  @override
  State<MeshPet> createState() => _MeshPetState();
}

class _MeshPetState extends State<MeshPet>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late ui.ImageShader _shader;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _shader = _makeShader();
    _ticker = createTicker((elapsed) {
      setState(() => _seconds = elapsed.inMicroseconds / 1000000);
    })..start();
  }

  ui.ImageShader _makeShader() => ui.ImageShader(
    widget.atlas.image,
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
    filterQuality: FilterQuality.high,
  );

  @override
  void didUpdateWidget(covariant MeshPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atlas.image != widget.atlas.image) {
      _shader.dispose();
      _shader = _makeShader();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: MeshPetPainter(
      shader: _shader,
      source: widget.atlas.definition.frameRect('idle', 0).uiRect,
      seconds: _seconds,
      params: widget.params,
    ),
    child: const SizedBox.expand(),
  );
}

/// One deformable layer to draw this frame. Two layers with complementary
/// alphas is how a frame-stepped clip is cross-faded in and out of a deformed
/// resting pose.
class _Layer {
  const _Layer({
    required this.source,
    required this.pose,
    required this.alpha,
  });

  final ui.Rect source;
  final _Pose pose;
  final double alpha;
}

class _Pose {
  const _Pose({
    this.verticalScale = 1,
    this.horizontalScale = 1,
    this.riseFraction = 0,
    this.breatheSeconds,
  });

  /// <1 crouches, >1 stretches. Applied about the feet.
  final double verticalScale;
  final double horizontalScale;

  /// Fraction of the pet's height it floats above the ground.
  final double riseFraction;

  /// When set, adds the resting breathing wave at this time.
  final double? breatheSeconds;
}

/// Timeline of one jump, in seconds. Anticipation and recovery are the whole
/// point: a hard cut reads badly mostly because nothing precedes or follows it.
abstract final class _Jump {
  static const double restUntil = 2.0;
  static const double crouchUntil = 2.35;
  static const double airborneUntil = 2.95;
  static const double recoverUntil = 3.4;
  static const double loop = 4.2;
  static const double crossfade = 0.12;

  static bool isAirborne(double t) => t >= crouchUntil && t < airborneUntil;
}

double _lerp(double a, double b, double x) => a + (b - a) * x;

/// Progress through [from]..[to], clamped to 0..1.
double _phase(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

List<_Layer> _smoothTimeline(SpriteAtlasDefinition definition, double t) {
  final idle = definition.frameRect('idle', 0).uiRect;
  final jumpFrames = definition.sequence('jumping').frameCount;

  if (t < _Jump.restUntil) {
    return <_Layer>[
      _Layer(source: idle, pose: _Pose(breatheSeconds: t), alpha: 1),
    ];
  }

  if (t < _Jump.crouchUntil) {
    // Anticipation: settle down onto the haunches before pushing off.
    final k = Curves.easeInOut.transform(
      _phase(t, _Jump.restUntil, _Jump.crouchUntil),
    );
    return <_Layer>[
      _Layer(
        source: idle,
        pose: _Pose(
          verticalScale: _lerp(1, 0.87, k),
          horizontalScale: _lerp(1, 1.06, k),
        ),
        alpha: 1,
      ),
    ];
  }

  if (t < _Jump.airborneUntil) {
    final k = _phase(t, _Jump.crouchUntil, _Jump.airborneUntil);
    final frame = (k * jumpFrames).floor().clamp(0, jumpFrames - 1);
    // Parabola: fastest at take-off, hangs at the apex.
    final rise = 4 * k * (1 - k) * 0.10;
    final air = _Layer(
      source: definition.frameRect('jumping', frame).uiRect,
      pose: _Pose(riseFraction: rise),
      alpha: 1,
    );
    final fade = _phase(t, _Jump.crouchUntil, _Jump.crouchUntil + _Jump.crossfade);
    if (fade >= 1) return <_Layer>[air];
    // Cross-fade out of the crouch so the clip does not pop in.
    return <_Layer>[
      _Layer(
        source: idle,
        pose: const _Pose(verticalScale: 0.87, horizontalScale: 1.06),
        alpha: 1 - fade,
      ),
      _Layer(source: air.source, pose: air.pose, alpha: fade),
    ];
  }

  if (t < _Jump.recoverUntil) {
    // Landing: absorb, overshoot slightly, settle.
    final k = _phase(t, _Jump.airborneUntil, _Jump.recoverUntil);
    final squash = k < 0.35
        ? _lerp(0.88, 1.05, Curves.easeOut.transform(k / 0.35))
        : _lerp(1.05, 1.0, Curves.easeOut.transform((k - 0.35) / 0.65));
    final landing = _Layer(
      source: idle,
      pose: _Pose(verticalScale: squash, horizontalScale: 2 - squash),
      alpha: 1,
    );
    final fade = _phase(
      t,
      _Jump.airborneUntil,
      _Jump.airborneUntil + _Jump.crossfade,
    );
    if (fade >= 1) return <_Layer>[landing];
    return <_Layer>[
      _Layer(
        source: definition
            .frameRect('jumping', jumpFrames - 1)
            .uiRect,
        pose: const _Pose(),
        alpha: 1 - fade,
      ),
      _Layer(source: landing.source, pose: landing.pose, alpha: fade),
    ];
  }

  return <_Layer>[
    _Layer(source: idle, pose: _Pose(breatheSeconds: t), alpha: 1),
  ];
}

class _LayeredMeshPainter extends CustomPainter {
  const _LayeredMeshPainter({
    required this.shader,
    required this.layers,
    required this.params,
  });

  final ui.ImageShader shader;
  final List<_Layer> layers;
  final MeshParams params;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      if (layer.alpha <= 0) continue;
      if (layer.alpha >= 1) {
        _paintLayer(canvas, size, layer);
        continue;
      }
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, layer.alpha),
      );
      _paintLayer(canvas, size, layer);
      canvas.restore();
    }
  }

  void _paintLayer(Canvas canvas, Size size, _Layer layer) {
    final source = layer.source;
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    final dest = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );

    final pose = layer.pose;
    final cols = params.columns;
    final rows = params.rows;
    final breatheSeconds = pose.breatheSeconds;
    final rise = pose.riseFraction * dest.height;

    final pointCount = (cols + 1) * (rows + 1);
    final positions = Float32List(pointCount * 2);
    final texCoords = Float32List(pointCount * 2);

    var i = 0;
    for (var row = 0; row <= rows; row++) {
      final v = row / rows;
      final lift = 1 - v;
      for (var col = 0; col <= cols; col++) {
        final u = col / cols;
        // Scale about the feet (v = 1) and the centre line (u = 0.5).
        final x =
            dest.left +
            dest.width * (0.5 + (u - 0.5) * pose.horizontalScale);
        final y = dest.bottom - dest.height * lift * pose.verticalScale;

        final resting = breatheSeconds == null
            ? Offset.zero
            : restingOffset(
                params: params,
                seconds: breatheSeconds,
                u: u,
                v: v,
                dest: dest.size,
              );

        positions[i] = x + resting.dx;
        positions[i + 1] = y + resting.dy - rise;
        texCoords[i] = source.left + u * source.width;
        texCoords[i + 1] = source.top + v * source.height;
        i += 2;
      }
    }

    final indices = Uint16List(cols * rows * 6);
    var k = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final topLeft = row * (cols + 1) + col;
        final topRight = topLeft + 1;
        final bottomLeft = topLeft + cols + 1;
        final bottomRight = bottomLeft + 1;
        indices[k++] = topLeft;
        indices[k++] = topRight;
        indices[k++] = bottomLeft;
        indices[k++] = topRight;
        indices[k++] = bottomRight;
        indices[k++] = bottomLeft;
      }
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint()..shader = shader);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(covariant _LayeredMeshPainter oldDelegate) => true;
}

/// Left: today's behaviour — swapping `stateName` resets the sprite, which is a
/// hard cut. Right: the same jump with anticipation, travel and recovery.
class TransitionDemo extends StatefulWidget {
  const TransitionDemo({
    super.key,
    required this.atlas,
    required this.params,
  });

  final LoadedSpriteAtlas atlas;
  final MeshParams params;

  @override
  State<TransitionDemo> createState() => _TransitionDemoState();
}

class _TransitionDemoState extends State<TransitionDemo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late ui.ImageShader _shader;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _shader = ui.ImageShader(
      widget.atlas.image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.high,
    );
    _ticker = createTicker((elapsed) {
      setState(
        () => _t = (elapsed.inMicroseconds / 1000000) % _Jump.loop,
      );
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: _Labelled(
          label: 'today — hard cut',
          child: PetSprite(
            atlas: widget.atlas,
            stateName: _Jump.isAirborne(_t) ? 'jumping' : 'idle',
          ),
        ),
      ),
      Expanded(
        child: _Labelled(
          label: 'mesh — anticipate / travel / settle',
          child: CustomPaint(
            painter: _LayeredMeshPainter(
              shader: _shader,
              layers: _smoothTimeline(widget.atlas.definition, _t),
              params: widget.params,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}

class MeshProbeApp extends StatelessWidget {
  const MeshProbeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8A24C)),
    ),
    home: const _ProbeScreen(),
  );
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  LoadedSpriteAtlas? _atlas;
  MeshParams _params = const MeshParams();
  final bool _sideBySide = true;
  bool _showTransition = false;
  bool _contractTiming = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loader = SpriteAtlasLoader();
    final pets = await loader.loadManifest();
    final atlas = await loader.loadPet(pets.first);
    if (mounted) setState(() => _atlas = atlas);
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      body: SafeArea(
        child: atlas == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('resting'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('jump transition'),
                        ),
                      ],
                      selected: <bool>{_showTransition},
                      onSelectionChanged: (value) =>
                          setState(() => _showTransition = value.first),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Text(
                      'left: today   right: mesh deformation',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF7A5B3A)),
                    ),
                  ),
                  Expanded(
                    child: _showTransition
                        ? TransitionDemo(atlas: atlas, params: _params)
                        : _sideBySide
                        ? Row(
                            children: <Widget>[
                              Expanded(
                                child: _Labelled(
                                  label: _contractTiming
                                      ? 'frames, contract timing'
                                      : 'frames, flat 8fps (today)',
                                  child: _contractTiming
                                      ? ContractPacedSprite(atlas: atlas)
                                      : PetSprite(atlas: atlas),
                                ),
                              ),
                              Expanded(
                                child: _Labelled(
                                  label: 'mesh',
                                  child: MeshPet(
                                    atlas: atlas,
                                    params: _params,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _Labelled(
                            label: 'mesh (full width)',
                            child: MeshPet(atlas: atlas, params: _params),
                          ),
                  ),
                  _Controls(
                    params: _params,
                    contractTiming: _contractTiming,
                    onParams: (value) => setState(() => _params = value),
                    onContractTiming: (value) =>
                        setState(() => _contractTiming = value),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(child: child),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9C8B76)),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.params,
    required this.contractTiming,
    required this.onParams,
    required this.onContractTiming,
  });

  final MeshParams params;
  final bool contractTiming;
  final ValueChanged<MeshParams> onParams;
  final ValueChanged<bool> onContractTiming;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      children: <Widget>[
        _Slider(
          label: 'breath amplitude',
          value: params.breathAmplitude,
          min: 0,
          max: 0.06,
          display: '${(params.breathAmplitude * 100).toStringAsFixed(1)}%',
          onChanged: (value) =>
              onParams(params.copyWith(breathAmplitude: value)),
        ),
        _Slider(
          label: 'head travel',
          value: params.headAmplitude,
          min: 0,
          max: 0.05,
          display: '${(params.headAmplitude * 100).toStringAsFixed(1)}%',
          onChanged: (value) =>
              onParams(params.copyWith(headAmplitude: value)),
        ),
        _Slider(
          label: 'head lag',
          value: params.headLag,
          min: 0,
          max: 1.2,
          display: '${params.headLag.toStringAsFixed(2)}s',
          onChanged: (value) => onParams(params.copyWith(headLag: value)),
        ),
        _Slider(
          label: 'ear swing',
          value: params.earAmplitude,
          min: 0,
          max: 0.05,
          display: '${(params.earAmplitude * 100).toStringAsFixed(1)}%',
          onChanged: (value) => onParams(params.copyWith(earAmplitude: value)),
        ),
        _Slider(
          label: 'body drift',
          value: params.swayAmplitude,
          min: 0,
          max: 0.04,
          display: '${(params.swayAmplitude * 100).toStringAsFixed(1)}%',
          onChanged: (value) =>
              onParams(params.copyWith(swayAmplitude: value)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('per-region', style: TextStyle(fontSize: 12)),
            Switch(
              value: params.regional,
              onChanged: (value) =>
                  onParams(params.copyWith(regional: value)),
            ),
            const SizedBox(width: 12),
            const Text('contract timing', style: TextStyle(fontSize: 12)),
            Switch(value: contractTiming, onChanged: onContractTiming),
          ],
        ),
      ],
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        width: 120,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 56,
        child: Text(
          display,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}
