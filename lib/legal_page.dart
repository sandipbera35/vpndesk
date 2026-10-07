import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'platform.dart';
import 'top_icons.dart' show DragBar;

const _teal = Color(0xFF2DE2C4), _violet = Color(0xFF7C9CFF), _amber = Color(0xFFFFC857);

/// One block of a legal document, parsed from the small Markdown subset the repository's legal files use.
sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.text);
  final int level;
  final String text;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

class LegalBullet extends LegalBlock {
  const LegalBullet(this.text);
  final String text;
}

/// A table row, shown as a card: [title] is the first column, [fields] are "Header" -> value for the other columns.
class LegalRow extends LegalBlock {
  const LegalRow(this.title, this.fields);
  final String title;
  final List<(String, String)> fields;
}

/// Parses headings (#, ##, ###), bullets (- ), tables (| a | b |) and paragraphs. Inline `**bold**`, `_italic_`, `code`
/// and [links](url) are handled when drawing. Anything else is plain paragraph text.
List<LegalBlock> parseLegalMarkdown(String src) {
  final out = <LegalBlock>[];
  final para = <String>[];
  List<String>? header;
  void flush() {
    if (para.isNotEmpty) out.add(LegalParagraph(para.join(' ')));
    para.clear();
  }

  List<String> cells(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }

  for (final raw in src.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
      header = null;
      continue;
    }
    final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (h != null) {
      flush();
      out.add(LegalHeading(h.group(1)!.length, h.group(2)!));
      continue;
    }
    if (line.trimLeft().startsWith('|')) {
      flush();
      final c = cells(line);
      if (c.every((x) => RegExp(r'^:?-{2,}:?$').hasMatch(x))) continue; // the |---|---| line
      if (header == null) {
        header = c;
      } else if (c.isNotEmpty) {
        out.add(LegalRow(c.first, [for (var i = 1; i < c.length; i++) (i < header.length ? header[i] : '', c[i])]));
      }
      continue;
    }
    if (line.startsWith('- ')) {
      flush();
      out.add(LegalBullet(line.substring(2)));
      continue;
    }
    para.add(line.trim());
  }
  flush();
  return out;
}

class LegalDoc {
  const LegalDoc(this.title, this.icon, this.color, this.assets, {this.plainLast = false});
  final String title;
  final IconData icon;
  final Color color;
  final List<String> assets;

  /// The last asset is plain text (a license), not Markdown.
  final bool plainLast;
}

const kLegalDocs = [
  LegalDoc('Privacy policy', Icons.privacy_tip_outlined, _teal, ['PRIVACY.md']),
  LegalDoc('Legal notices', Icons.gavel_rounded, _amber, ['LEGAL.md']),
  LegalDoc('Security', Icons.security_rounded, _violet, ['SECURITY.md']),
  LegalDoc('Licenses', Icons.description_outlined, Colors.white, ['THIRD_PARTY_NOTICES.md', 'LICENSE'], plainLast: true),
];

Route<void> legalRoute(Widget windowDots, {int tab = 0}) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => LegalPage(windowDots: windowDots, initialTab: tab),
      transitionsBuilder: (_, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
        return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(c), child: child));
      },
    );

