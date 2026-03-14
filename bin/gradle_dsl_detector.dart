import 'dart:io';

/// Represents the two main Gradle DSL types
enum GradleDsl { groovy, kotlin }

/// Result of DSL detection for a project
class DslDetectionResult {
  final GradleDsl settingsGradleDsl;
  final GradleDsl appBuildGradleDsl;
  final bool isMixedProject;

  DslDetectionResult({
    required this.settingsGradleDsl,
    required this.appBuildGradleDsl,
  }) : isMixedProject = settingsGradleDsl != appBuildGradleDsl;

  @override
  String toString() {
    return 'DslDetectionResult(settings: $settingsGradleDsl, '
        'appBuild: $appBuildGradleDsl, mixed: $isMixedProject)';
  }
}

/// Detects which Gradle DSL (Groovy or Kotlin) is used in Android projects
class GradleDslDetector {
  /// Detects the DSL used in the entire Android project
  ///
  /// Checks both settings.gradle and app/build.gradle files
  /// to determine which DSL is in use. Supports mixed projects
  /// where different files use different DSLs.
  ///
  /// [androidPath] is the path to the android directory (typically 'android')
  static DslDetectionResult detectProjectDsl(String androidPath) {
    // Detect settings.gradle DSL
    final settingsFile = findGradleFile(androidPath, 'settings.gradle');
    final settingsDsl = settingsFile != null
        ? detectFileDsl(settingsFile)
        : GradleDsl.groovy; // Default fallback

    // Detect app/build.gradle DSL
    final appBuildFile = findGradleFile('$androidPath/app', 'build.gradle');
    final appBuildDsl = appBuildFile != null
        ? detectFileDsl(appBuildFile)
        : GradleDsl.groovy; // Default fallback

    return DslDetectionResult(
      settingsGradleDsl: settingsDsl,
      appBuildGradleDsl: appBuildDsl,
    );
  }

  /// Detects the DSL used in a single Gradle file
  ///
  /// Uses file extension as the primary and only reliable indicator:
  /// - .gradle.kts → Kotlin DSL
  /// - .gradle → Groovy DSL
  ///
  /// Note: The plugins {} block is NOT a reliable indicator of Kotlin DSL,
  /// as it's also available in modern Groovy DSL projects.
  static GradleDsl detectFileDsl(File gradleFile) {
    // File extension is the ONLY reliable way to determine DSL
    if (gradleFile.path.endsWith('.gradle.kts')) {
      return GradleDsl.kotlin;
    } else {
      // All .gradle files use Groovy DSL, regardless of their content
      return GradleDsl.groovy;
    }
  }

  /// Finds a Gradle file with either .gradle or .gradle.kts extension
  ///
  /// Returns the file with .gradle.kts if both exist (Kotlin DSL is explicit)
  static File? findGradleFile(String basePath, String fileName) {
    // Remove .gradle extension if provided
    final baseFileName = fileName.replaceAll('.gradle', '');

    // Check for .gradle.kts first (explicit Kotlin DSL)
    final kotlinFile = File('$basePath/$baseFileName.gradle.kts');
    if (kotlinFile.existsSync()) {
      return kotlinFile;
    }

    // Check for .gradle file
    final groovyFile = File('$basePath/$baseFileName.gradle');
    if (groovyFile.existsSync()) {
      return groovyFile;
    }

    return null;
  }

}
