import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'legal_page.dart';
import 'platform.dart';
import 'top_icons.dart' show DragBar;

const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _violet = Color(0xFF7C9CFF), _red = Color(0xFFFF6B6B);

/// Slide + fade + slight scale route for the About page.
Route<void> aboutRoute(Widget windowDots, {Map<String, String> buildInfo = const {}}) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => AboutPage(windowDots: windowDots, buildInfo: buildInfo),
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
  const AboutPage({super.key, required this.windowDots, this.buildInfo = const {}});
  final Widget windowDots;

  /// Label -> value rows for "This build" (app version, Tor version, bridge mode).
  final Map<String, String> buildInfo;

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
              DragBar(child: Container(
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
              )),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
                      _stagger(0, _header()),
                      const SizedBox(height: 18),
                      if (widget.buildInfo.isNotEmpty) ...[
                        _stagger(1, _glass(Wrap(spacing: 28, runSpacing: 8, children: [
                          for (final e in widget.buildInfo.entries)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${e.key}: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                              SelectableText(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                        ]))),
                        const SizedBox(height: 18),
                      ],
                      _stagger(1, _authorCard()),
                      const SizedBox(height: 18),
                      _stagger(1, _contactCard()),
                      const SizedBox(height: 18),
                      _stagger(2, _section('How it works', Icons.account_tree_rounded, _teal, _howItWorks())),
                      const SizedBox(height: 18),
                      _stagger(3, _section('Modes & options', Icons.tune_rounded, _teal, _modes())),
                      const SizedBox(height: 18),
                      _stagger(4, _section('Open-source technology', Icons.code_rounded, _violet, _tech())),
                      const SizedBox(height: 18),
                      _stagger(5, _section('Good to know', Icons.info_outline_rounded, _amber, _notes())),
                      const SizedBox(height: 18),
                      _stagger(6, _section('Legal & privacy', Icons.gavel_rounded, _red, _legal())),
                      const SizedBox(height: 18),
                      _stagger(6, _aiNote()),
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
        const Text('OnionDesk', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        const Text('Pick a country. Browse through Tor or I2P. No account, no subscription.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
      ]);

  Widget _authorCard() => _glass(
        glow: _teal,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CREATED BY', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Sandip Bera', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('AI-Enabled Full-Stack Engineer  |  Backend Specialist', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _teal, height: 1.4)),
          const SizedBox(height: 8),
          const Text(
            '4+ years in Golang and Node.js, building microservices and distributed systems on PostgreSQL, shipped with Docker and cloud tooling. '
            'Works with AI-assisted development tools: Claude Code and Google Antigravity.',
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in const ['Golang', 'Node.js', 'Microservices', 'Distributed Systems', 'PostgreSQL', 'Docker & Cloud', 'Claude Code', 'Google Antigravity'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Text(t, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
              ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: const [
            _LinkChip(icon: Icons.code_rounded, label: 'GitHub', url: 'https://github.com/sandipbera35', color: Colors.white),
            _LinkChip(icon: Icons.language_rounded, label: 'sandipbera.in', url: 'https://sandipbera.in', color: _teal),
            _LinkChip(icon: Icons.work_rounded, label: 'LinkedIn', url: 'https://www.linkedin.com/in/sandipbera', color: _violet),
          ]),
        ]),
      );

  static const _contactEmail = 'sandipbera35@outlook.com';

  /// How to reach the author: bugs, ideas, suggestions, and joining as a contributor. Each chip opens a mail with the subject filled in.
  Widget _contactCard() => _glass(
        glow: _violet,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.mail_outline_rounded, size: 18, color: _violet),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Contact and contribute', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          const Text(
            'OnionDesk is open source and made by one person. Found a bug? Have an idea or a suggestion? Want to join as a contributor? Write to me. '
            'Tell me your system (Linux, Windows or macOS), the version from the "This build" line above, and what you did; for a bug, what you expected and what happened.',
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: const [
            _LinkChip(icon: Icons.bug_report_outlined, label: 'Report a bug', url: 'mailto:$_contactEmail?subject=OnionDesk%20bug%20report', color: _red),
            _LinkChip(icon: Icons.lightbulb_outline_rounded, label: 'Share an idea', url: 'mailto:$_contactEmail?subject=OnionDesk%20idea', color: _amber),
            _LinkChip(icon: Icons.chat_bubble_outline_rounded, label: 'Suggestion', url: 'mailto:$_contactEmail?subject=OnionDesk%20suggestion', color: _teal),
            _LinkChip(icon: Icons.group_add_outlined, label: 'Join as a contributor', url: 'mailto:$_contactEmail?subject=Contributing%20to%20OnionDesk', color: _violet),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.alternate_email_rounded, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            const Flexible(child: SelectableText(_contactEmail, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Copy the address',
              child: InkResponse(
                radius: 16,
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _contactEmail));
                  final m = ScaffoldMessenger.maybeOf(context);
                  m?.hideCurrentSnackBar();
                  m?.showSnackBar(const SnackBar(duration: Duration(milliseconds: 1400), behavior: SnackBarBehavior.floating, width: 240, content: Text('Copied')));
                },
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 15, color: Colors.white54)),
              ),
            ),
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
      ('Switch while connected', 'Changing country edits the torrc and reloads Tor while the proxy stays on, so traffic is meant to wait for a new circuit instead of going direct.'),
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

  /// Two columns of equal-height cards (rows are as tall as their tallest card), one column when narrow.
  Widget _grid(List<_ModeCard> cards) => LayoutBuilder(builder: (_, c) {
        if (c.maxWidth <= 640) {
          return Column(children: [for (final k in cards) Padding(padding: const EdgeInsets.only(bottom: 14), child: k)]);
        }
        return Column(children: [
          for (var i = 0; i < cards.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 14),
                  Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
                ]),
              ),
            ),
        ]);
      });

  Widget _modes() => _grid(const [
          _ModeCard(
            icon: Icons.public_rounded,
            color: _teal,
            title: 'OnionDesk Browser (BETA)',
            tagline: 'A real browser inside the app, wired to Tor and I2P.',
            points: [
              'Built on Chromium (CEF): modern sites, JavaScript and video. Tabs, a full view that fills the app window (F11), zoom, and an address bar that opens name.i2p directly.',
              'Nothing to set up: it uses whatever is connected. Normal sites go through Tor, .i2p sites through I2P, and anything else is refused, so it can never connect directly.',
              'Connect Tor in the Tor tab and/or start I2P in the I2P tab first. No Google traffic, no sync, no telemetry.',
              'Video plays without H.264/AAC (the open-source engine has no proprietary codecs). Linux x64 is tested; Windows and macOS are not yet.',
            ],
          ),
          _ModeCard(
            icon: Icons.blur_on_rounded,
            color: Color(0xFF22C55E),
            title: 'I2P network (BETA)',
            tagline: 'Reach .i2p sites through your own bundled i2pd router.',
            points: [
              'Start and stop a private i2pd router from the I2P tab; it is bundled, so there is nothing to install. The tab turns green when fully connected and shows peers, tunnels and bandwidth.',
              'I2P is a separate, small network for .i2p sites, forums and torrents. It has no country exits and does not make normal websites faster. A new router needs a few minutes to warm up, and many .i2p sites are offline.',
              'Your router does not relay other people\'s traffic unless you turn that on. It changes no system proxy or firewall, and closing the app stops it.',
            ],
          ),
          _ModeCard(
            icon: Icons.call_split_rounded,
            color: Color(0xFF22C55E),
            title: 'Split tunneling for I2P',
            tagline: 'Send chosen apps through I2P, with no proxy setup.',
            points: [
              'Add programs in the I2P tab and press Launch: each starts already set up for I2P. Browsers get a private profile.',
              'On Linux the app is also forced through I2P with a bundled preload shim, so even programs that ignore proxy settings are covered (not Flatpak/Snap, static or Go programs).',
              'Windows and macOS cover only apps that honour proxy settings. There is deliberately no system-wide I2P mode.',
            ],
          ),

          _ModeCard(
              icon: Icons.bolt_rounded,
              color: _amber,
              title: 'Auto (fastest location)',
              tagline: 'Always use the location with the highest speed.',
              points: [
                'Turn it on with the Auto chip inside the country box. The choice is remembered.',
                'Ranks countries by speed: your own measured speed through Tor when you have one, otherwise a live estimate from round-trip time and relay bandwidth, refreshed every minute.',
                'Disconnected: the fastest country is pre-selected, and Connect uses it.',
                'Connected: it switches only if another location is at least 25% faster, and at most once every 5 minutes, so it does not bounce around.',
                'Switching is designed to keep Tor and the proxy up, so your real IP is not meant to be exposed while it changes.',
              ],
          ),
          _ModeCard(
              icon: Icons.shield_rounded,
              color: _teal,
              title: 'System-wide (Linux)',
              tagline: 'Send every app\'s traffic through Tor, not just proxy-aware ones.',
              points: [
                'Optional and off by default. Works on GNOME, KDE and other desktops.',
                'Asks for your administrator password once when you connect, then adds nftables rules that redirect all TCP and DNS into Tor.',
                'Tor itself runs as a separate "oniondesk" user so its own traffic is not redirected.',
                'UDP (QUIC/HTTP3, games, voice calls) and IPv6 are blocked, because Tor cannot carry them. Local-network addresses stay direct.',
                'Disconnecting or closing the app restores normal networking. If Tor crashes, traffic stays blocked until you press Restore, so it is not sent around Tor.',
                'Off: only apps that use the system proxy (SOCKS5 127.0.0.1:9050) go through Tor.',
              ],
          ),
          _ModeCard(
              icon: Icons.fingerprint_rounded,
              color: _teal,
              title: 'New identity & auto-rotate',
              tagline: 'A fresh relay in the same country, on demand or on a timer.',
              points: [
                'Press New identity (beside the Ad blocker chip) to switch to a different relay in your chosen country. Open browser connections are moved too, so sites really see the new IP.',
                'Auto-rotate (Settings) does the same every 5, 10, 30 or 60 minutes.',
                'The country stays pinned (StrictNodes) and the proxy stays up, so nothing is meant to go direct while it changes. Tor limits this to about once every 10 seconds.',
              ],
          ),
          _ModeCard(
              icon: Icons.hub_outlined,
              color: _violet,
              title: 'Circuit visualizer',
              tagline: 'See the path your traffic takes, drawn on the map.',
              points: [
                'While connected the map draws you → guard → middle → exit, with a label for the guard and middle country.',
                'Open Circuits on the map to list your active circuits, the sites using each one, and highlight any of them.',
                'Everything is read from Tor\'s own control port and its bundled GeoIP file, so it works offline and where Tor Project web services are blocked. Countries only, never street addresses.',
              ],
          ),
          _ModeCard(
              icon: Icons.alt_route_rounded,
              color: _amber,
              title: 'Bridges',
              tagline: 'For networks that block Tor.',
              points: [
                'Settings → Bridges: obfs4, Snowflake, meek (looks like a CDN) or your own bridge lines from bridges.torproject.org.',
                'Uses the lyrebird transport bundled with Tor (Linux x64, Windows, macOS). Not yet on Linux arm64, and not combinable with System-wide mode.',
                'Bridges are slower; Snowflake needs the most patience. Direct relay probes are switched off while a bridge is used.',
              ],
          ),
          _ModeCard(
              icon: Icons.shield_outlined,
              color: _teal,
              title: 'Leak test',
              tagline: 'Check for common leaks.',
              points: [
                'Settings → Tools → Leak test (while connected) checks that sites see a Tor exit and not your real IP, that names are resolved inside Tor, and whether apps that ignore the proxy are covered.',
                'WebRTC cannot be tested from a desktop app; the result tells you which browser setting to change.',
              ],
          ),
          _ModeCard(
              icon: Icons.call_split_rounded,
              color: _violet,
              title: 'Split tunneling (per app)',
              tagline: 'Run chosen apps through Tor.',
              points: [
                'Settings → Tools → Split tunneling lists your installed apps (Linux .desktop files incl. Flatpak and Snap, macOS Applications, Windows Start Menu).',
                'The app starts with OnionDesk\'s proxy set. Browsers get a private profile with remote DNS and WebRTC off. On Linux, torsocks (if installed) also forces apps that ignore proxy settings.',
                'Windows and macOS cannot force such apps; for full coverage use System-wide mode (Linux). Kernel-level per-app routing (WFP, namespaces, Network Extensions) is not implemented.',
              ],
          ),
          _ModeCard(
              icon: Icons.block_flipped,
              color: _amber,
              title: 'Exclude countries',
              tagline: 'Never exit from countries you choose.',
              points: [
                'Settings → Exclude countries, with Five, Nine and Fourteen Eyes presets.',
                'Excluded countries cannot be selected and Auto never picks them.',
              ],
          ),
          _ModeCard(
              icon: Icons.block,
              color: _teal,
              title: 'Ad blocker',
              tagline: 'Block known ad and tracker domains.',
              points: [
                'Off by default. A small built-in list plus, if you download it in Settings, the full StevenBlack list (about 72,000 domains, MIT licence). Remove it any time.',
                'Works for apps that use the proxy and send hostnames; apps that resolve names themselves are not covered. Not available in System-wide mode yet.',
              ],
          ),
          _ModeCard(
              icon: Icons.settings_rounded,
              color: _violet,
              title: 'Settings, languages & updates',
              tagline: 'Everything is remembered between launches.',
              points: [
                'Six languages: English, हिन्दी, বাংলা, Español, العربية (right-to-left), Русский. Your choice, location and settings are saved.',
                'Optional: start at login (opens minimised) and connect on launch. Both are off by default.',
                'Update notice: checks GitHub releases now and then and tells you when a new version exists; nothing is installed automatically. You can turn it off.',
                'Expand the map to fill the window with the button in its corner.',
              ],
          ),
      ]);

  Widget _tech() {
    const items = [
      ('Tor', 'The anonymity network and the tor client that does the routing', 'BSD-3-Clause', 'https://www.torproject.org'),
      ('Flutter & Dart', 'UI toolkit and language the whole app is written in', 'BSD-3-Clause', 'https://flutter.dev'),
      ('i2pd', 'The I2P router bundled for the I2P tab (separate program)', 'BSD-3-Clause', 'https://i2pd.website'),
      ('Chromium (CEF)', 'Browser engine of OnionDesk Browser (Chromium Embedded Framework)', 'BSD-3-Clause', 'https://bitbucket.org/chromiumembedded/cef'),
      ('webview_cef', 'Flutter plugin that embeds CEF (patched copy in this app)', 'Apache-2.0', 'https://github.com/hlwhl/webview_cef'),
      ('proxychains-ng', 'Forces apps through I2P on Linux (separate preload library)', 'GPL-2.0+', 'https://github.com/rofl0r/proxychains-ng'),
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

  /// Deliberately tiny: one muted line.
  Widget _aiNote() => const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: Colors.white30),
          SizedBox(width: 6),
          Flexible(child: Text('Built with AI assistance (Claude Code, OpenCode); directed, reviewed and tested by the author.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 11))),
        ]),
      );

  Widget _legal() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Bullet('OnionDesk is an independent project, not made, endorsed or sponsored by the Tor Project, the I2P projects, Google or the Chromium project. Tor and the onion logo are trademarks of The Tor Project, Inc.; other names belong to their owners.'),
        const _Bullet('Provided "as is" under the Apache License 2.0: no warranty and no liability. It does not guarantee anonymity, security, speed or availability. Beta features (I2P, OnionDesk Browser, system-wide mode) may contain bugs and have not been independently audited.'),
        const _Bullet('Use it lawfully. Some countries restrict privacy and circumvention tools; you are responsible for following the laws that apply to you and the terms of the services you use. This is not legal advice.'),
        const SizedBox(height: 4),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < kLegalDocs.length; i++)
            _PageChip(icon: kLegalDocs[i].icon, label: kLegalDocs[i].title, color: kLegalDocs[i].color, onTap: () => Navigator.of(context).push(legalRoute(widget.windowDots, tab: i))),
        ]),
      ]);

  Widget _notes() => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Bullet('By default this is a local SOCKS5 proxy via Tor: apps that ignore the system proxy are not covered. Turn on System-wide mode (Linux) to cover every app; UDP such as QUIC and voice calls is then blocked, because Tor cannot carry it.'),
        _Bullet('Tor trades speed for privacy, so expect lower speeds than a commercial VPN. OnionDesk does not guarantee anonymity. Speeds shown are estimates until you connect.'),
        _Bullet('I2P and OnionDesk Browser are BETA. I2P is a small, slow network of its own, and the browser has no direct connection: it works only while Tor and/or I2P is connected.'),
        _Bullet('Exit relays are run by volunteers; the exit operator can see unencrypted traffic, so prefer HTTPS. When you are not connected, your real IP is looked up directly by third-party services (see the privacy policy).'),
        _Bullet('The app talks to the Tor network, the Tor Project relay directory, I2P reseed and address-book servers (when I2P is on), IP-lookup and speed-test services, and GitHub (update notice, and the optional ad list). The author collects nothing (no accounts, no telemetry), but the app does contact third-party services such as IP lookup; see the privacy policy. The update check can be turned off in Settings.'),
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

/// Like [_LinkChip] but opens a page inside the app.
class _PageChip extends StatelessWidget {
  const _PageChip({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: color.withValues(alpha: 0.08), border: Border.all(color: color.withValues(alpha: 0.35))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 15, color: color.withValues(alpha: 0.7)),
            ]),
          ),
        ),
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
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Text(tagline, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35)),
          const SizedBox(height: 4),
          Divider(height: 18, color: color.withValues(alpha: 0.18)),
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
