import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'l10n.dart';
import 'top_icons.dart' show DragBar;
import 'update_check.dart' show kAppVersion;

const _teal = Color(0xFF2DE2C4), _violet = Color(0xFF7C9CFF);

/// Everything the settings page reads and changes. The home page owns the state and persistence; the page only
/// shows it, so there is one source of truth. [listenable] fires when any value changes.
class SettingsActions {
  SettingsActions({
    required this.listenable,
    required this.lang,
    required this.setLang,
    required this.startAtLogin,
    required this.toggleStartAtLogin,
    required this.connectOnLaunch,
    required this.toggleConnectOnLaunch,
    required this.checkUpdates,
    required this.toggleCheckUpdates,
    required this.checkNow,
    required this.rotateMin,
    required this.setRotate,
    required this.bridgeSummary,
    required this.editBridges,
    required this.excludedCount,
    required this.editExcluded,
    required this.adBlock,
    required this.adBlockLocked,
    required this.toggleAdBlock,
    required this.downloadAdList,
    required this.adListStatus,
    required this.adListBusy,
    required this.adListInstalled,
    required this.removeAdList,
    required this.running,
    required this.runLeakTest,
    required this.runSplitTunnel,
    required this.languages,
    required this.notifications,
    required this.toggleNotifications,
    required this.lightTheme,
    required this.toggleLightTheme,
    this.onUninstall,
    required this.exportSettings,
    required this.importSettings,
  });
  final Listenable listenable;
  final String Function() lang;
  final void Function(String code) setLang;
  final Map<String, String> languages;
  final bool Function() startAtLogin, connectOnLaunch, checkUpdates, adBlock, adBlockLocked;
  final VoidCallback toggleStartAtLogin, toggleConnectOnLaunch, toggleCheckUpdates, checkNow, editBridges, editExcluded, toggleAdBlock, downloadAdList;
  final int Function() rotateMin, excludedCount;
  final void Function(int minutes) setRotate;
  final String Function() bridgeSummary, adListStatus;
  final bool Function() adListBusy, adListInstalled, running;
  final VoidCallback removeAdList, runLeakTest, runSplitTunnel;
  final bool Function() notifications;
  final VoidCallback toggleNotifications;
  final bool Function() lightTheme;
  final VoidCallback toggleLightTheme;

  /// Null where uninstalling from the app is not supported (macOS): the card is hidden.
  final VoidCallback? onUninstall;

  /// Both open a file chooser. Export: the saved path, null if cancelled, "!message" on failure.
  /// Import: null if cancelled, "" on success, otherwise the reason it failed.
  final Future<String?> Function() exportSettings, importSettings;
}

