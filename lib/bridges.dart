import 'dart:convert';
import 'dart:io';

/// Bridges / pluggable transports for networks that block Tor. Tor Expert Bundle ships `lyrebird` (obfs4, meek,
/// webtunnel and snowflake) and a `pt_config.json` with its recommended transport lines and default bridges; this
/// file turns the user's choice into torrc lines. Pure and tested; the app only passes in paths.

enum BridgeMode { none, obfs4, snowflake, meek, custom }

const bridgeLabels = <BridgeMode, String>{
  BridgeMode.none: 'No bridge (direct to Tor)',
  BridgeMode.obfs4: 'obfs4 (built-in bridges)',
  BridgeMode.snowflake: 'Snowflake',
  BridgeMode.meek: 'meek (looks like a CDN)',
  BridgeMode.custom: 'My own bridges',
};

BridgeMode bridgeModeFrom(Object? v) => BridgeMode.values.firstWhere((m) => m.name == v, orElse: () => BridgeMode.none);

class PtConfig {
  PtConfig(this.plugins, this.bridges);
  final Map<String, String> plugins; // name -> "ClientTransportPlugin ... exec ${pt_path}lyrebird"
  final Map<String, List<String>> bridges; // meek / obfs4 / snowflake -> bridge lines
}

PtConfig? parsePtConfig(String text) {
  try {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final plugins = {for (final e in (j['pluggableTransports'] as Map).entries) e.key as String: e.value as String};
    final bridges = {for (final e in (j['bridges'] as Map).entries) e.key as String: [for (final l in e.value as List) l as String]};
    return PtConfig(plugins, bridges);
  } catch (_) {
    return null;
  }
}

/// Where the bundled transports live (`<tor>/pluggable_transports`), or null if this install has none
/// (system tor, or a build without them).
Directory? ptDirectory(Directory? torDir) {
  if (torDir == null) return null;
  final d = Directory('${torDir.path}/pluggable_transports');
  final lyre = File('${d.path}/lyrebird${Platform.isWindows ? '.exe' : ''}');
  return lyre.existsSync() ? d : null;
}

const _transports = {'obfs4', 'meek_lite', 'snowflake', 'webtunnel', 'obfs3', 'scramblesuit'};

/// Problems with the user's own bridge lines (one per line, optionally prefixed with `Bridge `). Empty = fine.
/// Strict on purpose: each accepted line is copied into the torrc, so nothing else may get through.
List<String> validateBridgeLines(String text) {
  final problems = <String>[];
  var n = 0;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    n++;
    final l = line.replaceFirst(RegExp(r'^Bridge\s+', caseSensitive: false), '');
    if (l.length > 1500 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(l)) {
      problems.add('Line $n: contains control characters or is too long');
      continue;
    }
    final first = l.split(RegExp(r'\s+')).first;
    final isAddr = RegExp(r'^(\d{1,3}(\.\d{1,3}){3}|\[[0-9A-Fa-f:]+\]):\d{1,5}$').hasMatch(first);
    if (!_transports.contains(first) && !isAddr) problems.add('Line $n: must start with a transport (obfs4, snowflake, meek_lite, webtunnel) or IP:port');
  }
  if (n == 0) problems.add('Paste at least one bridge line');
  return problems;
}

String _firstWord(String l) => l.trim().replaceFirst(RegExp(r'^Bridge\s+', caseSensitive: false), '').split(RegExp(r'\s+')).first;

/// torrc lines for [mode]; '' when no bridges. [ptPath] is the pluggable_transports folder with forward slashes.
/// Throws [ArgumentError] with a readable message if the choice cannot work.
String bridgeTorrc(BridgeMode mode, PtConfig? cfg, String? ptPath, {String custom = ''}) {
  if (mode == BridgeMode.none) return '';
  if (cfg == null || ptPath == null) throw ArgumentError('Bridges are not available in this install (the transports are not bundled).');
  if (ptPath.contains(' ')) throw ArgumentError('Bridges need an install path without spaces (found: $ptPath).');
  final prefix = ptPath.endsWith('/') ? ptPath : '$ptPath/';
  String plugin(String name) {
    final t = cfg.plugins[name];
    if (t == null) throw ArgumentError('This build has no "$name" transport.');
    return t.replaceAll(r'${pt_path}', prefix);
  }

  final plugins = <String>{};
  final lines = <String>[];
  switch (mode) {
    case BridgeMode.obfs4:
      plugins.add(plugin('lyrebird'));
      lines.addAll(cfg.bridges['obfs4'] ?? const []);
    case BridgeMode.meek:
      plugins.add(plugin('lyrebird'));
      lines.addAll(cfg.bridges['meek'] ?? const []);
    case BridgeMode.snowflake:
      plugins.add(plugin('snowflake'));
      lines.addAll(cfg.bridges['snowflake'] ?? const []);
    case BridgeMode.custom:
      final bad = validateBridgeLines(custom);
      if (bad.isNotEmpty) throw ArgumentError(bad.first);
      for (final raw in custom.split('\n')) {
        final l = raw.trim().replaceFirst(RegExp(r'^Bridge\s+', caseSensitive: false), '');
        if (l.isEmpty || l.startsWith('#')) continue;
        lines.add(l);
        plugins.add(plugin(_firstWord(l) == 'snowflake' ? 'snowflake' : 'lyrebird'));
      }
    case BridgeMode.none:
      return '';
  }
  if (lines.isEmpty) throw ArgumentError('No bridge lines available for ${mode.name}.');
  return 'UseBridges 1\n${plugins.map((p) => '$p\n').join()}${lines.map((l) => 'Bridge $l\n').join()}';
}
