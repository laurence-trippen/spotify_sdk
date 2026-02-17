import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bin/gradle_dsl_detector.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gradle_dsl_detector_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('GradleDsl enum', () {
    test('has groovy and kotlin values', () {
      expect(GradleDsl.values, containsAll([GradleDsl.groovy, GradleDsl.kotlin]));
    });
  });

  group('DslDetectionResult', () {
    test('isMixedProject is false when both DSLs are the same', () {
      final result = DslDetectionResult(
        settingsGradleDsl: GradleDsl.groovy,
        appBuildGradleDsl: GradleDsl.groovy,
      );
      expect(result.isMixedProject, isFalse);
    });

    test('isMixedProject is true when DSLs differ', () {
      final result = DslDetectionResult(
        settingsGradleDsl: GradleDsl.groovy,
        appBuildGradleDsl: GradleDsl.kotlin,
      );
      expect(result.isMixedProject, isTrue);
    });

    test('toString includes DSL types and mixed flag', () {
      final result = DslDetectionResult(
        settingsGradleDsl: GradleDsl.kotlin,
        appBuildGradleDsl: GradleDsl.kotlin,
      );
      final str = result.toString();
      expect(str, contains('kotlin'));
      expect(str, contains('false'));
    });
  });

  group('GradleDslDetector.detectFileDsl', () {
    test('detects Kotlin DSL from .gradle.kts extension', () {
      final file = File('${tempDir.path}/settings.gradle.kts');
      file.writeAsStringSync('');

      expect(GradleDslDetector.detectFileDsl(file), GradleDsl.kotlin);
    });

    test('detects Groovy DSL from .gradle extension', () {
      final file = File('${tempDir.path}/settings.gradle');
      file.writeAsStringSync('');

      expect(GradleDslDetector.detectFileDsl(file), GradleDsl.groovy);
    });

    test('.gradle file with plugins block is still Groovy DSL', () {
      final file = File('${tempDir.path}/settings.gradle');
      file.writeAsStringSync('''
plugins {
    id "com.android.application" version "8.0.0" apply false
}
include ":app"
''');

      expect(GradleDslDetector.detectFileDsl(file), GradleDsl.groovy);
    });

    test('.gradle.kts file is always Kotlin DSL regardless of content', () {
      final file = File('${tempDir.path}/build.gradle.kts');
      file.writeAsStringSync("include ':app'"); // Groovy-style content

      expect(GradleDslDetector.detectFileDsl(file), GradleDsl.kotlin);
    });
  });

  group('GradleDslDetector.findGradleFile', () {
    test('finds .gradle.kts file when both exist (prefers .kts)', () {
      File('${tempDir.path}/settings.gradle').writeAsStringSync('');
      File('${tempDir.path}/settings.gradle.kts').writeAsStringSync('');

      final found = GradleDslDetector.findGradleFile(tempDir.path, 'settings.gradle');

      expect(found, isNotNull);
      expect(found!.path, endsWith('.gradle.kts'));
    });

    test('finds .gradle file when only Groovy exists', () {
      File('${tempDir.path}/build.gradle').writeAsStringSync('');

      final found = GradleDslDetector.findGradleFile(tempDir.path, 'build.gradle');

      expect(found, isNotNull);
      expect(found!.path, endsWith('build.gradle'));
      expect(found.path, isNot(endsWith('.kts')));
    });

    test('finds .gradle.kts file when only Kotlin DSL exists', () {
      File('${tempDir.path}/build.gradle.kts').writeAsStringSync('');

      final found = GradleDslDetector.findGradleFile(tempDir.path, 'build.gradle');

      expect(found, isNotNull);
      expect(found!.path, endsWith('.gradle.kts'));
    });

    test('returns null when neither file exists', () {
      final found = GradleDslDetector.findGradleFile(tempDir.path, 'nonexistent.gradle');
      expect(found, isNull);
    });

    test('accepts filename with or without .gradle extension', () {
      File('${tempDir.path}/settings.gradle').writeAsStringSync('');

      final withExt = GradleDslDetector.findGradleFile(tempDir.path, 'settings.gradle');
      final withoutExt = GradleDslDetector.findGradleFile(tempDir.path, 'settings');

      expect(withExt, isNotNull);
      expect(withoutExt, isNotNull);
    });
  });

  group('GradleDslDetector.detectProjectDsl', () {
    test('detects pure Groovy DSL project', () {
      final androidDir = Directory('${tempDir.path}/android')..createSync();
      final appDir = Directory('${androidDir.path}/app')..createSync();

      File('${androidDir.path}/settings.gradle').writeAsStringSync("include ':app'");
      File('${appDir.path}/build.gradle').writeAsStringSync('android {}');

      final result = GradleDslDetector.detectProjectDsl(androidDir.path);

      expect(result.settingsGradleDsl, GradleDsl.groovy);
      expect(result.appBuildGradleDsl, GradleDsl.groovy);
      expect(result.isMixedProject, isFalse);
    });

    test('detects pure Kotlin DSL project', () {
      final androidDir = Directory('${tempDir.path}/android')..createSync();
      final appDir = Directory('${androidDir.path}/app')..createSync();

      File('${androidDir.path}/settings.gradle.kts').writeAsStringSync('include(":app")');
      File('${appDir.path}/build.gradle.kts').writeAsStringSync('android {}');

      final result = GradleDslDetector.detectProjectDsl(androidDir.path);

      expect(result.settingsGradleDsl, GradleDsl.kotlin);
      expect(result.appBuildGradleDsl, GradleDsl.kotlin);
      expect(result.isMixedProject, isFalse);
    });

    test('detects mixed project (Groovy settings + Kotlin app)', () {
      final androidDir = Directory('${tempDir.path}/android')..createSync();
      final appDir = Directory('${androidDir.path}/app')..createSync();

      File('${androidDir.path}/settings.gradle').writeAsStringSync("include ':app'");
      File('${appDir.path}/build.gradle.kts').writeAsStringSync('android {}');

      final result = GradleDslDetector.detectProjectDsl(androidDir.path);

      expect(result.settingsGradleDsl, GradleDsl.groovy);
      expect(result.appBuildGradleDsl, GradleDsl.kotlin);
      expect(result.isMixedProject, isTrue);
    });

    test('defaults to Groovy when files are missing', () {
      final androidDir = Directory('${tempDir.path}/android')..createSync();

      final result = GradleDslDetector.detectProjectDsl(androidDir.path);

      expect(result.settingsGradleDsl, GradleDsl.groovy);
      expect(result.appBuildGradleDsl, GradleDsl.groovy);
    });
  });
}
