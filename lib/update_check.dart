// Update notice: compares this build with the latest GitHub release. Pure helpers; the HTTP call lives in main.dart.

/// Keep equal to `version:` in pubspec.yaml (a test enforces it, so a release cannot forget).
const kAppVersion = '1.3.0';

const kReleasesApi = 'https://api.github.com/repos/sandipbera35/vpndesk/releases/latest';

List<int>? _parts(String v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
  return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// True only when [latest] is a strictly higher x.y.z than [current]; anything unparsable is "not newer".
bool isNewer(String current, String latest) {
  final c = _parts(current), l = _parts(latest);
  if (c == null || l == null) return false;
  for (var i = 0; i < 3; i++) {
    if (l[i] != c[i]) return l[i] > c[i];
  }
  return false;
}

class UpdateInfo {
  const UpdateInfo(this.version, this.url);
  final String version, url;
}

/// From the `releases/latest` JSON: null for drafts, pre-releases, malformed answers or no newer version.
UpdateInfo? parseLatest(Map<String, dynamic> j, String current) {
  if (j['draft'] == true || j['prerelease'] == true) return null;
  final tag = j['tag_name'];
  final url = j['html_url'];
  if (tag is! String || url is! String || !url.startsWith('https://github.com/')) return null;
  return isNewer(current, tag) ? UpdateInfo(tag.replaceFirst(RegExp(r'^v'), ''), url) : null;
}