/// The privacy policy, legal notices, security policy and licenses, read from the same files as the repository.
class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.windowDots, this.initialTab = 0, this.loader});
  final Widget windowDots;
  final int initialTab;

  /// Test hook: how an asset is loaded (defaults to the app's asset bundle).
  final Future<String> Function(String asset)? loader;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late int _tab = widget.initialTab.clamp(0, kLegalDocs.length - 1);
  final _cache = <int, List<LegalBlock>>{};
  final _plain = <int, String>{};
  final _links = <TapGestureRecognizer>[];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  @override
  void dispose() {
    for (final r in _links) {
      r.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int i) async {
    if (_cache.containsKey(i)) return;
    final doc = kLegalDocs[i];
    final load = widget.loader ?? rootBundle.loadString;
    try {
      final md = <LegalBlock>[];
      for (var k = 0; k < doc.assets.length; k++) {
        final text = await load(doc.assets[k]);
        if (doc.plainLast && k == doc.assets.length - 1) {
          _plain[i] = text;
        } else {
          if (k > 0) md.add(const LegalHeading(2, ''));
          md.addAll(parseLegalMarkdown(text));
        }
      }
      if (mounted) setState(() => _cache[i] = md);
    } catch (e) {
      if (mounted) setState(() => _cache[i] = [LegalParagraph('This text could not be loaded ($e). It is also at https://github.com/sandipbera35/vpndesk')]);
    }
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _load(i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final doc = kLegalDocs[_tab];
    final blocks = _cache[_tab];
    for (final r in _links) {
      r.dispose();
    }
    _links.clear();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D1A), Color(0xFF0E1830), Color(0xFF070D1A)])),
        child: Column(children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: DragBar(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  widget.windowDots,
                  const Spacer(),
                  TextButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Close')),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(doc.icon, color: doc.color, size: 26),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Privacy & legal', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var i = 0; i < kLegalDocs.length; i++) _tabChip(i),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: blocks == null
                          ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: _teal)))
                          : SelectionArea(
                              child: ListView(controller: _scroll, padding: const EdgeInsets.only(bottom: 32), children: [
                                for (final b in blocks) _block(b, doc.color),
                                if (_plain[_tab] != null) Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withValues(alpha: 0.04), border: Border.all(color: Colors.white10)),
                                    child: Text(_plain[_tab]!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4, color: Colors.white60)),
                                  ),
                                ),
                              ]),
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabChip(int i) {
    final d = kLegalDocs[i];
    final on = i == _tab;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _select(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: d.color.withValues(alpha: on ? 0.18 : 0.05),
          border: Border.all(color: d.color.withValues(alpha: on ? 0.8 : 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(d.icon, size: 15, color: d.color),
          const SizedBox(width: 7),
          Text(d.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? d.color : Colors.white70)),
        ]),
      ),
    );
  }

  Widget _block(LegalBlock b, Color accent) => switch (b) {
        LegalHeading(:final level, :final text) => text.isEmpty
            ? const SizedBox(height: 18)
            : Padding(
                padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 6),
                child: Text(text, style: TextStyle(fontSize: level == 1 ? 21 : (level == 2 ? 16.5 : 14.5), fontWeight: FontWeight.w800, color: level == 1 ? Colors.white : accent)),
              ),
        LegalParagraph(:final text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _rich(text, 13.5, Colors.white70)),
        LegalBullet(:final text) => Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 5, color: accent)),
              Expanded(child: _rich(text, 13.5, Colors.white70)),
            ]),
          ),
        LegalRow(:final title, :final fields) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withValues(alpha: 0.04), border: Border.all(color: Colors.white10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _rich(title, 13.5, Colors.white, bold: true),
              for (final f in fields) ...[
                const SizedBox(height: 4),
                Text.rich(TextSpan(children: [
                  if (f.$1.isNotEmpty) TextSpan(text: '${f.$1}: ', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ..._inline(f.$2, 12.5, Colors.white60),
                ])),
              ],
            ]),
          ),
      };

  Widget _rich(String text, double size, Color color, {bool bold = false}) =>
      Text.rich(TextSpan(children: _inline(text, size, color, bold: bold)), style: TextStyle(height: 1.5, fontSize: size, color: color));

  /// `**bold**`, `_italic_`, `code` and [text](url).
  List<InlineSpan> _inline(String t, double size, Color color, {bool bold = false}) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|(?<![\w])_([^_]+)_(?![\w])');
    var at = 0;
    for (final m in re.allMatches(t)) {
      if (m.start > at) spans.add(TextSpan(text: t.substring(at, m.start), style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: TextStyle(fontFamily: 'monospace', fontSize: size - 1, color: _teal)));
      } else if (m.group(3) != null) {
        final url = m.group(4)!;
        final r = TapGestureRecognizer()..onTap = () => Plat.openUrl(url.startsWith('http') || url.startsWith('mailto:') ? url : 'https://github.com/sandipbera35/vpndesk/blob/main/$url');
        _links.add(r);
        spans.add(TextSpan(text: m.group(3), style: const TextStyle(color: _teal, decoration: TextDecoration.underline), recognizer: r));
      } else {
        spans.add(TextSpan(text: m.group(5), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      at = m.end;
    }
    if (at < t.length) spans.add(TextSpan(text: t.substring(at), style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null));
    return spans;
  }
}
