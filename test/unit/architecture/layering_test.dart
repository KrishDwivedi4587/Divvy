// Guards the separation the architecture depends on: the calculation engine
// and the other pure domain code must stay free of Flutter and the database, so
// the money rules can always be tested (and trusted) without a screen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<File> dartFilesIn(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

Iterable<String> importsOf(File f) =>
    _import.allMatches(f.readAsStringSync()).map((m) => m.group(1)!);

void main() {
  const forbiddenInDomain = [
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:go_router/',
    'package:sqflite/',
    'package:image_picker/',
    'package:google_mlkit',
    'package:path_provider/',
    'dart:ui',
  ];

  final domainDirs = [
    for (final feature in Directory('lib/features').listSync())
      if (feature is Directory &&
          Directory('${feature.path}/domain').existsSync())
        '${feature.path}/domain',
  ];

  test('there are domain directories to check', () {
    expect(domainDirs, isNotEmpty);
  });

  for (final dir in domainDirs) {
    test('$dir imports no framework, UI or storage code', () {
      for (final file in dartFilesIn(dir)) {
        for (final import in importsOf(file)) {
          for (final banned in forbiddenInDomain) {
            expect(
              import.startsWith(banned),
              isFalse,
              reason: '${file.path} imports $import',
            );
          }
        }
      }
    });
  }

  test('domain code does not reach into data or presentation layers', () {
    for (final dir in domainDirs) {
      for (final file in dartFilesIn(dir)) {
        for (final import in importsOf(file)) {
          expect(import.contains('/presentation/'), isFalse, reason: file.path);
          expect(import.contains('/data/'), isFalse, reason: file.path);
          expect(import.contains('/application/'), isFalse, reason: file.path);
        }
      }
    }
  });
}
