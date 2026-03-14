import 'dart:io';

import 'gradle_dsl_detector.dart';
import 'gradle_syntax_generator.dart';

/// Handles reading and writing Gradle files with DSL awareness
class GradleFileHandler {
  /// Reads a Gradle file (either .gradle or .gradle.kts)
  ///
  /// Returns a tuple of (File, String content).
  /// Automatically detects and uses the correct file extension.
  ///
  /// [basePath] is the directory containing the gradle file
  /// [fileName] is the base name without extension (e.g., 'settings.gradle')
  ///
  /// Throws if the file doesn't exist.
  static (File, String) readGradleFile(String basePath, String fileName) {
    final file = GradleDslDetector.findGradleFile(basePath, fileName);

    if (file == null) {
      throw FileSystemException(
        'Gradle file not found: $basePath/$fileName',
      );
    }

    final content = file.readAsStringSync();
    return (file, content);
  }

  /// Writes content to a Gradle file with the appropriate extension
  ///
  /// [basePath] is the directory to write to
  /// [fileName] is the base name without extension
  /// [content] is the file content to write
  /// [dsl] determines the file extension (.gradle or .gradle.kts)
  static Future<void> writeGradleFile(
    String basePath,
    String fileName,
    String content,
    GradleDsl dsl,
  ) async {
    final baseFileName = fileName.replaceAll('.gradle', '');
    final extension = GradleSyntaxGenerator.getFileExtension(dsl);
    final file = File('$basePath/$baseFileName$extension');

    await file.writeAsString(content);
  }

  /// Checks if a Gradle file exists (either .gradle or .gradle.kts)
  ///
  /// Returns true if either extension exists
  static bool gradleFileExists(String basePath, String fileName) {
    final file = GradleDslDetector.findGradleFile(basePath, fileName);
    return file != null;
  }

  /// Checks if content contains an include statement for the module
  ///
  /// Checks both DSL formats to be thorough
  static bool containsIncludeStatement(
    String content,
    String moduleName,
    GradleDsl dsl,
  ) {
    final includeStatement =
        GradleSyntaxGenerator.generateIncludeStatement(moduleName, dsl);

    // Also check the other DSL format for robustness
    final otherDsl =
        dsl == GradleDsl.kotlin ? GradleDsl.groovy : GradleDsl.kotlin;
    final otherIncludeStatement =
        GradleSyntaxGenerator.generateIncludeStatement(moduleName, otherDsl);

    return content.contains(includeStatement) ||
        content.contains(otherIncludeStatement);
  }

  /// Inserts an include statement into settings.gradle content
  ///
  /// Tries to insert after the app include statement if found,
  /// otherwise appends to the end of the file.
  static String insertIncludeStatement(
    String content,
    String moduleName,
    GradleDsl dsl,
  ) {
    final includeStatement =
        GradleSyntaxGenerator.generateIncludeStatement(moduleName, dsl);

    // Try to insert after the app include statement
    // Check for both quote styles and DSL formats
    final patterns = [
      "include ':app'",
      'include ":app"',
      'include(":app")',
    ];

    for (final pattern in patterns) {
      if (content.contains(pattern)) {
        return content.replaceFirst(
          pattern,
          '$pattern\n$includeStatement',
        );
      }
    }

    // If no app include found, append to the end
    final trimmed = content.trimRight();
    return '$trimmed\n$includeStatement\n';
  }
}
