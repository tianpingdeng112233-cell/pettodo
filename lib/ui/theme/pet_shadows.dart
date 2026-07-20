import 'package:flutter/material.dart';

abstract final class PetShadows {
  static const List<BoxShadow> task = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(190, 140, 80, 0.10),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
  static const List<BoxShadow> taskDone = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(242, 166, 90, 0.22),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
  static const List<BoxShadow> panel = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(190, 140, 80, 0.08),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
  static const List<BoxShadow> primaryButton = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(242, 166, 90, 0.35),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];
  static const List<BoxShadow> banner = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(150, 95, 40, 0.22),
      offset: Offset(0, 10),
      blurRadius: 26,
    ),
  ];
  static const List<BoxShadow> theaterButton = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];
  static const List<BoxShadow> toggleKnob = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.15),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
  static const List<BoxShadow> petChoice = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(242, 166, 90, 0.18),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
}
