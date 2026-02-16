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
  /// Uses multiple signals:
  /// 1. File extension (.gradle vs .gradle.kts)
  /// 2. File content analysis (plugins block, function syntax, etc.)
  static GradleDsl detectFileDsl(File gradleFile) {
    // First, check the file extension (most reliable)
    final dslFromExtension = _detectFromExtension(gradleFile);
    if (dslFromExtension != null) {
      return dslFromExtension;
    }

    // If .gradle file, analyze content
    try {
      final content = gradleFile.readAsStringSync();
      return _detectFromContent(content);
    } catch (e) {
      // If we can't read the file, default to Groovy
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

  /// Detects DSL from file extension
  ///
  /// Returns null if extension is ambiguous (e.g., .gradle file could be either)
  static GradleDsl? _detectFromExtension(File file) {
    if (file.path.endsWith('.gradle.kts')) {
      return GradleDsl.kotlin;
    }
    // .gradle files can contain either DSL, need content analysis
    return null;
  }

  /// Detects DSL from file content
  ///
  /// Uses heuristics to determine if a .gradle file uses Kotlin DSL syntax
  static GradleDsl _detectFromContent(String content) {
    // Check for Kotlin DSL indicators
    if (_hasKotlinDslIndicators(content)) {
      return GradleDsl.kotlin;
    }

    // Default to Groovy DSL
    return GradleDsl.groovy;
  }

  /// Checks if content has Kotlin DSL indicators
  static bool _hasKotlinDslIndicators(String content) {
    // Check for plugins {} block (Kotlin DSL feature)
    if (_hasPluginsBlock(content)) {
      return true;
    }

    // Check for function call syntax: include(":module")
    if (_hasFunctionCallSyntax(content)) {
      return true;
    }

    // Check for Kotlin-specific map syntax: mapOf(...)
    if (_hasKotlinMapSyntax(content)) {
      return true;
    }

    return false;
  }

  /// Checks for plugins {} block
  ///
  /// The plugins {} block is a Kotlin DSL feature, though it can appear
  /// in .gradle files when using modern Gradle versions
  static bool _hasPluginsBlock(String content) {
    // Look for "plugins {" pattern
    final pluginsRegex = RegExp(r'plugins\s*\{');
    return pluginsRegex.hasMatch(content);
  }

  /// Checks for function call syntax
  ///
  /// Kotlin DSL uses function calls: include(":app")
  /// Groovy DSL uses: include ':app' or include ":app"
  static bool _hasFunctionCallSyntax(String content) {
    // Look for include(...) pattern (Kotlin style)
    final functionCallRegex = RegExp(r'include\s*\(');
    return functionCallRegex.hasMatch(content);
  }

  /// Checks for Kotlin map syntax
  ///
  /// Kotlin DSL uses: mapOf("key" to "value")
  /// Groovy DSL uses: [key: "value"]
  static bool _hasKotlinMapSyntax(String content) {
    // Look for mapOf(...) pattern
    final mapOfRegex = RegExp(r'mapOf\s*\(');
    return mapOfRegex.hasMatch(content);
  }
}
