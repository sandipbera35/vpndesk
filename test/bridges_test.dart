import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/bridges.dart';

const cfgText = '''
{"recommendedDefault":"obfs4","pluggableTransports":{
 "lyrebird":"ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec \${pt_path}lyrebird",
 "snowflake":"ClientTransportPlugin snowflake exec \${pt_path}lyrebird",
 "conjure":"ClientTransportPlugin conjure exec \${pt_path}conjure-client"},
 "bridges":{"meek":["meek_lite 192.0.2.20:80 url=https://x.example front=y.example"],
  "obfs4":["obfs4 1.2.3.4:443 AAAA cert=zzz iat-mode=0","obfs4 5.6.7.8:80 BBBB cert=yyy iat-mode=1"],
  "snowflake":["snowflake 192.0.2.3:80 CCCC fingerprint=CCCC url=https://f.example/"]}}
''';

void main() {
  final cfg = parsePtConfig(cfgText)!;
  const pt = '/opt/oniondesk/tor/pluggable_transports';

  test('config parses', () {
    expect(cfg.plugins.keys, containsAll(['lyrebird', 'snowflake']));
    expect(cfg.bridges['obfs4'], hasLength(2));
    expect(parsePtConfig('not json'), isNull);
  });

  test('no bridges: nothing is written', () => expect(bridgeTorrc(BridgeMode.none, cfg, pt), ''));

  test('obfs4: UseBridges, resolved plugin path, every default bridge', () {
    final t = bridgeTorrc(BridgeMode.obfs4, cfg, pt);
    expect(t, startsWith('UseBridges 1\n'));
    expect(t, contains('ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec $pt/lyrebird\n'));
    expect('Bridge obfs4'.allMatches(t), hasLength(2));
    expect(t, isNot(contains(r'${pt_path}')));
  });

  test('snowflake and meek use the right plugin line and bridge set', () {
    final s = bridgeTorrc(BridgeMode.snowflake, cfg, '$pt/');
    expect(s, contains('ClientTransportPlugin snowflake exec $pt/lyrebird\n'));
    expect(s, contains('Bridge snowflake 192.0.2.3:80'));
    final m = bridgeTorrc(BridgeMode.meek, cfg, pt);
    expect(m, contains('Bridge meek_lite 192.0.2.20:80'));
  });

  test('custom lines: Bridge prefix optional, plugins added per transport', () {
    final t = bridgeTorrc(BridgeMode.custom, cfg, pt, custom: 'obfs4 9.9.9.9:443 DDDD cert=q iat-mode=0\nBridge snowflake 192.0.2.4:80 EEEE\n# comment\n\n1.1.1.1:9001 FFFF');
    expect(t, contains('Bridge obfs4 9.9.9.9:443 DDDD cert=q iat-mode=0\n'));
    expect(t, contains('Bridge snowflake 192.0.2.4:80 EEEE\n'));
    expect(t, contains('Bridge 1.1.1.1:9001 FFFF\n'));
    expect(t, contains('ClientTransportPlugin snowflake exec'));
    expect('Bridge '.allMatches(t), hasLength(3));
  });

  test('custom lines cannot inject other torrc directives', () {
    for (final evil in ['ExitNodes {us}', 'obfs4 1.2.3.4:1 AAAA\nExitNodes {us}', 'DataDirectory /etc', 'obfs4 1.2.3.4:1 A\rSocksPort 1', '', '   \n# only comment']) {
      expect(() => bridgeTorrc(BridgeMode.custom, cfg, pt, custom: evil), throwsArgumentError, reason: evil);
    }
  });

  test('unusable setups give readable errors', () {
    expect(() => bridgeTorrc(BridgeMode.obfs4, null, pt), throwsA(isA<ArgumentError>().having((e) => '$e', 'msg', contains('not available'))));
    expect(() => bridgeTorrc(BridgeMode.obfs4, cfg, null), throwsArgumentError);
    expect(() => bridgeTorrc(BridgeMode.obfs4, cfg, r'C:/Users/A B/OnionDesk/tor/pluggable_transports'), throwsA(isA<ArgumentError>().having((e) => '$e', 'msg', contains('spaces'))));
  });

  test('mode round trip', () {
    for (final m in BridgeMode.values) { expect(bridgeModeFrom(m.name), m); }
    expect(bridgeModeFrom('garbage'), BridgeMode.none);
    expect(bridgeModeFrom(null), BridgeMode.none);
  });
}
