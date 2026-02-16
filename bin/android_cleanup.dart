import 'dart:io';

import 'android_setup.dart';
import 'gradle_dsl_detector.dart';
import 'gradle_file_handler.dart';
import 'gradle_syntax_generator.dart';

/// Removes all changes made by the [android_setup] script.
Future<void> main(List<String> args) async {
  logger.i('running android_cleanup script');

  // detect DSL before cleanup
  final dslResult = GradleDslDetector.detectProjectDsl('android');

  // remove the module directory if it exists
  final moduleDir = Directory('android/$moduleName');
  if (moduleDir.existsSync()) {
    await moduleDir.delete(recursive: true);
    logger.t('deleted directory ${moduleDir.path}');
  }

  // remove the include statement from settings.gradle
  if (GradleFileHandler.gradleFileExists('android', 'settings.gradle')) {
    final (settingsFile, settingsContent) = GradleFileHandler.readGradleFile(
      'android',
      'settings.gradle',
    );

    final settingsDsl = dslResult.settingsGradleDsl;
    final includeStatements = [
      GradleSyntaxGenerator.generateIncludeStatement(moduleName, settingsDsl),
      // Also try the other DSL format for robustness
      GradleSyntaxGenerator.generateIncludeStatement(
        moduleName,
        settingsDsl == GradleDsl.kotlin ? GradleDsl.groovy : GradleDsl.kotlin,
      ),
    ];

    if (includeStatements.any((stmt) => settingsContent.contains(stmt))) {
      var newContent = settingsContent;
      for (final stmt in includeStatements) {
        newContent = newContent.replaceAll(stmt, '');
      }
      // Clean up double newlines
      newContent = newContent.replaceAll('\n\n\n', '\n\n');

      await settingsFile.writeAsString(newContent);
      logger.t('removed include statement from settings.gradle');
    }
  }

  // remove the manifestPlaceholder from app/build.gradle
  if (GradleFileHandler.gradleFileExists('android/app', 'build.gradle')) {
    final (appBuildFile, appBuildContent) = GradleFileHandler.readGradleFile(
      'android/app',
      'build.gradle',
    );

    if (appBuildContent.contains('manifestPlaceholders')) {
      final newContent = appBuildContent
          .split('\n')
          .where((line) => !line.contains('manifestPlaceholders'))
          .join('\n');

      await appBuildFile.writeAsString(newContent);
      logger.t('removed manifestPlaceholders from app/build.gradle');
    }
  }
}
