import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:webview_cef/webview_cef.dart';
import 'browser_mux.dart';
import 'browser_nav.dart';
import 'browser_sandbox.dart';
import 'extras.dart' show lightTheme, kLightFilter;
import 'l10n.dart';

const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _red = Color(0xFFFF6B6B), _violet = Color(0xFF7C9CFF), _green = Color(0xFF22C55E);

/// The engine reports a failed load as a `data:text/html;base64,...` page saying "Failed to load URL X with error E (-n)".
/// Returns X and E, or null for any other address.
({String url, String error})? parseLoadError(String dataUrl) {
  const p = 'data:text/html;base64,';
  if (!dataUrl.startsWith(p)) return null;
  try {
    final html = utf8.decode(base64.decode(Uri.decodeComponent(dataUrl.substring(p.length))), allowMalformed: true);
    final m = RegExp(r'Failed to load URL (\S+) with error (\w+)').firstMatch(html);
    return m == null ? null : (url: m.group(1)!, error: m.group(2)!);
  } catch (_) {
    return null;
  }
}

/// One browser tab. The engine's browser is created the first time the tab opens an address (a fresh tab only shows
/// the start screen and costs nothing).
class _BTab {
  _BTab(this.id);
  final int id;
  WebViewController? ctl;
  bool ready = false, loading = false, start = true, zoomed = false;
  String title = '', url = '';
  ({String url, String error})? loadError;
}

/// OnionDesk Browser: a Chromium (CEF) browser inside the app, with tabs and a full-view mode. Every request goes through
/// one local SOCKS5 route ([BrowserMux]) that sends `.i2p` to I2P and everything else to Tor, according to what is
/// connected, and refuses anything else. The browser itself has no way to reach the internet directly.
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.torReady, required this.i2pReady, required this.fullView, required this.onToggleFull});

  /// Which networks are connected right now (they are connected from the Tor and I2P tabs). The browser uses
  /// whatever is up, automatically: Tor for the normal web, I2P for .i2p, both together if both are connected.
  /// There is nothing to configure or connect in the browser itself.
  final bool torReady, i2pReady;

  /// Full view: the app's own header and margins are hidden so the page fills the window (the home page decides how).
  final bool fullView;
  final VoidCallback onToggleFull;

  @override
  State<BrowserPage> createState() => BrowserPageState();
}

class BrowserPageState extends State<BrowserPage> {
  BrowserMux? _mux;
  String? _error;
  bool _engineReady = false;
  final List<_BTab> _tabs = [];
  int _active = 0, _nextId = 1;
  final _addr = TextEditingController();
  final _addrFocus = FocusNode();
  bool _noSandbox = false; // this system cannot run Chromium's sandbox: the browser warns
  int _refusedSeen = 0;
  String? _blockedNote;

  _BTab get _tab => _tabs[_active];
  bool get _loading => _engineReady && _tab.loading;
  bool get _start => _tab.start;
  String get _url => _tab.url;

  @override
  void initState() {
    super.initState();
    _bootEngine();
  }

