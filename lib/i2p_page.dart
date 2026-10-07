import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'extras.dart' show formatBytes, formatElapsed;
import 'i2p.dart';
import 'connect_ring.dart';
import 'l10n.dart';
import 'launch_via_i2p.dart' show appLabel;
import 'platform.dart';

const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _red = Color(0xFFFF6B6B), _violet = Color(0xFF7C9CFF);
/// Fully connected to I2P: green (the Tor tab is teal, so the two read differently at a glance).
const _green = Color(0xFF22C55E), _greenLight = Color(0xFF86EFAC);

/// The "I2P" tab: start / stop the user's own i2pd, see its status, copy the proxy addresses. Self-contained: it only
/// talks to [router]; the home page owns the router and persists the two settings through the callbacks.
class I2pPage extends StatefulWidget {
  const I2pPage({super.key, required this.router, required this.onToggleShare, required this.onLocate, required this.apps, required this.onAddApp, required this.onRemoveApp, required this.onLaunchApp, this.forced = false, required this.onOpenBrowser});
  final I2pRouter router;

  /// Saved split-tunneling apps (command lines), added by the user. Launch starts one with the I2P proxy set.
  final List<String> apps;
  final VoidCallback onAddApp;
  final void Function(String line) onRemoveApp, onLaunchApp;

  /// The force shim is available (Linux build): apps that ignore proxy settings are forced through I2P too.
  final bool forced;

  /// Opens OnionDesk Browser (its own tab); it uses I2P automatically once I2P is connected.
  final VoidCallback onOpenBrowser;

  final VoidCallback onToggleShare;
  final Future<void> Function() onLocate;
  @override
  State<I2pPage> createState() => _I2pPageState();
}

