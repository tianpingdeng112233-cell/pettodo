class RigPoint {
  const RigPoint(this.x, this.y);

  factory RigPoint.fromJson(Object? value, String field) {
    if (value is! List<Object?> || value.length != 2) {
      throw FormatException('$field must contain two pixel coordinates.');
    }
    return RigPoint(
      _coordinate(value[0], '$field.x'),
      _coordinate(value[1], '$field.y'),
    );
  }

  final int x;
  final int y;
}

class RigBox {
  const RigBox(this.x0, this.y0, this.x1, this.y1);

  factory RigBox.fromJson(Object? value, String field) {
    if (value is! List<Object?> || value.length != 4) {
      throw FormatException('$field must contain four pixel coordinates.');
    }
    final box = RigBox(
      _coordinate(value[0], '$field.x0'),
      _coordinate(value[1], '$field.y0'),
      _coordinate(value[2], '$field.x1'),
      _coordinate(value[3], '$field.y1'),
    );
    if (box.x0 >= box.x1 || box.y0 >= box.y1) {
      throw FormatException('$field must have positive area.');
    }
    return box;
  }

  final int x0;
  final int y0;
  final int x1;
  final int y1;

  int get width => x1 - x0;
  int get height => y1 - y0;

  bool fits(int imageWidth, int imageHeight) =>
      x0 >= 0 && y0 >= 0 && x1 <= imageWidth && y1 <= imageHeight;
}

RigBox? _optionalBox(Object? value, String field) {
  if (value == null) return null;
  try {
    return RigBox.fromJson(value, field);
  } on FormatException {
    return null;
  }
}

RigPoint? _optionalPoint(Object? value, String field) {
  if (value == null) return null;
  try {
    return RigPoint.fromJson(value, field);
  } on FormatException {
    return null;
  }
}

class FrontRigDefinition {
  const FrontRigDefinition({
    required this.groundY,
    required this.head,
    required this.tail,
    required this.leftFrontLeg,
    required this.rightFrontLeg,
    required this.headPivot,
    required this.tailPivot,
  });

  factory FrontRigDefinition.fromJson(Object? value) {
    final map = _object(value, 'front');
    final boxes = _object(map['boxes'], 'front.boxes');
    final pivots = _object(map['pivots'], 'front.pivots');
    return FrontRigDefinition(
      groundY: _coordinate(map['groundY'], 'front.groundY'),
      head: _optionalBox(boxes['head'], 'front.boxes.head'),
      tail: RigBox.fromJson(boxes['tail'], 'front.boxes.tail'),
      leftFrontLeg: RigBox.fromJson(
        boxes['leftFrontLeg'],
        'front.boxes.leftFrontLeg',
      ),
      rightFrontLeg: RigBox.fromJson(
        boxes['rightFrontLeg'],
        'front.boxes.rightFrontLeg',
      ),
      headPivot: _optionalPoint(pivots['head'], 'front.pivots.head'),
      tailPivot: RigPoint.fromJson(pivots['tail'], 'front.pivots.tail'),
    );
  }

  final int groundY;

  /// Null means the producer rejected head detection; render full front poses.
  final RigBox? head;
  final RigBox tail;
  final RigBox leftFrontLeg;
  final RigBox rightFrontLeg;
  final RigPoint? headPivot;
  final RigPoint tailPivot;

  void validateForImage(int width, int height) {
    if (groundY < 0 || groundY > height) {
      throw const FormatException('front.groundY is outside the image.');
    }
    for (final entry in <(String, RigBox)>[
      ('tail', tail),
      ('leftFrontLeg', leftFrontLeg),
      ('rightFrontLeg', rightFrontLeg),
    ]) {
      if (!entry.$2.fits(width, height)) {
        throw FormatException('front.boxes.${entry.$1} is outside the image.');
      }
    }
    _validatePivot(tailPivot, width, height, 'front.pivots.tail');
  }

