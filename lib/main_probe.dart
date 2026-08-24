/// Separate entry point for the PROPOSAL-009 animation probe.
///
///     flutter run -t lib/main_probe.dart
///
/// The product's own `main.dart` never imports this, and nothing in the app
/// routes to it. Delete both files once the animation direction is settled.
library;

import 'package:flutter/material.dart';

import 'dev/mesh_probe.dart';

void main() => runApp(const MeshProbeApp());
