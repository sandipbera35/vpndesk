import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'l10n.dart';
import 'bridges.dart';
import 'installed_apps.dart';
import 'leak_test.dart';

const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _red = Color(0xFFFF6B6B);

/// Small rounded action chip used in the tools row.
class ToolPill extends StatelessWidget {
  const ToolPill({super.key, required this.icon, required this.label, this.onTap, this.tooltip, this.active = false, this.busy = false});
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active, busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final color = active ? _teal : Colors.white70;
    return Tooltip(
      message: L10n.tr(tooltip ?? label),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: onTap == null ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active ? _teal.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: active ? _teal : Colors.white24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                busy
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label, maxLines: 1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-rotate picker: minutes (0 = off).
class RotatePill extends StatelessWidget {
  const RotatePill({super.key, required this.minutes, required this.enabled, required this.onChanged});
  final int minutes;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: L10n.tr('Get a new exit relay automatically'),
        enabled: enabled,
        color: const Color(0xFF16233A),
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final m in const [0, 5, 10, 30, 60])
            PopupMenuItem(value: m, child: Row(children: [
              Icon(m == minutes ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: m == minutes ? _teal : Colors.white38),
              const SizedBox(width: 8),
              Text(m == 0 ? 'Off' : 'Every $m min'),
            ])),
        ],
        child: IgnorePointer(
          child: ToolPill(icon: Icons.autorenew_rounded, label: minutes == 0 ? 'Auto-rotate: off' : 'Rotate every $minutes min', active: minutes > 0, onTap: enabled ? () {} : null),
        ),
      );
}

/// Runs [run] and shows each check with a coloured verdict.
Future<void> showLeakTest(BuildContext context, Future<List<LeakCheck>> Function() run) =>
    showDialog<void>(context: context, builder: (_) => _LeakDialog(run: run));

class _LeakDialog extends StatefulWidget {
  const _LeakDialog({required this.run});
  final Future<List<LeakCheck>> Function() run;
  @override
  State<_LeakDialog> createState() => _LeakDialogState();
}

class _LeakDialogState extends State<_LeakDialog> {
  List<LeakCheck>? _res;
  String? _err;

  @override
  void initState() {
    super.initState();
    widget.run().then((r) { if (mounted) setState(() => _res = r); }, onError: (Object e) { if (mounted) setState(() => _err = '$e'); });
  }

  static (IconData, Color) _look(LeakLevel l) => switch (l) {
        LeakLevel.ok => (Icons.check_circle_rounded, _teal),
        LeakLevel.warn => (Icons.info_rounded, _amber),
        LeakLevel.fail => (Icons.cancel_rounded, _red),
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF111B2E),
        title: const Text('Leak test'),
        content: SizedBox(
          width: 460,
          child: _err != null
              ? Text('The test could not run: $_err')
              : _res == null
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final c in _res!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(_look(c.level).$1, color: _look(c.level).$2, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(c.detail, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
                            ])),
                          ]),
                        ),
                    ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
}

/// Countries the user never wants to exit from (Auto never picks them, they cannot be selected).
const exclusionPresets = <String, List<String>>{
  'Five Eyes': ['us', 'gb', 'ca', 'au', 'nz'],
  'Nine Eyes': ['us', 'gb', 'ca', 'au', 'nz', 'dk', 'fr', 'nl', 'no'],
  'Fourteen Eyes': ['us', 'gb', 'ca', 'au', 'nz', 'dk', 'fr', 'nl', 'no', 'de', 'be', 'it', 'se', 'es'],
};

Future<Set<String>?> showExcludeDialog(BuildContext context, {required Map<String, String> countries, required Set<String> initial, required String locked}) =>
    showDialog<Set<String>>(context: context, builder: (_) => _ExcludeDialog(countries: countries, initial: initial, locked: locked));

class _ExcludeDialog extends StatefulWidget {
  const _ExcludeDialog({required this.countries, required this.initial, required this.locked});
  final Map<String, String> countries;
  final Set<String> initial;
  final String locked; // the connected / selected country cannot be excluded
  @override
  State<_ExcludeDialog> createState() => _ExcludeDialogState();
}

class _ExcludeDialogState extends State<_ExcludeDialog> {
  late final Set<String> _sel = {...widget.initial}..remove(widget.locked);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final names = widget.countries.entries.where((e) => e.value.toLowerCase().contains(_q.toLowerCase())).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return AlertDialog(
      backgroundColor: const Color(0xFF111B2E),
      title: const Text('Exclude countries'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Excluded countries are never used as an exit: Auto skips them and they cannot be selected.', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final p in exclusionPresets.entries)
              ActionChip(label: Text(p.key), onPressed: () => setState(() => _sel.addAll(p.value.where((c) => c != widget.locked && widget.countries.containsKey(c))))),
            ActionChip(label: const Text('Clear'), onPressed: () => setState(_sel.clear)),
          ]),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: L10n.tr('Search')),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(children: [
              for (final e in names)
                CheckboxListTile(
                  dense: true,
                  value: _sel.contains(e.key),
                  title: Text(e.key == widget.locked ? '${e.value} (current location)' : e.value),
                  onChanged: e.key == widget.locked ? null : (v) => setState(() => v == true ? _sel.add(e.key) : _sel.remove(e.key)),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_sel), child: Text('Save (${_sel.length})')),
      ],
    );
  }
}

