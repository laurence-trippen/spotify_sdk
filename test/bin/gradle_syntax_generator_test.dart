import 'package:flutter_test/flutter_test.dart';

import '../../bin/gradle_dsl_detector.dart';
import '../../bin/gradle_syntax_generator.dart';

void main() {
  group('GradleSyntaxGenerator.generateModuleBuildFile', () {
    const aarFileName = 'spotify-app-remote-release-0.8.0.aar';

    test('Groovy DSL uses single quotes for file reference', () {
      final content = GradleSyntaxGenerator.generateModuleBuildFile(
        aarFileName,
        GradleDsl.groovy,
      );

      expect(content, contains("file('$aarFileName')"));
      expect(content, contains('configurations.maybeCreate("default")'));
      expect(content, contains('artifacts.add("default"'));
    });

    test('Kotlin DSL uses double quotes for file reference', () {
      final content = GradleSyntaxGenerator.generateModuleBuildFile(
        aarFileName,
        GradleDsl.kotlin,
      );

      expect(content, contains('file("$aarFileName")'));
      expect(content, contains('configurations.maybeCreate("default")'));
      expect(content, contains('artifacts.add("default"'));
    });

    test('Groovy output does not contain double-quoted file reference', () {
      final content = GradleSyntaxGenerator.generateModuleBuildFile(
        aarFileName,
        GradleDsl.groovy,
      );
      expect(content, isNot(contains('file("$aarFileName")')));
    });

    test('Kotlin output does not contain single-quoted file reference', () {
      final content = GradleSyntaxGenerator.generateModuleBuildFile(
        aarFileName,
        GradleDsl.kotlin,
      );
      expect(content, isNot(contains("file('$aarFileName')")));
    });
  });

  group('GradleSyntaxGenerator.generateIncludeStatement', () {
    const moduleName = 'spotify-app-remote';

    test('Groovy DSL generates single-quoted include', () {
      final statement = GradleSyntaxGenerator.generateIncludeStatement(
        moduleName,
        GradleDsl.groovy,
      );
      expect(statement, equals("include ':$moduleName'"));
    });

    test('Kotlin DSL generates function call include', () {
      final statement = GradleSyntaxGenerator.generateIncludeStatement(
        moduleName,
        GradleDsl.kotlin,
      );
      expect(statement, equals('include(":$moduleName")'));
    });

    test('Groovy include does not use function call syntax', () {
      final statement = GradleSyntaxGenerator.generateIncludeStatement(
        moduleName,
        GradleDsl.groovy,
      );
      expect(statement, isNot(contains('(')));
    });

    test('Kotlin include does not use single quotes', () {
      final statement = GradleSyntaxGenerator.generateIncludeStatement(
        moduleName,
        GradleDsl.kotlin,
      );
      expect(statement, isNot(contains("'")));
    });
  });

  group('GradleSyntaxGenerator.generateManifestPlaceholders', () {
    final placeholders = {
      'redirectSchemeName': 'spotify-sdk',
      'redirectHostName': 'auth',
    };

    test('Groovy DSL generates map literal syntax', () {
      final result = GradleSyntaxGenerator.generateManifestPlaceholders(
        placeholders,
        GradleDsl.groovy,
      );

      expect(result, startsWith('manifestPlaceholders = ['));
      expect(result, contains('redirectSchemeName: "spotify-sdk"'));
      expect(result, contains('redirectHostName: "auth"'));
    });

    test('Kotlin DSL generates mapOf() syntax', () {
      final result = GradleSyntaxGenerator.generateManifestPlaceholders(
        placeholders,
        GradleDsl.kotlin,
      );

      expect(result, startsWith('manifestPlaceholders = mapOf('));
      expect(result, contains('"redirectSchemeName" to "spotify-sdk"'));
      expect(result, contains('"redirectHostName" to "auth"'));
    });

    test('Groovy output does not contain mapOf', () {
      final result = GradleSyntaxGenerator.generateManifestPlaceholders(
        placeholders,
        GradleDsl.groovy,
      );
      expect(result, isNot(contains('mapOf')));
    });

    test('Kotlin output does not use map literal syntax', () {
      final result = GradleSyntaxGenerator.generateManifestPlaceholders(
        placeholders,
        GradleDsl.kotlin,
      );
      // Should not have Groovy-style "key: value" (without quotes around key)
      expect(result, isNot(contains('redirectSchemeName: ')));
    });

    test('works with empty placeholder map', () {
      final result = GradleSyntaxGenerator.generateManifestPlaceholders(
        {},
        GradleDsl.groovy,
      );
      expect(result, equals('manifestPlaceholders = []'));
    });
  });

  group('GradleSyntaxGenerator.getFileExtension', () {
    test('Groovy DSL returns .gradle', () {
      expect(GradleSyntaxGenerator.getFileExtension(GradleDsl.groovy), equals('.gradle'));
    });

    test('Kotlin DSL returns .gradle.kts', () {
      expect(GradleSyntaxGenerator.getFileExtension(GradleDsl.kotlin), equals('.gradle.kts'));
    });
  });
}
