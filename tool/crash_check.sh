#!/usr/bin/env bash
# Real-app crash test (Linux, needs a display): connect, SIGKILL the app, check the machine is restored.
# Touches the real GNOME proxy settings and puts them back. Usage: tool/crash_check.sh [kill|term|hup|dot]
set -u
cd "$(dirname "$0")/.."
export PATH=/opt/flutter/bin:$PATH
P=org.gnome.system.proxy
MODE=${1:-kill}; echo "$MODE" > /tmp/oniondesk_crash_mode; echo "mode: $MODE"
o_mode=$(gsettings get $P mode); o_host=$(gsettings get $P.socks host); o_port=$(gsettings get $P.socks port)
echo "original proxy: $o_mode $o_host $o_port"
# a user proxy that must survive the round trip (not a blind 'none')
gsettings set $P.socks host '10.1.2.3'; gsettings set $P.socks port 8080; gsettings set $P mode manual
LOG=$(mktemp); trap 'rm -f $LOG /tmp/oniondesk_crash_mode' EXIT
flutter test integration_test/crash_test.dart -d linux >"$LOG" 2>&1 &
for i in $(seq 1 400); do grep -q CRASH_CONNECTED "$LOG" && break; sleep 1; done
grep -q CRASH_CONNECTED "$LOG" || { echo "never connected"; tail -20 "$LOG"; }
echo "--- while connected:"
echo "proxy: $(gsettings get $P mode) $(gsettings get $P.socks host):$(gsettings get $P.socks port)"
echo "journal:"; cat ~/.local/state/oniondesk/session.json 2>&1
echo "tor:"; pgrep -a -x tor
echo "watchdog:"; pgrep -af '[v]pndesk-restore --watch'
echo "--- app ends via '$MODE' in ~8s; polling..."
for i in $(seq 1 40); do
  sleep 1
  [ ! -e ~/.local/state/oniondesk/session.json ] && { echo "journal gone after ${i}s past connect+8"; break; }
done
sleep 2
echo "--- after kill -9:"
echo "proxy: $(gsettings get $P mode) $(gsettings get $P.socks host):$(gsettings get $P.socks port)  (expect manual 10.1.2.3:8080)"
echo "tor:"; pgrep -a -x tor || echo "  none"
echo "journal:"; ls ~/.local/state/oniondesk/ 2>&1
echo "watchdog:"; pgrep -af '[v]pndesk-restore --watch' || echo "  none"
# put the original user settings back
gsettings set $P.socks host "${o_host//\'/}"; gsettings set $P.socks port "$o_port"; gsettings set $P mode "${o_mode//\'/}"
echo "restored original: $(gsettings get $P mode)"