  Future<void> _bootEngine() async {
    try {
      final mux = BrowserMux(torOn: () => widget.torReady, i2pOn: () => widget.i2pReady);
      final port = await mux.start();
      _mux = mux;
      mux.changed.addListener(_onRefused);
      // The engine takes the proxy as a start-up setting: this local route, and nothing else.
      _noSandbox = !sandboxAvailable(linux: Platform.isLinux);
      await WebviewManager().initialize(proxyServer: '127.0.0.1:$port', noSandbox: _noSandbox);
      if (!mounted) return;
      setState(() {
        _tabs.add(_BTab(_nextId++));
        _engineReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Create the engine browser of [t] and load [url] in it.
  Future<void> _spawn(_BTab t, String url) async {
    final c = WebviewManager().createWebView(loading: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: _teal)));
    t.ctl = c;
    c.setWebviewListener(WebviewEventsListener(
      onTitleChanged: (title) { if (mounted && !title.startsWith('data:')) setState(() => t.title = title); },
      onUrlChanged: (u) {
        if (!mounted) return;
        // A failed load arrives as a data: page with the reason in it. Show our own panel and keep the real address.
        final err = parseLoadError(u);
        if (err != null) {
          setState(() { t.loadError = err; t.start = false; t.url = err.url; if (t == _tab) _addr.text = displayAddress(err.url); });
          return;
        }
        if (u.startsWith('data:')) return;
        setState(() {
          t.loadError = null;
          t.url = u;
          if (u.isNotEmpty && u != 'about:blank') {
            t.start = false;
            if (t == _tab && !_addrFocus.hasFocus) _addr.text = displayAddress(u);
          }
        });
      },
      onLoadStart: (_, _) { if (mounted) setState(() => t.loading = true); },
      onLoadEnd: (_, _) {
        if (!mounted) return;
        setState(() => t.loading = false);
        _applyZoom(t);
      },
    ));
    try {
      await c.initialize(url);
      if (mounted) setState(() => t.ready = true);
    } catch (e) {
      if (mounted) setState(() => _blockedNote = 'The page could not be started: $e');
    }
  }

  // ---- zoom (Ctrl +/-/0): the engine has no zoom call, so the page's own scale is changed ----
  double _zoom = 1.0;

  void _applyZoom(_BTab t) {
    if (t.ready && _zoom != 1.0 || t.ready && t.zoomed) {
      t.zoomed = _zoom != 1.0;
      t.ctl?.executeJavaScript("document.documentElement.style.zoom='${_zoom.toStringAsFixed(2)}'");
    }
  }

  void zoomIn() { setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 3.0)); _applyZoom(_tab); }
  void zoomOut() { setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 3.0)); _applyZoom(_tab); }
  void zoomReset() { setState(() => _zoom = 1.0); _applyZoom(_tab); }

  // ---- tabs ----

  /// Ctrl+T / the + button: a fresh tab with the start screen, and the address bar ready to type.
  void newTab() {
    if (!_engineReady) return;
    setState(() {
      _tabs.add(_BTab(_nextId++));
      _active = _tabs.length - 1;
      _addr.clear();
      _blockedNote = null;
    });
    _addrFocus.requestFocus();
  }

  /// Ctrl+W / the x on a tab. The last tab is replaced by a fresh one, so the browser always has a tab.
  Future<void> closeTab(int i) async {
    if (i < 0 || i >= _tabs.length) return;
    final t = _tabs[i];
    setState(() {
      _tabs.removeAt(i);
      if (_tabs.isEmpty) _tabs.add(_BTab(_nextId++));
      if (_active >= _tabs.length) _active = _tabs.length - 1;
      if (i < _active) _active--;
      _syncAddr();
    });
    if (t.ctl != null && t.ready) {
      try { await t.ctl!.dispose(); } catch (_) {}
    }
  }

  void closeCurrentTab() => closeTab(_active);

  void _select(int i) {
    if (i == _active) return;
    setState(() { _active = i; _blockedNote = null; _syncAddr(); });
  }

  void _syncAddr() => _addr.text = _tab.start ? '' : displayAddress(_tab.url);

  // ---- navigation ----

  void _onRefused() {
    final m = _mux;
    if (m == null || !mounted || m.refused == _refusedSeen) return;
    _refusedSeen = m.refused;
    final h = m.lastRefused ?? '';
    if (_isBackgroundHost(h)) return; // Chromium's own chatter, not something the user asked for
    final i2p = h.toLowerCase().endsWith('.i2p');
    setState(() => _blockedNote = i2p
        ? 'Blocked $h: I2P is not connected (start it in the I2P tab).'
        : 'Blocked $h: Tor is not connected (connect it in the Tor tab). Nothing is sent outside Tor or I2P.');
  }

  @override
  void dispose() {
    _mux?.changed.removeListener(_onRefused);
    _mux?.stop();
    _addr.dispose();
    _addrFocus.dispose();
    // The engine and its webviews live as long as the app: the page is kept alive while another tab is shown.
    super.dispose();
  }

  /// Hosts Chromium may contact on its own; their refusal is expected and not worth a notice.
  static bool _isBackgroundHost(String h) {
    final x = h.toLowerCase();
    return x.endsWith('google.com') || x.endsWith('googleapis.com') || x.endsWith('gstatic.com') || x.endsWith('googleusercontent.com') || x.endsWith('chromium.org');
  }

  void _go(String text) {
    final u = resolveAddress(text, useTor: widget.torReady || !widget.i2pReady, useI2p: widget.i2pReady);
    if (u == null) {
      setState(() => _blockedNote = 'That address cannot be opened here (only http and https).');
      return;
    }
    _openUrl(u);
  }

  void _openUrl(String u) {
    final t = _tab;
    setState(() { _blockedNote = null; t.loadError = null; t.start = false; t.url = u; t.loading = true; t.title = ''; _addr.text = displayAddress(u); });
    if (t.ctl == null) {
      _spawn(t, u);
    } else if (t.ready) {
      t.ctl!.loadUrl(u);
    }
    _addrFocus.unfocus();
  }

  void _home() {
    final t = _tab;
    setState(() { t.start = true; t.loadError = null; t.title = ''; t.url = ''; _addr.clear(); _blockedNote = null; });
    if (t.ctl != null && t.ready) t.ctl!.loadUrl('about:blank');
  }

  void _back() { if (_tab.ready) _tab.ctl?.goBack(); }
  void _forward() { if (_tab.ready) _tab.ctl?.goForward(); }
  void _reload() { if (_tab.ready) _tab.ctl?.reload(); }

  Widget _navButton(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
        message: L10n.tr(tip),
        waitDuration: const Duration(milliseconds: 500),
        child: InkResponse(
          onTap: onTap,
          radius: 16,
          child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 17, color: onTap == null ? Colors.white24 : Colors.white70)),
        ),
      );

  /// Green when something is connected, red when nothing is: the browser's network state at a glance (read-only).
  Widget _statusCapsule() {
    final up = widget.torReady || widget.i2pReady;
    final color = up ? _green : _red;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.10), border: Border.all(color: color.withValues(alpha: 0.45))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 4)])),
        const SizedBox(width: 6),
        m.Text(L10n.tr(_via()), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  /// The tabs: slim, one line. The open tab has a teal underline; a spinner shows while loading; the close button
  /// shows on the open tab and under the pointer. "+" opens a new tab.
  Widget _tabStrip() => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
        child: SizedBox(
          height: 30,
          child: LayoutBuilder(builder: (_, box) {
            final room = box.maxWidth - 150; // the new-tab button and the status capsule
            final w = (room / (_tabs.isEmpty ? 1 : _tabs.length)).clamp(104.0, 190.0);
            return Row(children: [
              SizedBox(
                width: (w * _tabs.length).clamp(0.0, room < 0 ? 0.0 : room),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < _tabs.length; i++) _tabChip(i, w)]),
                ),
              ),
              const SizedBox(width: 2),
              _navButton(Icons.add_rounded, 'New tab (Ctrl+T)', newTab),
              const Spacer(),
              _statusCapsule(),
            ]);
          }),
        ),
      );

  int _hoverTab = -1;

  Widget _tabChip(int i, double width) {
    final t = _tabs[i], on = i == _active;
    final showClose = on || _hoverTab == i;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoverTab = i),
      onExit: (_) => setState(() { if (_hoverTab == i) _hoverTab = -1; }),
      child: GestureDetector(
        onTap: () => _select(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: 30,
          margin: const EdgeInsets.only(right: 3),
          padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            color: on ? Colors.white.withValues(alpha: 0.09) : (_hoverTab == i ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            border: Border(bottom: BorderSide(color: on ? _teal : Colors.transparent, width: 2)),
          ),
          child: Row(children: [
            SizedBox(
              width: 13,
              height: 13,
              child: t.loading ? const CircularProgressIndicator(strokeWidth: 1.8, color: _teal) : Icon(t.start ? Icons.add_box_outlined : Icons.public_rounded, size: 13, color: on ? _teal : Colors.white38),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: m.Text(
                t.title.isNotEmpty && !t.start ? t.title : L10n.tr('New tab'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.8, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : Colors.white60),
              ),
            ),
            SizedBox(
              width: 20,
              child: showClose
                  ? InkResponse(onTap: () => closeTab(i), radius: 11, child: Icon(Icons.close_rounded, size: 13, color: on ? Colors.white70 : Colors.white38))
                  : null,
            ),
          ]),
        ),
      ),
    );
  }

  /// What kind of address is open, shown inside the address bar: I2P, a secure page, or a plain http page.
  Widget _addrBadge() {
    final host = Uri.tryParse(_url)?.host ?? '';
    if (_url.isEmpty || _start) return const Icon(Icons.search_rounded, size: 16, color: Colors.white54);
    if (host.endsWith('.i2p')) {
      return Container(
        margin: const EdgeInsets.only(left: 8, right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: _green.withValues(alpha: 0.16), border: Border.all(color: _green.withValues(alpha: 0.6))),
        child: const m.Text('I2P', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _green, letterSpacing: 0.5)),
      );
    }
    if (_url.startsWith('https://')) return const Icon(Icons.lock_rounded, size: 15, color: _green);
    return const Icon(Icons.lock_open_rounded, size: 15, color: _amber);
  }

  /// Shown while the first bytes of a page have not arrived (the engine paints nothing before that): a clear "opening" state
  /// instead of an empty black area. The first request through Tor or I2P can take a while.
  Widget _openingOverlay(_BTab t) {
    final host = Uri.tryParse(t.url)?.host ?? t.url;
    final i2p = host.endsWith('.i2p');
    return Container(
      color: const Color(0xFF0B1220),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6, color: _teal)),
        const SizedBox(height: 16),
        m.Text('${L10n.tr('Opening')} $host', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        m.Text(L10n.tr(i2p ? 'The first page through I2P can take up to a minute.' : 'The first page through Tor can take a few seconds.'), style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
    );
  }

  /// Light mode is the whole app run through [kLightFilter], which would also invert the web page (photos look like negatives).
  /// The filter is its own inverse (an involution), so applying it again to the page restores the real colors.
  Widget _trueColors(Widget page) => ValueListenableBuilder<bool>(
        valueListenable: lightTheme,
        builder: (_, light, child) => light ? ColorFiltered(colorFilter: kLightFilter, child: child) : child!,
        child: page,
      );

  /// A slim notice line (blocked request, sandbox warning ...).
  Widget _note(IconData icon, Color color, String text, {VoidCallback? onClose}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.09), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: m.Text(text, style: const TextStyle(fontSize: 11.8, color: Colors.white70))),
          if (onClose != null) InkResponse(onTap: onClose, radius: 12, child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.close_rounded, size: 13, color: Colors.white38))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final none = !widget.torReady && !widget.i2pReady;
    final active = _engineReady && _tabs.isNotEmpty ? _tab : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _tabStrip(),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 34,
          child: Row(children: [
            _navButton(Icons.arrow_back_rounded, 'Back', active?.ready == true ? _back : null),
            _navButton(Icons.arrow_forward_rounded, 'Forward', active?.ready == true ? _forward : null),
            _navButton(_loading ? Icons.close_rounded : Icons.refresh_rounded, _loading ? 'Stop' : 'Reload', active?.ready == true ? _reload : null),
            _navButton(Icons.home_rounded, 'Start page', _engineReady ? _home : null),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextField(
                  controller: _addr,
                  focusNode: _addrFocus,
                  enabled: _engineReady,
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: _go,
                  onTap: () => _addr.selection = TextSelection(baseOffset: 0, extentOffset: _addr.text.length),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: L10n.tr('Search, or type an address (name.i2p works)'),
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                    prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Center(widthFactor: 1, child: _addrBadge())),
                    prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _teal, width: 1.2)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if ((_zoom - 1.0).abs() > 0.01) Tooltip(message: L10n.tr('Reset zoom (Ctrl+0)'), child: GestureDetector(onTap: zoomReset, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: m.Text('${(_zoom * 100).round()}%', style: const TextStyle(fontSize: 11, color: Colors.white60))))),
            _navButton(widget.fullView ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, widget.fullView ? 'Exit full view (F11)' : 'Full view (F11)', widget.onToggleFull),
          ]),
        ),
      ),
      if (_noSandbox) _note(Icons.gpp_maybe_rounded, _red, L10n.tr('This system does not allow the browser sandbox (user namespaces are off), so the browser runs without it. Avoid untrusted sites, or enable user namespaces.')),
      if (none || _blockedNote != null)
        _note(Icons.shield_outlined, _amber, L10n.tr(_blockedNote ?? 'Neither Tor nor I2P is connected, so nothing can open yet. Connect Tor in the Tor tab, or start I2P in the I2P tab; the browser then uses them automatically.'),
            onClose: _blockedNote != null ? () => setState(() => _blockedNote = null) : null),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: const Color(0xFF0B1220),
              child: _error != null
                  ? _errorView()
                  : active == null
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: _teal))
                      : Stack(children: [
                          // Only the open tab's page is shown; the others keep their state in the engine.
                          if (active.ctl != null && active.ready) Positioned.fill(child: KeyedSubtree(key: ValueKey(active.id), child: _trueColors(active.ctl!.webviewWidget))),
                          if (active.loading && active.title.isEmpty && active.loadError == null && !active.start) Positioned.fill(child: _openingOverlay(active)),
                          if (active.loadError != null) Positioned.fill(child: _errorPanel(active.loadError!)),
                          if (active.start) Positioned.fill(child: _startScreen()),
                          if (active.loading)
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: LinearProgressIndicator(minHeight: 2, color: _teal, backgroundColor: Colors.transparent),
                            ),
                        ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.web_asset_off_rounded, size: 40, color: _red),
            const SizedBox(height: 12),
            const Text('The browser engine could not start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            m.Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
          ]),
        ),
      );

  /// Read-only: which networks the browser is using right now.
  String _via() => widget.torReady && widget.i2pReady ? 'via Tor + I2P' : widget.torReady ? 'via Tor' : widget.i2pReady ? 'via I2P' : 'no network';

  /// "This page can't be opened": our own words for what went wrong, with what to try.
  Widget _errorPanel(({String url, String error}) e) {
    final host = Uri.tryParse(e.url)?.host ?? e.url;
    final i2p = host.endsWith('.i2p');
    final torOff = !i2p && !widget.torReady;
    final i2pOff = i2p && !widget.i2pReady;
    final String why = const {'ERR_SOCKS_CONNECTION_FAILED', 'ERR_PROXY_CONNECTION_FAILED', 'ERR_CONNECTION_CLOSED', 'ERR_CONNECTION_REFUSED', 'ERR_EMPTY_RESPONSE', 'ERR_TUNNEL_CONNECTION_FAILED', 'ERR_CONNECTION_RESET'}.contains(e.error)
        ? (i2pOff
            ? 'I2P is not connected. Start it in the I2P tab and wait until it says connected.'
            : torOff
                ? 'Tor is not connected. Connect it in the Tor tab. Normal websites open only through Tor.'
                : i2p
                    ? 'The I2P router could not reach this site. It may be offline, or its name is not in your address book yet (it downloads in the background; try again in a few minutes, or use a .b32.i2p address).'
                    : 'Tor could not reach this site. It may be down or blocking Tor.')
        : e.error == 'ERR_NAME_NOT_RESOLVED' ? 'The name could not be found.' : 'The page could not be loaded (${e.error}).';
    return Container(
      color: const Color(0xFF0B1220),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.cloud_off_rounded, size: 38, color: _amber),
              const SizedBox(height: 14),
              m.Text(L10n.tr('This page cannot be opened'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              m.Text(e.url, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _violet, fontSize: 13)),
              const SizedBox(height: 14),
              m.Text(L10n.tr(why), style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14)),
              const SizedBox(height: 18),
              Row(children: [
                FilledButton.icon(onPressed: () => _openUrl(e.url), icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Try again'), style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF07101F), shape: const StadiumBorder())),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: _home, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: const StadiumBorder()), child: const Text('Start page')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, Color accent, List<QuickLink> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          m.Text(L10n.tr(title).toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: 1.3, color: accent, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [for (final l in links) _QuickCard(link: l, accent: accent, onTap: () => _openUrl(l.url))]),
      ]);

  /// The start screen: made of Flutter widgets (no web page of ours), shown until the first address is opened.
  Widget _startScreen() => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1220), Color(0xFF0E1B33), Color(0xFF0B1220)])),
        child: Stack(children: [
          Positioned(top: -120, left: -80, child: _glow(_teal, 340)),
          Positioned(bottom: -140, right: -60, child: _glow(_violet, 380)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(32, 34, 32, 34), children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [_teal, _violet]), boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 26)]),
                    child: const Icon(Icons.travel_explore_rounded, size: 34, color: Color(0xFF07101F)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [_teal, _violet]).createShader(r),
                    child: const m.Text('OnionDesk Browser', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _amber.withValues(alpha: 0.16), border: Border.all(color: _amber.withValues(alpha: 0.6))),
                    child: const m.Text('BETA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: _amber)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: m.Text(
                    L10n.tr('Browse through Tor, I2P or both, automatically, whichever is connected. This browser has no direct connection to the internet: if a network is off, its sites simply do not open.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, height: 1.5, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: TextField(
                      onSubmitted: _go,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: L10n.tr('Search, or type an address (name.i2p works)'),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _teal, width: 1.6)),
                      ),
                    ),
                  ),
                ),
                if (widget.i2pReady) ...[const SizedBox(height: 34), _section('I2P search engines and directories', Icons.hub_rounded, _green, kI2pQuickLinks)],
                if (widget.torReady) ...[const SizedBox(height: 28), _section('The web through Tor', Icons.public_rounded, _violet, kTorQuickLinks)],
                if (!widget.torReady && !widget.i2pReady) ...[
                  const SizedBox(height: 30),
                  Center(child: m.Text(L10n.tr('Connect Tor or start I2P (in their own tabs) and this page fills with places to go.'), textAlign: TextAlign.center, style: const TextStyle(color: _amber, fontSize: 14))),
                ],
              ]),
            ),
          ),
        ]),
      );

  Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.16), c.withValues(alpha: 0)]))),
      );
}

/// A start-screen card: initial in a gradient circle, name, address, one line about it. Lifts a little under the pointer.
class _QuickCard extends StatefulWidget {
  const _QuickCard({required this.link, required this.accent, required this.onTap});
  final QuickLink link;
  final Color accent;
  final VoidCallback onTap;
  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.link, a = widget.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 218,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: _hover ? const Color(0xFF15233C) : const Color(0xFF111B2E),
            border: Border.all(color: _hover ? a.withValues(alpha: 0.8) : const Color(0xFF1D2C47)),
            boxShadow: _hover ? [BoxShadow(color: a.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [a, a.withValues(alpha: 0.45)])),
              child: m.Text(l.title.characters.first.toUpperCase(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF07101F))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                m.Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                m.Text(Uri.parse(l.url).host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: a)),
                const SizedBox(height: 5),
                m.Text(L10n.tr(l.blurb), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
