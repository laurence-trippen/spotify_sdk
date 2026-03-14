import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../bin/gradle_dsl_detector.dart';
import '../../bin/gradle_file_handler.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gradle_file_handler_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('GradleFileHandler.gradleFileExists', () {
    test('returns true for existing .gradle file', () {
      File('${tempDir.path}/build.gradle').writeAsStringSync('');

      expect(
        GradleFileHandler.gradleFileExists(tempDir.path, 'build.gradle'),
        isTrue,
      );
    });

    test('returns true for existing .gradle.kts file', () {
      File('${tempDir.path}/build.gradle.kts').writeAsStringSync('');

      expect(
        GradleFileHandler.gradleFileExists(tempDir.path, 'build.gradle'),
        isTrue,
      );
    });

    test('returns false when no gradle file exists', () {
      expect(
        GradleFileHandler.gradleFileExists(tempDir.path, 'build.gradle'),
        isFalse,
      );
    });
  });

  group('GradleFileHandler.readGradleFile', () {
    test('reads content from .gradle file', () {
      const content = "include ':app'";
      File('${tempDir.path}/settings.gradle').writeAsStringSync(content);

      final (file, readContent) = GradleFileHandler.readGradleFile(
        tempDir.path,
        'settings.gradle',
      );

      expect(readContent, equals(content));
      expect(file.path, endsWith('.gradle'));
    });

    test('reads content from .gradle.kts file', () {
      const content = 'include(":app")';
      File('${tempDir.path}/settings.gradle.kts').writeAsStringSync(content);

      final (file, readContent) = GradleFileHandler.readGradleFile(
        tempDir.path,
        'settings.gradle',
      );

      expect(readContent, equals(content));
      expect(file.path, endsWith('.gradle.kts'));
    });

    test('throws FileSystemException when file does not exist', () {
      expect(
        () => GradleFileHandler.readGradleFile(tempDir.path, 'missing.gradle'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('prefers .gradle.kts when both files exist', () {
      File('${tempDir.path}/settings.gradle').writeAsStringSync('groovy content');
      File('${tempDir.path}/settings.gradle.kts').writeAsStringSync('kotlin content');

      final (_, content) = GradleFileHandler.readGradleFile(
        tempDir.path,
        'settings.gradle',
      );

      expect(content, equals('kotlin content'));
    });
  });

  group('GradleFileHandler.containsIncludeStatement', () {
    test('detects Groovy include in Groovy project', () {
      const content = "include ':app'\ninclude ':spotify-app-remote'";

      expect(
        GradleFileHandler.containsIncludeStatement(
          content,
          'spotify-app-remote',
          GradleDsl.groovy,
        ),
        isTrue,
      );
    });

    test('detects Kotlin include in Kotlin project', () {
      const content = 'include(":app")\ninclude(":spotify-app-remote")';

      expect(
        GradleFileHandler.containsIncludeStatement(
          content,
          'spotify-app-remote',
          GradleDsl.kotlin,
        ),
        isTrue,
      );
    });

    test('also detects Kotlin include when checking in Groovy mode (robustness)', () {
      // If a Groovy project already has Kotlin-style include from a previous run,
      // containsIncludeStatement should still detect it
      const content = 'include(":app")\ninclude(":spotify-app-remote")';

      expect(
        GradleFileHandler.containsIncludeStatement(
          content,
          'spotify-app-remote',
          GradleDsl.groovy, // Checking in Groovy mode
        ),
        isTrue,
      );
    });

    test('returns false when module is not included', () {
      const content = "include ':app'";

      expect(
        GradleFileHandler.containsIncludeStatement(
          content,
          'spotify-app-remote',
          GradleDsl.groovy,
        ),
        isFalse,
      );
    });
  });

  group('GradleFileHandler.insertIncludeStatement', () {
    test('inserts Groovy include after app include (single-quoted)', () {
      const content = "include ':app'";
      const moduleName = 'spotify-app-remote';

      final result = GradleFileHandler.insertIncludeStatement(
        content,
        moduleName,
        GradleDsl.groovy,
      );

      expect(result, contains("include ':app'"));
      expect(result, contains("include ':$moduleName'"));
      // Module include should appear after app include
      expect(
        result.indexOf("include ':$moduleName'"),
        greaterThan(result.indexOf("include ':app'")),
      );
    });

    test('inserts Groovy include after app include (double-quoted)', () {
      const content = 'include ":app"';
      const moduleName = 'spotify-app-remote';

      final result = GradleFileHandler.insertIncludeStatement(
        content,
        moduleName,
        GradleDsl.groovy,
      );

      expect(result, contains("include ':$moduleName'"));
    });

    test('inserts Kotlin include after app include', () {
      const content = 'include(":app")';
      const moduleName = 'spotify-app-remote';

      final result = GradleFileHandler.insertIncludeStatement(
        content,
        moduleName,
        GradleDsl.kotlin,
      );

      expect(result, contains('include(":app")'));
      expect(result, contains('include(":$moduleName")'));
    });

    test('appends to end when no app include found', () {
      const content = 'rootProject.name = "my-project"';
      const moduleName = 'spotify-app-remote';

      final result = GradleFileHandler.insertIncludeStatement(
        content,
        moduleName,
        GradleDsl.groovy,
      );

      expect(result, endsWith("include ':$moduleName'\n"));
    });

    test('preserves existing content', () {
      const content = '''
pluginManagement {
    repositories {
        google()
    }
}

include ':app'
''';
      final result = GradleFileHandler.insertIncludeStatement(
        content,
        'spotify-app-remote',
        GradleDsl.groovy,
      );

      expect(result, contains('pluginManagement'));
      expect(result, contains("include ':app'"));
      expect(result, contains("include ':spotify-app-remote'"));
    });
  });

  group('GradleFileHandler.writeGradleFile', () {
    test('writes .gradle file for Groovy DSL', () async {
      const content = 'configurations.maybeCreate("default")';

      await GradleFileHandler.writeGradleFile(
        tempDir.path,
        'build.gradle',
        content,
        GradleDsl.groovy,
      );

      final written = File('${tempDir.path}/build.gradle');
      expect(written.existsSync(), isTrue);
      expect(written.readAsStringSync(), equals(content));
    });

    test('writes .gradle.kts file for Kotlin DSL', () async {
      const content = 'configurations.maybeCreate("default")';

      await GradleFileHandler.writeGradleFile(
        tempDir.path,
        'build.gradle',
        content,
        GradleDsl.kotlin,
      );

      final written = File('${tempDir.path}/build.gradle.kts');
      expect(written.existsSync(), isTrue);
      expect(written.readAsStringSync(), equals(content));
    });
  });
}
