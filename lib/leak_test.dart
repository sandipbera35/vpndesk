// Leak test verdicts (pure). The checks themselves are done in main.dart and passed in as plain values.

enum LeakLevel { ok, warn, fail }

class LeakCheck {
  const LeakCheck(this.title, this.level, this.detail);
  final String title, detail;
  final LeakLevel level;
}

class LeakInputs {
  const LeakInputs({
    required this.realIp,
    required this.proxyIp,
    required this.proxyIsTor,
    required this.directIp,
    required this.directIsTor,
    required this.systemWide,
    required this.dnsViaProxyOk,
  });
  final String? realIp; // our address without Tor (looked up before connecting)
  final String? proxyIp; // address a site sees through the SOCKS proxy
  final bool? proxyIsTor; // check.torproject.org says that request came from Tor
  final String? directIp; // address seen by a request that does NOT use the proxy
  final bool? directIsTor;
  final bool systemWide;
  final bool? dnsViaProxyOk; // a hostname was resolved by tor itself (SOCKS5 with remote DNS)
}

List<LeakCheck> evaluateLeaks(LeakInputs i) {
  final out = <LeakCheck>[];

  // 1. Through the proxy: must be a Tor exit and must not be our real address.
  if (i.proxyIp == null) {
    out.add(const LeakCheck('Traffic through the proxy', LeakLevel.fail, 'No answer through the proxy. Is OnionDesk connected?'));
  } else if (i.realIp != null && i.proxyIp == i.realIp) {
    out.add(LeakCheck('Traffic through the proxy', LeakLevel.fail, 'Sites see your real IP (${i.proxyIp}).'));
  } else if (i.proxyIsTor == false) {
    out.add(LeakCheck('Traffic through the proxy', LeakLevel.warn, '${i.proxyIp} is not a known Tor exit.'));
  } else {
    out.add(LeakCheck('Traffic through the proxy', LeakLevel.ok, 'Sites see ${i.proxyIp}${i.proxyIsTor == true ? ' (a Tor exit)' : ''}, not your real IP.'));
  }

  // 2. DNS: names must be resolved by tor, not by the local resolver.
  if (i.dnsViaProxyOk == null) {
    out.add(const LeakCheck('DNS lookups', LeakLevel.warn, 'Could not test.'));
  } else {
    out.add(i.dnsViaProxyOk!
        ? const LeakCheck('DNS lookups', LeakLevel.ok, 'Names are resolved inside Tor for apps that use the proxy (SOCKS5 with remote DNS).')
        : const LeakCheck('DNS lookups', LeakLevel.fail, 'A hostname could not be resolved through Tor.'));
  }

  // 3. Apps that ignore the proxy.
  if (i.directIp == null) {
    out.add(const LeakCheck('Apps that ignore the proxy', LeakLevel.warn, 'Could not test.'));
  } else if (i.systemWide) {
    out.add(i.directIsTor == true || (i.realIp != null && i.directIp != i.realIp)
        ? LeakCheck('Apps that ignore the proxy', LeakLevel.ok, 'System-wide mode: even a plain connection leaves through Tor (${i.directIp}).')
        : LeakCheck('Apps that ignore the proxy', LeakLevel.fail, 'System-wide mode is on but a plain connection shows your real IP (${i.directIp}).'));
  } else if (i.realIp != null && i.directIp == i.realIp) {
    out.add(const LeakCheck('Apps that ignore the proxy', LeakLevel.warn,
        'Normal for proxy mode: only apps that use the proxy are protected. Turn on System-wide mode (Linux) to cover every app.'));
  } else {
    out.add(const LeakCheck('Apps that ignore the proxy', LeakLevel.ok, 'A plain connection does not show your real IP.'));
  }

  // 4. WebRTC cannot be tested from a desktop app.
  out.add(const LeakCheck('WebRTC (browser)', LeakLevel.warn,
      'Cannot be tested here. In Firefox set media.peerconnection.enabled to false; in Chrome use a WebRTC-blocking extension.'));
  return out;
}
