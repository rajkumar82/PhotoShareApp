import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';
import 'sync.dart';

const _task = 'photoshare-backup';

/// Entry point Android runs in the background (even when the app is closed).
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((name, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final settings = await SyncSettings.load();
      if (!settings.auto || settings.albumIds.isEmpty) return true;
      final token = await const FlutterSecureStorage().read(key: 'photoshare_token');
      if (token == null) return true;
      await SyncService.run(Api(token: token), settings);
      return true;
    } catch (_) {
      return false; // Android tries again later
    }
  });
}

/// Turns the periodic backup on (with the user's Wi-Fi / charging choices) or off.
class BackgroundSync {
  static Future<void> init() => Workmanager().initialize(backgroundDispatcher);

  static Future<void> apply(SyncSettings s) async {
    if (!s.auto || s.albumIds.isEmpty) {
      await Workmanager().cancelByUniqueName(_task);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: s.wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresCharging: s.chargingOnly,
      ),
    );
  }
}