class _I2pPageState extends State<I2pPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.router.addListener(_changed);
    widget.router.detect();
    widget.router.refresh();
    // Uptime / "building tunnels" clock: only while this page is shown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && widget.router.active) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.router.removeListener(_changed);
    super.dispose();
  }

  void _changed() { if (mounted) setState(() {}); }

  I2pRouter get r => widget.router;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(duration: const Duration(milliseconds: 1400), behavior: SnackBarBehavior.floating, width: 240, content: const Text('Copied')));
  }

  Widget _glass({required Widget child, Color? glow, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.025)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [BoxShadow(color: (glow ?? Colors.black).withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: child,
      );

  Color get _color => switch (r.state) {
        I2pState.running => _green,
        I2pState.starting => _amber,
        I2pState.failed || I2pState.external => _red,
        _ => const Color(0xFF64748B),
      };

  String get _title => switch (r.state) {
        I2pState.notInstalled => 'I2P router not found',
        I2pState.stopped => 'I2P is off',
        I2pState.starting => 'Joining the I2P network…',
        I2pState.running => 'Connected to I2P',
        I2pState.failed => 'I2P stopped',
        I2pState.external => 'Another I2P router is running',
      };

  String get _sub {
    final up = r.startedAt == null ? '' : formatElapsed(DateTime.now().difference(r.startedAt!));
    return switch (r.state) {
      I2pState.notInstalled => 'Install i2pd (free), then come back here.',
      I2pState.stopped => 'Starts your own private i2pd. Nothing on your system settings is changed.',
      I2pState.starting => 'Finding peers and building tunnels. The first start can take several minutes. $up',
      I2pState.running => r.startedAt != null && DateTime.now().difference(r.startedAt!) < const Duration(minutes: 5)
          ? 'Connected. The router is still warming up: pages are slower for the first few minutes. $up'
          : 'Browse .i2p sites through the proxy below. $up',
      I2pState.failed => r.error ?? 'The router ended unexpectedly.',
      I2pState.external => r.error ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = r.state == I2pState.starting;
    final canStart = r.state == I2pState.stopped || r.state == I2pState.failed || r.state == I2pState.external;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(padding: EdgeInsets.zero, children: [
          _glass(
            glow: r.state == I2pState.running ? _green : null,
            child: Row(children: [
              _orb(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: r.state == I2pState.running ? _green : Colors.white)),
                  const SizedBox(height: 2),
                  Text(_sub, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 12),
              if (r.state != I2pState.notInstalled)
                FilledButton.icon(
                  onPressed: busy ? null : (canStart ? r.start : r.stop),
                  icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(canStart ? Icons.play_arrow_rounded : Icons.stop_rounded),
                  label: Text(busy ? 'Starting…' : (canStart ? 'Start I2P' : 'Stop')),
                  style: FilledButton.styleFrom(backgroundColor: canStart ? _green : _red, foregroundColor: const Color(0xFF07101F), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), shape: const StadiumBorder()),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          _experimentalNote(),
          const SizedBox(height: 14),
          if (r.state != I2pState.notInstalled) ...[_browserCard(), const SizedBox(height: 14)],
          if (r.state == I2pState.notInstalled) _installCard(),
          if (r.state == I2pState.external) _externalCard(),
          if (r.active) _statsRow(),
          if (r.active) const SizedBox(height: 14),
          _howToCard(),
          const SizedBox(height: 14),
          _appsCard(),
          const SizedBox(height: 14),
          _optionsCard(),
          if (r.state == I2pState.failed && r.log.trim().isNotEmpty) ...[const SizedBox(height: 14), _logCard()],
          const SizedBox(height: 14),
          _glass(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: _violet),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I2P is a separate anonymous network for .i2p sites, torrents, chat and mail inside the network. It has no country exits and does not unblock normal websites or make them faster: use the Tor tab for that.',
                  style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 13),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// I2P support is new: say so, and set expectations (it is a different, slower network than Tor).
  Widget _experimentalNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: _amber.withValues(alpha: 0.08), border: Border.all(color: _amber.withValues(alpha: 0.45))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: _amber.withValues(alpha: 0.18)),
            child: const m.Text('EXPERIMENTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: _amber)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'I2P support is new. I2P is a small, slow network: a fresh router needs 10 to 15 minutes to find its way, pages take a while to load, and many I2P sites are offline. It is not a replacement for Tor.',
              style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 12.5),
            ),
          ),
        ]),
      );

  /// The status orb: a spinning ring with the join progress while connecting, a green lock once connected.
  Widget _orb() {
    final running = r.state == I2pState.running, starting = r.state == I2pState.starting;
    final color = _color;
    return ConnectRing(
      connecting: starting,
      running: running,
      progress: r.progress,
      colors: const [_green, _greenLight],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)]),
          boxShadow: [BoxShadow(color: color.withValues(alpha: running ? 0.6 : 0.2), blurRadius: 18)],
        ),
        child: starting
            ? Center(child: m.Text('${(r.progress * 100).round()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF07101F), fontFeatures: [FontFeature.tabularFigures()])))
            : Icon(running ? Icons.lock : Icons.hub_rounded, size: 19, color: const Color(0xFF07101F)),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color accent) => Expanded(
        child: _glass(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 14, color: accent), const SizedBox(width: 6), Expanded(child: Text(label.toUpperCase(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 8),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
          ]),
        ),
      );

  Widget _statsRow() {
    final s = r.status;
    String n(int? v) => v == null ? '—' : '$v';
    String bw(double? v) => v == null ? '—' : '${formatBytes(v.round())}/s';
    return Row(children: [
      _stat('Routers known', n(s.routers), Icons.people_alt_outlined, _teal),
      const SizedBox(width: 12),
      _stat('Network', s.netText == null ? '—' : s.netText!.split(' - ').first, Icons.public, _violet),
      const SizedBox(width: 12),
      _stat('Tunnels built', s.successRate == null ? '—' : '${s.successRate!.round()}%', Icons.alt_route_rounded, _amber),
      const SizedBox(width: 12),
      _stat('Down / up', '${bw(s.bwIn)} · ${bw(s.bwOut)}', Icons.swap_vert_rounded, _teal),
    ]);
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap, {String? tip}) {
    final body = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: _teal), const SizedBox(width: 8), m.Text(label, style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]))]),
        ),
      ),
    );
    return tip == null ? body : Tooltip(message: L10n.tr(tip), child: body);
  }

  Widget _howToCard() => _glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How to use it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'The easy way: add your browser under Split tunneling below and press Launch, nothing to set up. To do it by hand, point a browser at the HTTP proxy address below, then open an .i2p address. Well-known sites (stats.i2p, i2pforum.i2p, i2p-projekt.i2p...) work at once; other names appear once i2pd has downloaded its address book, which can take several minutes (a full .b32.i2p address always works).',
            style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _chip(Icons.copy_rounded, 'HTTP proxy  127.0.0.1:$kI2pHttpPort', () => _copy('127.0.0.1:$kI2pHttpPort'), tip: 'Copy the HTTP proxy address'),
            _chip(Icons.copy_rounded, 'SOCKS5  127.0.0.1:$kI2pSocksPort', () => _copy('127.0.0.1:$kI2pSocksPort'), tip: 'Copy the SOCKS5 address'),
            _chip(Icons.open_in_new_rounded, 'Router console', () => Plat.openUrl('http://127.0.0.1:$kI2pConsolePort/'), tip: 'Open the i2pd web console (needs the router running)'),
          ]),
        ]),
      );

  /// OnionDesk Browser lives in its own tab; this card is the way in (no app to choose, no proxy to set).
  Widget _browserCard() => _glass(
        glow: r.state == I2pState.running ? _green : null,
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [_teal, _violet])), child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF07101F), size: 24)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('OnionDesk Browser', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('A browser built into OnionDesk (no Chromium, no web engine). It uses I2P and Tor automatically, whichever are connected. It shows pages without JavaScript, so simple sites like eepsites, forums and wikis work best.',
                  style: TextStyle(color: Colors.white60, height: 1.4, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: widget.onOpenBrowser,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open OnionDesk Browser'),
            style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF07101F), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: const StadiumBorder()),
          ),
        ]),
      );

  /// Split tunneling: only the apps the user adds here are started with the I2P proxy; the rest of the computer is untouched.
  Widget _appsCard() {
    final ready = r.state == I2pState.running;
    return _glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.call_split_rounded, size: 20, color: _violet),
          const SizedBox(width: 10),
          const Expanded(child: Text('Split tunneling: apps through I2P', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          OutlinedButton.icon(
            onPressed: widget.onAddApp,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add app…'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 14)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          widget.apps.isEmpty
              ? 'Add the programs that should use I2P (a browser, a torrent client, a chat app). They are started with I2P already set up: you do not configure any proxy. Everything else on your computer stays as it is.'
              : (ready ? (widget.forced ? 'Press Launch. The app is forced through I2P automatically, even if it has no proxy setting (Flatpak/Snap, statically linked and Go programs excepted).' : 'Press Launch. The app is started with I2P set up automatically. Programs that ignore proxy settings are not covered on this system.') : 'Start I2P first, then launch your apps.'),
          style: const TextStyle(color: Colors.white60, height: 1.45, fontSize: 13),
        ),
        if (widget.apps.isNotEmpty) const SizedBox(height: 10),
        for (final line in widget.apps)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.05), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: Row(children: [
              const Icon(Icons.apps_rounded, size: 16, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(message: line, child: m.Text(appLabel(line), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
              ),
              TextButton(onPressed: ready ? () => widget.onLaunchApp(line) : null, child: const Text('Launch')),
              IconButton(tooltip: L10n.tr('Remove'), onPressed: () => widget.onRemoveApp(line), icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38), visualDensity: VisualDensity.compact),
            ]),
          ),
      ]),
    );
  }

  Widget _optionsCard() => _glass(
        child: Column(children: [
          Row(children: [
            const Icon(Icons.volunteer_activism_outlined, size: 20, color: Colors.white54),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Share bandwidth with the network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Lets your router relay other people\'s traffic (how I2P stays fast). Uses your bandwidth, so it is off by default. Takes effect the next time you start I2P.', style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.3)),
              ]),
            ),
            Switch(value: r.share, onChanged: (_) => widget.onToggleShare(), activeThumbColor: _teal, activeTrackColor: _teal.withValues(alpha: 0.35)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.folder_open_rounded, size: 20, color: Colors.white54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('i2pd program', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(r.exe == null ? L10n.tr('Not found') : (r.bundled ? L10n.tr('Included with OnionDesk') : r.exe!), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
            ),
            OutlinedButton(
              onPressed: r.active ? null : widget.onLocate,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: const Text('Locate…'),
            ),
          ]),
        ]),
      );

  Widget _installCard() {
    final hint = i2pInstallHint(win: Plat.win, mac: Plat.mac, osRelease: _osRelease());
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _glass(
        glow: _amber,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Install i2pd', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('OnionDesk normally includes the free i2pd router, but this copy does not. Install it once, then press Check again.', style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (hint != null) _chip(Icons.terminal_rounded, hint.command, () => _copy(hint.command), tip: 'Copy the install command'),
            _chip(Icons.download_rounded, 'i2pd releases (GitHub)', () => Plat.openUrl('https://github.com/PurpleI2P/i2pd/releases'), tip: 'Open the official downloads'),
            _chip(Icons.refresh_rounded, 'Check again', r.detect),
          ]),
        ]),
      ),
    );
  }

  Widget _externalCard() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _glass(
          glow: _red,
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: _red),
            const SizedBox(width: 12),
            const Expanded(child: Text('OnionDesk never touches an I2P router it did not start. Stop the other one (for example the i2pd service), or use its console, then press Start again.', style: TextStyle(height: 1.4, fontSize: 13))),
            const SizedBox(width: 12),
            _chip(Icons.open_in_new_rounded, 'Open console', () => Plat.openUrl('http://127.0.0.1:$kI2pConsolePort/')),
          ]),
        ),
      );

  Widget _logCard() {
    final lines = r.log.trim().split('\n');
    final tail = lines.sublist(lines.length > 12 ? lines.length - 12 : 0).join('\n');
    return _glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Last messages from i2pd', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(tail, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Colors.white70, height: 1.35)),
      ]),
    );
  }

  String? _osRelease() {
    try { return File('/etc/os-release').readAsStringSync(); } catch (_) { return null; }
  }
}
