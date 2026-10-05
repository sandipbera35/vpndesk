import 'package:flutter/material.dart';
import 'platform.dart';

const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _violet = Color(0xFF7C9CFF);

/// Slide + fade + slight scale route for the About page.
Route<void> aboutRoute(Widget windowDots, {VoidCallback? onUninstall}) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => AboutPage(windowDots: windowDots, onUninstall: onUninstall),
      transitionsBuilder: (_, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
            child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(c), child: child),
          ),
        );
      },
    );

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.windowDots, this.onUninstall});
  final Widget windowDots;

  /// Null where uninstalling from the app is not supported (only Linux for now): the card is hidden.
  final VoidCallback? onUninstall;
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _in.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// Staggered entrance: section [i] fades/slides in after the previous ones.
  Widget _stagger(int i, Widget child) {
    final start = (0.08 * i).clamp(0.0, 0.8);
    final a = CurvedAnimation(parent: _in, curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a), child: child),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D1A), Color(0xFF0E1830), Color(0xFF070D1A)]),
          ),
          child: Stack(children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (_, _) => Stack(children: [
                _blob(Alignment(-1 + 0.4 * _glow.value, -1), _teal, 560),
                _blob(Alignment(1, 1 - 0.4 * _glow.value), const Color(0xFF7C5CFF), 600),
              ]),
            ),
            Column(children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  widget.windowDots,
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                  ),
                ]),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
                      _stagger(0, _header()),
                      const SizedBox(height: 18),
                      _stagger(1, _authorCard()),
                      const SizedBox(height: 18),
                      _stagger(2, _section('How it works', Icons.account_tree_rounded, _teal, _howItWorks())),
                      const SizedBox(height: 18),
                      _stagger(3, _section('Modes & options', Icons.tune_rounded, _teal, _modes())),
                      const SizedBox(height: 18),
                      _stagger(4, _section('Open-source technology', Icons.code_rounded, _violet, _tech())),
                      const SizedBox(height: 18),
                      _stagger(5, _section('Good to know', Icons.info_outline_rounded, _amber, _notes())),
                      const SizedBox(height: 18),
                      _stagger(6, _aiNote()),
                      if (widget.onUninstall != null) ...[
                        const SizedBox(height: 18),
                        _stagger(7, _uninstallCard()),
                      ],
                    ]),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _blob(Alignment a, Color c, double size) => Align(
        alignment: a,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0)])),
        ),
      );

  Widget _glass(Widget child, {Color? glow}) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.025)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [BoxShadow(color: (glow ?? Colors.black).withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: child,
      );

  Widget _header() => Column(children: [
        AnimatedBuilder(
          animation: _glow,
          builder: (_, _) => Container(
            width: 104, height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.25 + 0.3 * _glow.value), blurRadius: 24 + 20 * _glow.value)],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(26), child: Image.asset('assets/icon.png', fit: BoxFit.cover, filterQuality: FilterQuality.high)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('VPN Desk', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        const Text('Pick a country. Browse through Tor. No account, no subscription.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
      ]);

  Widget _authorCard() => _glass(
        glow: _teal,
        Wrap(spacing: 22, runSpacing: 18, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (_, _) => Container(
              width: 96, height: 96,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF7C5CFF), _teal]),
                boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.2 + 0.25 * _glow.value), blurRadius: 18 + 14 * _glow.value)],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/profile.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF0E1830),
                    alignment: Alignment.center,
                    child: const Text('SB', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('CREATED BY', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Sandip Bera', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: const [
              _LinkChip(icon: Icons.code_rounded, label: 'GitHub', url: 'https://github.com/sandipbera35', color: Colors.white),
              _LinkChip(icon: Icons.language_rounded, label: 'sandipbera.in', url: 'https://sandipbera.in', color: _teal),
              _LinkChip(icon: Icons.work_rounded, label: 'LinkedIn', url: 'https://www.linkedin.com/in/sandipbera', color: _violet),
            ]),
          ]),
        ]),
      );

  Widget _section(String title, IconData icon, Color accent, Widget body) => _glass(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          body,
        ]),
      );

  Widget _howItWorks() {
    const steps = [
      ('Choose a location', 'Pick a country (or turn on Auto to always use the fastest). The app asks the Tor Project\'s Onionoo directory for the best exit relay in that country.'),
      ('Start Tor', 'It writes a torrc with ExitNodes pinned to that relay and StrictNodes on, then launches the bundled tor. Tor builds a 3-hop circuit: guard → middle → exit.'),
      ('Route traffic', 'Tor opens a SOCKS5 proxy on 127.0.0.1:9050 and the app points your system proxy at it, so apps that honour the proxy leave from the exit relay\'s country. With the optional System-wide mode (Linux), an nftables rule also redirects every app\'s TCP and DNS into Tor after one administrator prompt.'),
      ('Verify', 'The exit IP is looked up through Tor and both your real and exit IPs are pinned on the map. The card values refresh automatically.'),
      ('Live speed estimates', 'Every minute the app measures real round-trip time to relays in each country, caps it by relay bandwidth, and calibrates against speeds you have actually measured.'),
      ('Switch without leaks', 'Changing country edits the torrc and reloads Tor while the proxy stays on, so traffic waits for a new circuit instead of going direct.'),
      ('Disconnect', 'Stopping the app ends tor and restores your proxy settings.'),
    ];
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _teal.withValues(alpha: 0.15), border: Border.all(color: _teal.withValues(alpha: 0.6))),
              child: Text('${i + 1}', style: const TextStyle(color: _teal, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(steps[i].$2, style: const TextStyle(color: Colors.white60, height: 1.45, fontSize: 13.5)),
              ]),
            ),
          ]),
        ),
    ]);
  }

  Widget _modes() => LayoutBuilder(builder: (_, c) {
        final two = c.maxWidth > 640;
        final w = two ? (c.maxWidth - 14) / 2 : c.maxWidth;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(
            width: w,
            child: const _ModeCard(
              icon: Icons.bolt_rounded,
              color: _amber,
              title: 'Auto (fastest location)',
              tagline: 'Always use the location with the highest speed.',
              points: [
                'Turn it on with the Auto chip inside the country box. The choice is remembered.',
                'Ranks countries by speed: your own measured speed through Tor when you have one, otherwise a live estimate from round-trip time and relay bandwidth, refreshed every minute.',
                'Disconnected: the fastest country is pre-selected, and Connect uses it.',
                'Connected: it switches only if another location is at least 25% faster, and at most once every 5 minutes, so it does not bounce around.',
                'Switching never drops Tor or the proxy, so your real IP is not exposed while it changes.',
              ],
            ),
          ),
          SizedBox(
            width: w,
            child: const _ModeCard(
              icon: Icons.shield_rounded,
              color: _teal,
              title: 'System-wide (Linux)',
              tagline: 'Send every app\'s traffic through Tor, not just proxy-aware ones.',
              points: [
                'Optional and off by default. Works on GNOME, KDE and other desktops.',
                'Asks for your administrator password once when you connect, then adds nftables rules that redirect all TCP and DNS into Tor.',
                'Tor itself runs as a separate "vpndesk" user so its own traffic is not redirected.',
                'UDP (QUIC/HTTP3, games, voice calls) and IPv6 are blocked, because Tor cannot carry them. Local-network addresses stay direct.',
                'Disconnecting or closing the app restores normal networking. If Tor crashes, traffic stays blocked until you press Restore, so nothing leaks.',
                'Off: only apps that use the system proxy (SOCKS5 127.0.0.1:9050) go through Tor.',
              ],
            ),
          ),
        ]);
      });

  Widget _tech() {
    const items = [
      ('Tor', 'The anonymity network and the tor client that does the routing', 'BSD-3-Clause', 'https://www.torproject.org'),
      ('Flutter & Dart', 'UI toolkit and language the whole app is written in', 'BSD-3-Clause', 'https://flutter.dev'),
      ('libevent', 'Event loop used by tor (bundled)', 'BSD-3-Clause', 'https://libevent.org'),
      ('OpenSSL', 'TLS and cryptography used by tor (bundled)', 'Apache-2.0', 'https://www.openssl.org'),
      ('zlib', 'Compression used by tor (bundled)', 'zlib', 'https://zlib.net'),
      ('bitsdojo_window', 'Frameless window with custom controls', 'MIT', 'https://pub.dev/packages/bitsdojo_window'),
      ('socks5_proxy', 'Sends the app\'s own requests through Tor\'s SOCKS5 port', 'MIT', 'https://pub.dev/packages/socks5_proxy'),
      ('Natural Earth', 'Country outlines for the world map', 'Public domain', 'https://www.naturalearthdata.com'),
      ('Onionoo', 'Tor Project relay directory API used to find exits', 'Public service', 'https://metrics.torproject.org/onionoo.html'),
    ];
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 700 ? 3 : (c.maxWidth > 440 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final t in items) SizedBox(width: w, child: _TechTile(name: t.$1, desc: t.$2, license: t.$3, url: t.$4)),
      ]);
    });
  }

  Widget _uninstallCard() => _glass(
        glow: const Color(0xFFFF6B6B),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF6B6B)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Uninstall VPN Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Removes the app, its system helper and (if you choose) your settings from this computer. You will be asked to confirm.',
                  style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 13.5)),
            ]),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: widget.onUninstall,
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B), side: BorderSide(color: const Color(0xFFFF6B6B).withValues(alpha: 0.6))),
            child: const Text('Uninstall…'),
          ),
        ]),
      );

  Widget _aiNote() => _glass(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: _violet),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Built with AI assistance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                'This app was designed and directed by Sandip Bera and developed with the help of AI coding assistants: Claude Code (by Anthropic) and OpenCode. All code was reviewed and tested by the author.',
                style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 13.5),
              ),
            ]),
          ),
        ]),
      );

  Widget _notes() => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Bullet('By default this is a local SOCKS5 proxy via Tor: apps that ignore the system proxy are not covered. Turn on System-wide mode (Linux) to cover every app; UDP such as QUIC and voice calls is then blocked, because Tor cannot carry it.'),
        _Bullet('Tor trades speed for anonymity, so expect lower speeds than a commercial VPN. Speeds shown are estimates until you connect.'),
        _Bullet('Exit relays are run by volunteers; the exit operator can see unencrypted traffic, so prefer HTTPS.'),
        _Bullet('The app only talks to Tor Project, IP-lookup and speed-test services. It has no accounts and no telemetry.'),
      ]);
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 6, right: 12), child: Icon(Icons.circle, size: 6, color: _amber)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, height: 1.45, fontSize: 13.5))),
        ]),
      );
}