/// Ask which program to run through OnionDesk. Returns the command line, or null if cancelled.
Future<String?> showLaunchDialog(BuildContext context, {required List<String> recents, required List<String> found, List<AppEntry> apps = const []}) =>
    showDialog<String>(context: context, builder: (_) => _LaunchDialog(recents: recents, found: found, apps: apps));

class _LaunchDialog extends StatefulWidget {
  const _LaunchDialog({required this.recents, required this.found, required this.apps});
  final List<String> recents, found;
  final List<AppEntry> apps;
  @override
  State<_LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<_LaunchDialog> {
  final _c = TextEditingController();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF111B2E),
        title: const Text('Run an app through OnionDesk'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Starts the program with OnionDesk\'s proxy (127.0.0.1:9050) set, so only that app goes through Tor. '
                'Browsers get their own private profile with remote DNS and WebRTC off.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 10),
            if (widget.found.isNotEmpty) Wrap(spacing: 6, children: [for (final f in widget.found) ActionChip(label: Text(f), onPressed: () => setState(() => _c.text = f))]),
            const SizedBox(height: 8),
            TextField(controller: _c, autofocus: true, decoration: InputDecoration(isDense: true, hintText: L10n.tr('firefox   or   /path/to/app --option')), onChanged: (_) => setState(() {}), onSubmitted: (v) => Navigator.of(context).pop(v)),
            if (widget.apps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(L10n.tr('Installed apps'), style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Container(
                height: 150,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                child: Builder(builder: (_) {
                  // Typing a command hides nothing: the list only filters by name while the text looks like a name.
                  final shown = filterApps(widget.apps, _c.text.startsWith('/') || _c.text.contains(' ') ? '' : _c.text);
                  return ListView.builder(
                    itemCount: shown.length,
                    itemExtent: 34,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => setState(() => _c.text = shown[i].command),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: m.Text(shown[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    ),
                  );
                }),
              ),
            ],
            if (widget.recents.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Recent', style: TextStyle(fontSize: 12, color: Colors.white54)),
              Wrap(spacing: 6, runSpacing: 4, children: [for (final r in widget.recents) ActionChip(label: Text(r, overflow: TextOverflow.ellipsis), onPressed: () => setState(() => _c.text = r))]),
            ],
            const SizedBox(height: 10),
            const Text('Apps that ignore proxy settings are not covered (install torsocks, or use System-wide mode).', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_c.text), child: const Text('Run')),
        ],
      );
}


/// Bridge choice. Returns the new mode and custom lines, or null if cancelled.
Future<({BridgeMode mode, String custom})?> showBridgeDialog(BuildContext context, {required BridgeMode mode, required String custom, required bool available, required bool locked}) =>
    showDialog<({BridgeMode mode, String custom})>(context: context, builder: (_) => _BridgeDialog(mode: mode, custom: custom, available: available, locked: locked));

class _BridgeDialog extends StatefulWidget {
  const _BridgeDialog({required this.mode, required this.custom, required this.available, required this.locked});
  final BridgeMode mode;
  final String custom;
  final bool available, locked;
  @override
  State<_BridgeDialog> createState() => _BridgeDialogState();
}

class _BridgeDialogState extends State<_BridgeDialog> {
  late BridgeMode _mode = widget.mode;
  late final _c = TextEditingController(text: widget.custom);
  String? _err;

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  void _save() {
    if (_mode == BridgeMode.custom) {
      final bad = validateBridgeLines(_c.text);
      if (bad.isNotEmpty) { setState(() => _err = bad.first); return; }
    }
    Navigator.of(context).pop((mode: _mode, custom: _c.text));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.available && !widget.locked;
    return AlertDialog(
      backgroundColor: const Color(0xFF111B2E),
      title: const Text('Bridges'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bridges hide that you use Tor. Use one if your network blocks Tor. They are slower, and Snowflake needs the most patience.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
          if (!widget.available) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Not available in this install: the bridge transports are not bundled.', style: TextStyle(color: _amber, fontSize: 12.5))),
          if (widget.locked) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Disconnect to change this.', style: TextStyle(color: _amber, fontSize: 12.5))),
          const SizedBox(height: 6),
          RadioGroup<BridgeMode>(
            groupValue: _mode,
            onChanged: (v) { if (enabled && v != null) setState(() { _mode = v; _err = null; }); },
            child: Column(children: [
              for (final m in BridgeMode.values)
                RadioListTile<BridgeMode>(dense: true, value: m, enabled: enabled, title: Text(bridgeLabels[m]!)),
            ]),
          ),
          if (_mode == BridgeMode.custom) ...[
            TextField(
              controller: _c,
              enabled: enabled,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(isDense: true, hintText: L10n.tr('One bridge per line, e.g. obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0'), errorText: _err),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            const Text('Get bridges at bridges.torproject.org. System-wide mode cannot be combined with bridges yet.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: enabled ? _save : null, child: const Text('Save')),
      ],
    );
  }
}
