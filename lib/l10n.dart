import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' show TextAlign, TextOverflow, TextStyle, ValueListenableBuilder, Widget, StatelessWidget, BuildContext;

import 'l10n_strings.dart';

/// Light-weight translations: the English text itself is the key, so an untranslated string simply stays English.
/// Keys may contain `{0}`, `{1}` placeholders to match text with values in it ("Exit in {0}"). Nothing here touches
/// logic, only what is drawn.

const kLanguages = <String, String>{
  'en': 'English',
  'hi': 'हिन्दी',
  'bn': 'বাংলা',
  'es': 'Español',
  'ar': 'العربية',
  'ru': 'Русский',
};

const kRtl = {'ar'};

class L10n {
  static final ValueNotifier<String> lang = ValueNotifier<String>('en');

  /// The language of the operating system if we have it, else English.
  static String systemLanguage([String? localeName]) {
    final code = (localeName ?? (kIsWeb ? 'en' : Platform.localeName)).split(RegExp(r'[_\-.]')).first.toLowerCase();
    return kLanguages.containsKey(code) ? code : 'en';
  }

  static void set(String code) {
    if (kLanguages.containsKey(code)) lang.value = code;
  }

  static final Map<String, List<(RegExp, String)>> _patterns = {};
  static final Set<String> missing = {}; // filled when ONIONDESK_L10N_DUMP is set, for building the tables

  static List<(RegExp, String)> _patternsFor(String code) => _patterns.putIfAbsent(code, () {
        final table = kTranslations[code] ?? const {};
        return [
          for (final e in table.entries)
            if (e.key.contains('{'))
              (RegExp('^${RegExp.escape(e.key).replaceAllMapped(RegExp(r'\\\{(\d)\\\}'), (_) => '(.+?)')}\$', dotAll: true), e.value),
        ];
      });

  /// Translate [s] for [code] (default: current language).
  static String tr(String s, [String? code]) {
    code ??= lang.value;
    if (_dump && s.trim().length > 2 && RegExp(r'[A-Za-z]{3}').hasMatch(s) && (code == 'en' || kTranslations[code]?[s] == null)) missing.add(s);
    if (code == 'en' || s.isEmpty) return s;
    final table = kTranslations[code];
    final exact = table?[s];
    if (exact != null) return exact;
    for (final (re, tpl) in _patternsFor(code)) {
      final mt = re.firstMatch(s);
      if (mt != null) {
        var out = tpl;
        for (var i = 0; i < mt.groupCount; i++) { out = out.replaceAll('{$i}', mt.group(i + 1)!); }
        return out;
      }
    }
    return s;
  }

  static final bool _dump = !kIsWeb && Platform.environment['ONIONDESK_L10N_DUMP'] != null;
}

/// Drop-in for Flutter's `Text` (same names for what this app uses) that translates its string and rebuilds when
/// the language changes.
class Text extends StatelessWidget {
  const Text(this.data, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap});
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: L10n.lang,
        builder: (_, code, _) => m.Text(L10n.tr(data, code), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, softWrap: softWrap),
      );
}
