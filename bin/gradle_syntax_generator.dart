import 'gradle_dsl_detector.dart';

/// Generates Gradle syntax for both Groovy and Kotlin DSL
class GradleSyntaxGenerator {
  /// Generates the content for a module's build.gradle file
  ///
  /// Creates a simple build configuration that adds the AAR file
  /// as a default artifact.
  ///
  /// Example Groovy output:
  /// ```
  /// configurations.maybeCreate("default")
  /// artifacts.add("default", file('spotify-app-remote.aar'))
  /// ```
  ///
  /// Example Kotlin DSL output:
  /// ```
  /// configurations.maybeCreate("default")
  /// artifacts.add("default", file("spotify-app-remote.aar"))
  /// ```
  static String generateModuleBuildFile(String aarFileName, GradleDsl dsl) {
    final fileRef = dsl == GradleDsl.kotlin
        ? 'file("$aarFileName")' // Kotlin DSL uses double quotes
        : "file('$aarFileName')"; // Groovy DSL uses single quotes

    return '''
configurations.maybeCreate("default")
artifacts.add("default", $fileRef)
''';
  }

  /// Generates an include statement for settings.gradle
  ///
  /// Groovy DSL: `include ':module-name'`
  /// Kotlin DSL: `include(":module-name")`
  static String generateIncludeStatement(String moduleName, GradleDsl dsl) {
    if (dsl == GradleDsl.kotlin) {
      return 'include(":$moduleName")';
    } else {
      return "include ':$moduleName'";
    }
  }

  /// Generates manifestPlaceholders line for build.gradle
  ///
  /// Groovy DSL: `manifestPlaceholders = [key: "value", ...]`
  /// Kotlin DSL: `manifestPlaceholders.putAll(mapOf("key" to "value", ...))`
  ///
  /// Note: In Kotlin DSL, manifestPlaceholders is a pre-initialized
  /// `MutableMap<String, Any>` (val), so it cannot be reassigned with =.
  /// Instead, putAll() is used to populate it.
  static String generateManifestPlaceholders(
    Map<String, String> placeholders,
    GradleDsl dsl,
  ) {
    final mapContent = _formatMap(placeholders, dsl);
    if (dsl == GradleDsl.kotlin) {
      return 'manifestPlaceholders.putAll($mapContent)';
    }
    return 'manifestPlaceholders = $mapContent';
  }

  /// Returns the appropriate file extension for the DSL
  ///
  /// Groovy DSL: `.gradle`
  /// Kotlin DSL: `.gradle.kts`
  static String getFileExtension(GradleDsl dsl) {
    return dsl == GradleDsl.kotlin ? '.gradle.kts' : '.gradle';
  }

  /// Formats a map literal according to DSL syntax
  ///
  /// Groovy DSL: `[key1: "value1", key2: "value2"]`
  /// Kotlin DSL: `mapOf("key1" to "value1", "key2" to "value2")`
  static String _formatMap(Map<String, String> map, GradleDsl dsl) {
    if (dsl == GradleDsl.kotlin) {
      // Kotlin DSL: mapOf("key" to "value", ...)
      final entries = map.entries
          .map((e) => '"${e.key}" to "${e.value}"')
          .join(', ');
      return 'mapOf($entries)';
    } else {
      // Groovy DSL: [key: "value", ...]
      final entries = map.entries
          .map((e) => '${e.key}: "${e.value}"')
          .join(', ');
      return '[$entries]';
    }
  }
}
