import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/api.dart';
import '../services/background.dart';
import '../services/sync.dart';
import '../theme.dart';

/// Choose which phone folders are backed up to the library, whether that happens by itself, and run it now.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.api, required this.onDone});
  final Api api;
  final VoidCallback onDone; // refresh the library after a run

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  SyncSettings _s = SyncSettings();
  List<AssetPathEntity>? _folders;
  bool _noAccess = false;
  bool _running = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SyncSettings.load();
    final folders = await SyncService.folders();
    if (!mounted) return;
    setState(() {
      _s = s;
      _folders = folders;
      _noAccess = folders.isEmpty;
    });
  }

  Future<void> _change(SyncSettings next) async {
    setState(() => _s = next);
    await next.save();
    await BackgroundSync.apply(next);
  }

  Future<void> _runNow() async {
    setState(() {
      _running = true;
      _status = 'Starting...';
    });
    try {
      final r = await SyncService.run(widget.api, _s, onStatus: (t) => mounted ? setState(() => _status = t) : null);
      if (mounted) setState(() => _status = r.summary);
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _status = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _freeUp() async {
    setState(() {
      _running = true;
      _status = 'Checking what is safely backed up...';
    });
    try {
      final plan = await SyncService.freeUpPlan(widget.api, _s, onStatus: (t) => mounted ? setState(() => _status = t) : null);
      if (!mounted) return;
      setState(() => _status = null);
      if (plan.photos.isEmpty) {
        setState(() => _status = 'Nothing to free up yet. Only photos older than 30 days that the server has confirmed are offered.');
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Free up ${plan.size}?'),
          content: Text(
            '${plan.photos.length} photos older than 30 days are safely in your PhotoShare library (the server confirmed each exact file just now).\n\n'
            "They will move to your phone's Trash, where Android keeps them for about 30 days. Android will ask you to confirm.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move to Trash')),
          ],
        ),
      );
      if (go != true) return;
      final n = await SyncService.removeFromPhone(plan.photos);
      if (mounted) setState(() => _status = n > 0 ? 'Moved $n photos to Trash.' : 'Nothing was removed.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (_) {
      if (mounted) setState(() => _status = 'Something went wrong. Nothing was removed.');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final folders = _folders;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.barGrad)),
        title: const Text('Back up photos'),
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Photos in the folders you tick are copied to your PhotoShare library exactly as they are (full quality). '
            'They stay private to you until you post one to your feed.',
            style: TextStyle(color: c.muted),
          ),
        ),
        SwitchListTile(
          title: const Text('Back up automatically'),
          subtitle: const Text('Checks every few hours in the background'),
          value: _s.auto,
          onChanged: _s.albumIds.isEmpty ? null : (v) => _change(_s.copy(auto: v)),
        ),
        SwitchListTile(
          title: const Text('Only on Wi-Fi'),
          value: _s.wifiOnly,
          onChanged: (v) => _change(_s.copy(wifiOnly: v)),
        ),
        SwitchListTile(
          title: const Text('Only while charging'),
          value: _s.chargingOnly,
          onChanged: (v) => _change(_s.copy(chargingOnly: v)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _running || _s.albumIds.isEmpty ? null : _runNow,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Back up now'),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _running || _s.albumIds.isEmpty ? null : _freeUp,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Free up space'),
          ),
        ),
        if (_running) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: LinearProgressIndicator()),
        if (_status != null || _s.lastNote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_status ?? 'Last run: ${_s.lastNote}', style: TextStyle(color: c.muted)),
          ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text('Folders', style: TextStyle(fontWeight: FontWeight.w700))),
        if (folders == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_noAccess)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Allow PhotoShare to see your photos to choose folders.', style: TextStyle(color: c.muted)),
              TextButton(onPressed: PhotoManager.openSetting, child: const Text('Open settings')),
            ]),
          )
        else
          for (final f in folders)
            FutureBuilder<int>(
              future: f.assetCountAsync,
              builder: (_, snap) => CheckboxListTile(
                title: Text(f.name),
                subtitle: snap.hasData ? Text('${snap.data} photos') : null,
                value: _s.albumIds.contains(f.id),
                onChanged: (v) {
                  final ids = {..._s.albumIds};
                  v == true ? ids.add(f.id) : ids.remove(f.id);
                  _change(_s.copy(albumIds: ids, auto: ids.isEmpty ? false : _s.auto));
                },
              ),
            ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