  FrontRigDefinition withoutHead() => FrontRigDefinition(
    groundY: groundY,
    head: null,
    tail: tail,
    leftFrontLeg: leftFrontLeg,
    rightFrontLeg: rightFrontLeg,
    headPivot: null,
    tailPivot: tailPivot,
  );
}

class SideRigDefinition {
  const SideRigDefinition({
    required this.groundY,
    required this.facing,
    required this.head,
    required this.tail,
    required this.frontLeg,
    required this.hindLeg,
    required this.headPivot,
    required this.tailPivot,
    required this.frontLegPivot,
    required this.hindLegPivot,
  });

  factory SideRigDefinition.fromJson(Object? value) {
    final map = _object(value, 'side');
    final facing = map['facing'];
    if (facing != 'right') {
      throw const FormatException('side.facing must be right.');
    }
    final boxes = _object(map['boxes'], 'side.boxes');
    final pivots = _object(map['pivots'], 'side.pivots');
    return SideRigDefinition(
      groundY: _coordinate(map['groundY'], 'side.groundY'),
      facing: facing as String,
      head: RigBox.fromJson(boxes['head'], 'side.boxes.head'),
      tail: RigBox.fromJson(boxes['tail'], 'side.boxes.tail'),
      frontLeg: RigBox.fromJson(boxes['frontLeg'], 'side.boxes.frontLeg'),
      hindLeg: RigBox.fromJson(boxes['hindLeg'], 'side.boxes.hindLeg'),
      headPivot: RigPoint.fromJson(pivots['head'], 'side.pivots.head'),
      tailPivot: RigPoint.fromJson(pivots['tail'], 'side.pivots.tail'),
      frontLegPivot: RigPoint.fromJson(
        pivots['frontLeg'],
        'side.pivots.frontLeg',
      ),
      hindLegPivot: RigPoint.fromJson(pivots['hindLeg'], 'side.pivots.hindLeg'),
    );
  }

  final int groundY;
  final String facing;
  final RigBox head;
  final RigBox tail;
  final RigBox frontLeg;
  final RigBox hindLeg;
  final RigPoint headPivot;
  final RigPoint tailPivot;
  final RigPoint frontLegPivot;
  final RigPoint hindLegPivot;

  void validateForImage(int width, int height) {
    if (groundY < 0 || groundY > height) {
      throw const FormatException('side.groundY is outside the image.');
    }
    for (final entry in <(String, RigBox)>[
      ('head', head),
      ('tail', tail),
      ('frontLeg', frontLeg),
      ('hindLeg', hindLeg),
    ]) {
      if (!entry.$2.fits(width, height)) {
        throw FormatException('side.boxes.${entry.$1} is outside the image.');
      }
    }
    _validatePivot(headPivot, width, height, 'side.pivots.head');
    _validatePivot(tailPivot, width, height, 'side.pivots.tail');
    _validatePivot(frontLegPivot, width, height, 'side.pivots.frontLeg');
    _validatePivot(hindLegPivot, width, height, 'side.pivots.hindLeg');
  }
}

class RigDefinition {
  const RigDefinition({
    required this.rigVersion,
    required this.front,
    required this.side,
  });

  factory RigDefinition.fromJson(Object? value) {
    final map = _object(value, 'rig');
    if (map['rigVersion'] != 1) {
      throw const FormatException('The rig version is not supported.');
    }
    return RigDefinition(
      rigVersion: 1,
      front: FrontRigDefinition.fromJson(map['front']),
      side: SideRigDefinition.fromJson(map['side']),
    );
  }

  final int rigVersion;
  final FrontRigDefinition front;
  final SideRigDefinition side;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be an object.');
  }
  return value;
}

int _coordinate(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

void _validatePivot(RigPoint point, int width, int height, String field) {
  if (point.x < 0 || point.y < 0 || point.x > width || point.y > height) {
    throw FormatException('$field is outside the image.');
  }
}