class _LinkChip extends StatefulWidget {
  const _LinkChip({required this.icon, required this.label, required this.url, required this.color});
  final IconData icon;
  final String label, url;
  final Color color;
  @override
  State<_LinkChip> createState() => _LinkChipState();
}

class _LinkChipState extends State<_LinkChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => Plat.openUrl(widget.url),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.color.withValues(alpha: _hover ? 0.2 : 0.08),
              border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.9 : 0.35)),
              boxShadow: _hover ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 16)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 8),
              Text(widget.label, style: TextStyle(fontWeight: FontWeight.w700, color: widget.color, fontSize: 13)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_outward_rounded, size: 13, color: widget.color.withValues(alpha: 0.7)),
            ]),
          ),
        ),
      );
}

class _TechTile extends StatefulWidget {
  const _TechTile({required this.name, required this.desc, required this.license, required this.url});
  final String name, desc, license, url;
  @override
  State<_TechTile> createState() => _TechTileState();
}

class _TechTileState extends State<_TechTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => Plat.openUrl(widget.url),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: _hover ? 0.09 : 0.04),
              border: Border.all(color: _hover ? _violet.withValues(alpha: 0.7) : Colors.white10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.license, style: const TextStyle(fontSize: 10, color: _violet, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(widget.desc, style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4)),
            ]),
          ),
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.color, required this.title, required this.tagline, required this.points});
  final IconData icon;
  final Color color;
  final String title, tagline;
  final List<String> points;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          Text(tagline, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 6, right: 10), child: Icon(Icons.circle, size: 5, color: color)),
                Expanded(child: Text(p, style: const TextStyle(color: Colors.white60, height: 1.45, fontSize: 13))),
              ]),
            ),
        ]),
      );
}
