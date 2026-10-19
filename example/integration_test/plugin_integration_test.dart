// Runs against the real Kotlin/Swift code on a device or simulator:
//   cd example && flutter test integration_test
//
// Outside the store (a debug build) there is no update to find, so this checks
// that the native side answers with well-formed data or a clean error.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_update/in_app_update.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkForUpdate answers', (tester) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      expect(info.updateAvailability, isNot(UpdateAvailability.unsupported));
    } on InAppUpdateException catch (e) {
      // Android: "app is not owned by any user" when not installed from Play.
      expect(e.code, InAppUpdateException.checkFailed);
    }
  });

  testWidgets('completeUpdate without a download fails cleanly', (
    tester,
  ) async {
    try {
      await InAppUpdate.completeUpdate();
    } on InAppUpdateException catch (e) {
      expect(e.code, InAppUpdateException.completeFailed);
    }
  });
}