Route<void> settingsRoute(Widget windowDots, SettingsActions actions) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => SettingsPage(windowDots: windowDots, actions: actions),
      transitionsBuilder: (_, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
        return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(c), child: child));
      },
    );

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.windowDots, required this.actions});
  final Widget windowDots;
  final SettingsActions actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D1A), Color(0xFF0E1830), Color(0xFF070D1A)])),
          child: Stack(children: [
            _blob(const Alignment(-1, -1), _teal, 520),
            _blob(const Alignment(1, 1), const Color(0xFF7C5CFF), 560),
            Column(children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: DragBar(child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    windowDots,
                    const Spacer(),
                    TextButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Close')),
                  ]),
                )),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: AnimatedBuilder(
                      animation: actions.listenable,
                      builder: (_, _) => ListView(padding: const EdgeInsets.fromLTRB(24, 4, 24, 32), children: [
                        Row(children: [
                          const Icon(Icons.settings_rounded, color: _teal, size: 26),
                          const SizedBox(width: 10),
                          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 16),
                        _card('General', Icons.tune_rounded, _teal, [
                          _row(Icons.language_rounded, 'Language', null, trailing: _languageMenu(context)),
                          _switch(Icons.login_rounded, 'Start OnionDesk when I log in', 'Opens minimised. It does not connect unless you also turn on the next option.', actions.startAtLogin(), actions.toggleStartAtLogin),
                          _switch(Icons.bolt_rounded, 'Connect automatically on launch', 'Connects with your last location as soon as the app is up.', actions.connectOnLaunch(), actions.toggleConnectOnLaunch),
                          _switch(Icons.system_update_alt_rounded, 'Check for updates automatically', 'Asks GitHub for the latest release now and then. Nothing is installed automatically.', actions.checkUpdates(), actions.toggleCheckUpdates),
                          _switch(Icons.notifications_active_outlined, 'Desktop notifications', 'Tell me when the connection drops, or when Auto-fastest / auto-rotate changes my exit.', actions.notifications(), actions.toggleNotifications),
                          _switch(Icons.light_mode_rounded, 'Light theme', 'Switch the app from the dark look to a light one.', actions.lightTheme(), actions.toggleLightTheme),
                          _row(Icons.refresh_rounded, 'Check for updates now', 'Version $kAppVersion', trailing: _button('Check', actions.checkNow)),
                        ]),
                        const SizedBox(height: 16),
                        _card('Backup', Icons.save_alt_rounded, _violet, [
                          _row(Icons.upload_file_rounded, 'Export settings', 'Choose where to save a JSON file with your language, favorites, exclusions and toggles. Bridge lines are never exported.', trailing: _button('Export', () async {
                            final r = await actions.exportSettings();
                            if (r == null || !context.mounted) return;
                            _toast(context, r.startsWith('!') ? r.substring(1) : 'Saved to $r');
                          })),
                          _row(Icons.download_for_offline_rounded, 'Import settings', 'Choose a JSON file you exported before. Only known options are applied. Disconnect first.', trailing: _button('Import', () async {
                            final r = await actions.importSettings();
                            if (r == null || !context.mounted) return;
                            _toast(context, r.isEmpty ? 'Settings imported.' : r);
                          })),
                        ]),
                        const SizedBox(height: 16),
                        _card('Connection', Icons.alt_route_rounded, _violet, [
                          _row(Icons.autorenew_rounded, 'Auto-rotate', 'Switch to a fresh relay in the same country on a timer.', trailing: _rotateMenu(context)),
                          _row(Icons.alt_route_rounded, 'Bridges', 'Use a bridge when your network blocks Tor.', trailing: _button(actions.bridgeSummary(), actions.editBridges)),
                          _row(Icons.block_flipped, 'Exclude countries', 'Auto never uses them and they cannot be selected.', trailing: _button(actions.excludedCount() == 0 ? 'None' : '${actions.excludedCount()}', actions.editExcluded)),
                        ]),
                        const SizedBox(height: 16),
                        _card('Tools', Icons.handyman_rounded, _violet, [
                          _row(Icons.shield_outlined, 'Leak test', actions.running() ? 'Check that your real IP and DNS do not leak' : 'Connect first', trailing: _button('Run', actions.running() ? actions.runLeakTest : null)),
                          _row(Icons.call_split_rounded, 'Split tunneling', actions.running() ? 'Run chosen apps through Tor: pick from your installed apps' : 'Connect first', trailing: _button('Choose app…', actions.running() ? actions.runSplitTunnel : null)),
                        ]),
                        const SizedBox(height: 16),
                        _card('Privacy & blocking', Icons.shield_outlined, _teal, [
                          _switch(Icons.block, 'Ad blocker', actions.adBlockLocked() ? 'Disconnect to change this' : 'Block known ad and tracker domains for apps using the proxy', actions.adBlock(), actions.adBlockLocked() ? null : actions.toggleAdBlock),
                          _row(Icons.download_rounded, 'Download the full ad-block list (StevenBlack, MIT)', actions.adListStatus(),
                              trailing: actions.adListBusy()
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: _teal))
                                  : (actions.adListInstalled() ? _button('Remove', actions.removeAdList) : _button('Download', actions.downloadAdList))),
                        ]),
                        if (actions.onUninstall != null) ...[
                          const SizedBox(height: 16),
                          _card('Uninstall', Icons.delete_outline_rounded, const Color(0xFFFF6B6B), [
                            _row(Icons.delete_outline_rounded, 'Uninstall OnionDesk', 'Removes the app, its system helper and (if you choose) your settings from this computer. You will be asked to confirm.',
                                trailing: OutlinedButton(
                                  onPressed: actions.onUninstall,
                                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B), side: BorderSide(color: const Color(0xFFFF6B6B).withValues(alpha: 0.6)), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 14)),
                                  child: const Text('Uninstall…'),
                                )),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _blob(Alignment a, Color c, double size) => Align(
        alignment: a,
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0)]))),
      );

  Widget _card(String title, IconData icon, Color color, List<Widget> rows) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.025)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color))]),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)), rows[i]],
        ]),
      );

  Widget _row(IconData icon, String title, String? sub, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3))),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ]),
      );

  Widget _switch(IconData icon, String title, String sub, bool value, VoidCallback? onTap) => _row(icon, title, sub,
      trailing: Switch(value: value, onChanged: onTap == null ? null : (_) => onTap(), activeThumbColor: _teal, activeTrackColor: _teal.withValues(alpha: 0.35)));

  Widget _button(String label, VoidCallback? onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 14)),
        child: Text(label),
      );

  Widget _languageMenu(BuildContext context) => PopupMenuButton<String>(
        color: const Color(0xFF16233A),
        onSelected: actions.setLang,
        itemBuilder: (_) => [for (final e in actions.languages.entries) CheckedPopupMenuItem(value: e.key, checked: actions.lang() == e.key, child: m.Text(e.value))],
        child: IgnorePointer(child: _button(actions.languages[actions.lang()]!, () {})),
      );

  void _toast(BuildContext context, String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));
  }

  Widget _rotateMenu(BuildContext context) => PopupMenuButton<int>(
        color: const Color(0xFF16233A),
        onSelected: actions.setRotate,
        itemBuilder: (_) => [for (final m in const [0, 5, 10, 30, 60]) CheckedPopupMenuItem(value: m, checked: actions.rotateMin() == m, child: Text(m == 0 ? 'Off' : 'Every $m min'))],
        child: IgnorePointer(child: _button(actions.rotateMin() == 0 ? L10n.tr('Off') : L10n.tr('Every ${actions.rotateMin()} min'), () {})),
      );
}
