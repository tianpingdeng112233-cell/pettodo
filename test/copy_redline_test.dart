import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib string literals contain no pressure or deprivation copy', () {
    const forbidden = <String>[
      'hungry',
      'starv',
      'feed me',
      "don't forget",
      'streak',
      'days in a row',
      'waiting to eat',
      'waiting for you',
      'time to feed',
      'come back',
      'misses you',
    ];
    // Literals that CONTAIN a forbidden word only to promise its absence.
    // These are constitutional statements, not pressure copy.
    const exemptLiterals = <String>[
      'Only warm memories — no streaks or missed days',
    ];
    final violations = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final literal in _stringLiteralsIn(source)) {
        if (exemptLiterals.contains(literal.value)) continue;
        final lower = literal.value.toLowerCase();
        for (final phrase in forbidden) {
          if (lower.contains(phrase)) {
            violations.add('${file.path}:${literal.line}: $phrase');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<({int line, String value})> _stringLiteralsIn(String source) sync* {
  var index = 0;
  var line = 1;

  while (index < source.length) {
    final current = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (current == '/' && next == '/') {
      index += 2;
      while (index < source.length && source[index] != '\n') {
        index++;
      }
      continue;
    }
    if (current == '/' && next == '*') {
      index += 2;
      var depth = 1;
      while (index < source.length && depth > 0) {
        final commentCurrent = source[index];
        final commentNext = index + 1 < source.length ? source[index + 1] : '';
        if (commentCurrent == '\n') line++;
        if (commentCurrent == '/' && commentNext == '*') {
          depth++;
          index += 2;
        } else if (commentCurrent == '*' && commentNext == '/') {
          depth--;
          index += 2;
        } else {
          index++;
        }
      }
      continue;
    }

    final raw = current == 'r' && (next == "'" || next == '"');
    final quoteIndex = raw ? index + 1 : index;
    if (quoteIndex < source.length &&
        (source[quoteIndex] == "'" || source[quoteIndex] == '"')) {
      final quote = source[quoteIndex];
      final triple =
          quoteIndex + 2 < source.length &&
          source[quoteIndex + 1] == quote &&
          source[quoteIndex + 2] == quote;
      final delimiterLength = triple ? 3 : 1;
      final literalLine = line;
      final value = StringBuffer();
      index = quoteIndex + delimiterLength;

      while (index < source.length) {
        if (source[index] == '\n') line++;
        if (triple) {
          if (index + 2 < source.length &&
              source[index] == quote &&
              source[index + 1] == quote &&
              source[index + 2] == quote) {
            index += delimiterLength;
            break;
          }
        } else if (source[index] == quote) {
          index++;
          break;
        }

        if (!raw && source[index] == r'\' && index + 1 < source.length) {
          value
            ..write(source[index])
            ..write(source[index + 1]);
          index += 2;
          continue;
        }
        value.write(source[index]);
        index++;
      }

      yield (line: literalLine, value: value.toString());
      continue;
    }

    if (current == '\n') line++;
    index++;
  }
}
