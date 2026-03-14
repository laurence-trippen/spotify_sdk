import 'dart:io';

import 'android_setup.dart';
import 'gradle_file_handler.dart';

/// Checks if all preconditions are met to execute the script.
/// Returns true if all preconditions are met, false otherwise.
class PreconditionChecker {
  static bool setupConditionsMet() {
    // check if the script is executed on a supported platform
    if (!Platform.isMacOS && !Platform.isLinux) {
      logger.w(
          'Warning: This script has not been tested on your platform (${Platform.operatingSystem}).');
    }

    // check if flutter is installed
    if (!(Platform.environment['PATH']?.contains("flutter") ?? false) &&
        Platform.environment['FLUTTER_ROOT'] == null) {
      logger.e('Error: Flutter is not installed or not in your PATH.');
      return false;
    }

    // check if the script is executed from inside a flutter project
    if (!File('pubspec.yaml').existsSync()) {
      logger.e(
          'Error: The script must be executed from inside a flutter project.');
      return false;
    }

    // check if the necessary android files exist (both .gradle and .gradle.kts)
    if (!GradleFileHandler.gradleFileExists('android/app', 'build.gradle')) {
      logger.e('Error: The file "android/app/build.gradle" does not exist.');
      return false;
    }

    // check if the setup may have already been executed and recommend to run the cleanup script
    bool prevRun = Directory('android/$moduleName').existsSync() ||
        GradleFileHandler.gradleFileExists('android/$moduleName', 'build.gradle');
    if (!prevRun && GradleFileHandler.gradleFileExists('android', 'settings.gradle')) {
      final (_, settingsContent) = GradleFileHandler.readGradleFile(
        'android',
        'settings.gradle',
      );
      // Check for both Groovy and Kotlin DSL include statements
      prevRun |= settingsContent.contains("include ':$moduleName'");
      prevRun |= settingsContent.contains('include ":$moduleName"');
      prevRun |= settingsContent.contains('include(":$moduleName")');
    }

    if (prevRun) {
      logger.w('Warning: The setup may have already been executed. '
          'Please run dart run spotify_sdk:android_setup --cleanup before running this script again.');
      return false;
    }

    return true;
  }
}
