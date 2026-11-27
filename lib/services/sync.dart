import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// What the user chose for backing up: which camera folders, and when.
class SyncSettings {
  SyncSettings({this.albumIds = const {}, this.auto = false, this.wifiOnly = true, this.chargingOnly = false, this.lastRun, this.lastNote});
  final Set<String> albumIds;
  final bool auto, wifiOnly, chargingOnly;
  final DateTime? lastRun;
  final String? lastNote;

  SyncSettings copy({Set<String>? albumIds, bool? auto, bool? wifiOnly, bool? chargingOnly}) => SyncSettings(
        albumIds: albumIds ?? this.albumIds,
        auto: auto ?? this.auto,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        chargingOnly: chargingOnly ?? this.chargingOnly,
        lastRun: lastRun,
        lastNote: lastNote,
      );

  static Future<SyncSettings> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // the background job writes too
    final last = p.getInt('sync_last_run');
    return SyncSettings(
      albumIds: (p.getStringList('sync_albums') ?? const []).toSet(),
      auto: p.getBool('sync_auto') ?? false,
      wifiOnly: p.getBool('sync_wifi_only') ?? true,
      chargingOnly: p.getBool('sync_charging_only') ?? false,
      lastRun: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      lastNote: p.getString('sync_last_note'),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('sync_albums', albumIds.toList());
    await p.setBool('sync_auto', auto);
    await p.setBool('sync_wifi_only', wifiOnly);
    await p.setBool('sync_charging_only', chargingOnly);
  }
}

class SyncResult {
  SyncResult({this.uploaded = 0, this.alreadyThere = 0, this.failed = 0, this.note});
  int uploaded, alreadyThere, failed;
  String? note;

  String get summary {
    if (note != null) return note!;
    final parts = [
      if (uploaded > 0) '$uploaded backed up',
      if (alreadyThere > 0) '$alreadyThere already there',
      if (failed > 0) '$failed failed',
    ];
    return parts.isEmpty ? 'Everything is already backed up.' : '${parts.join(', ')}.';
  }
}

/// Backs up the photos in the chosen folders: finds ones this phone has not finished yet, asks the server which it already
/// holds (by the file's SHA-256), and uploads only the rest, as the original files. Safe to run again at any time, and from
/// the background: a photo is only remembered as done once the server has confirmed it holds the exact bytes.
class SyncService {
  static const _doneKey = 'sync_done_assets';
  static const _batch = 20;

  static Future<List<AssetPathEntity>> folders() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) return [];
    final list = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: false);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<String> _sha(File f) async => (await sha256.bind(f.openRead()).first).toString();

  static Future<SyncResult> run(Api api, SyncSettings settings, {void Function(String status)? onStatus}) async {
    final result = SyncResult();
    if (settings.albumIds.isEmpty) return SyncResult(note: 'Choose at least one folder first.');
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) return SyncResult(note: 'Allow access to your photos to back them up.');

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final done = (prefs.getStringList(_doneKey) ?? const []).toSet();

    final albums = [for (final a in await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: false)) if (settings.albumIds.contains(a.id)) a];
    final todo = <AssetEntity>[];
    final seen = <String>{};
    for (final album in albums) {
      final total = await album.assetCountAsync;
      for (var page = 0; page * 200 < total; page++) {
        for (final a in await album.getAssetListPaged(page: page, size: 200)) {
          if (!done.contains(a.id) && seen.add(a.id)) todo.add(a);
        }
      }
    }
    todo.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    SyncResult stopped(ApiException e) =>
        SyncResult(uploaded: result.uploaded, alreadyThere: result.alreadyThere, failed: result.failed, note: _stopNote(e, result));

    for (var i = 0; i < todo.length; i += _batch) {
      final chunk = todo.sublist(i, i + _batch > todo.length ? todo.length : i + _batch);
      onStatus?.call('Checking ${i + 1}-${i + chunk.length} of ${todo.length}...');
      final files = <AssetEntity, File>{};
      final hashes = <AssetEntity, String>{};
      for (final a in chunk) {
        try {
          final f = await a.originFile;
          if (f == null) {
            result.failed++;
            continue;
          }
          files[a] = f;
          hashes[a] = await _sha(f);
        } catch (_) {
          result.failed++;
        }
      }
      if (hashes.isEmpty) continue;
      final Set<String> stored;
      try {
        stored = await api.libraryStored(hashes.values.toSet().toList());
      } on ApiException catch (e) {
        await _remember(prefs, done);
        return stopped(e);
      }
      for (final a in hashes.keys) {
        final hash = hashes[a]!;
        if (stored.contains(hash)) {
          result.alreadyThere++;
          done.add(a.id);
          continue;
        }
        onStatus?.call('Backing up ${result.uploaded + 1}...');
        try {
          await api.uploadToLibrary(files[a]!, hash: hash, takenAt: a.createDateTime, name: await _name(a, files[a]!));
          result.uploaded++;
          done.add(a.id);
        } on ApiException catch (e) {
          if (e.status == 401 || e.status == null) {
            await _remember(prefs, done);
            return stopped(e);
          }
          result.failed++; // e.g. a file the server refuses; it is tried again next time
        }
      }
      await _remember(prefs, done);
    }
    await prefs.setInt('sync_last_run', DateTime.now().millisecondsSinceEpoch);
    await prefs.setString('sync_last_note', result.summary);
    return result;
  }

  static Future<String> _name(AssetEntity a, File f) async {
    final t = await a.titleAsync;
    return t.isNotEmpty ? t : f.path.split(RegExp(r'[\\/]')).last;
  }

  static String _stopNote(ApiException e, SyncResult r) =>
      e.status == 401 ? 'Please open PhotoShare and sign in again.' : 'Stopped: ${e.message} (${r.uploaded} backed up so far.)';

  static Future<void> _remember(SharedPreferences p, Set<String> done) => p.setStringList(_doneKey, done.toList());
}
