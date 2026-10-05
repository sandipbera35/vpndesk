#!/usr/bin/env bash
# Loads vpndesk-net's real nftables rule functions inside a throw-away user+network namespace, so the
# host firewall is never touched. Checks: rules load, the table has the expected chains, delete is
# idempotent, and the table is really gone afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."
HELPER=packaging/linux/vpndesk-net
FUNCS="$(sed -n '/^rules_clear()/,/^ensure_user()/p' "$HELPER" | sed '$d')"
BEFORE="$(nft list tables 2>/dev/null | sort || true)"
unshare -Urn bash -c '
LAN4="127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16"
LAN6="::1, fe80::/10, fc00::/7"
TABLE="inet vpndesk"; UID_T=1234
'"$FUNCS"'
fail() { echo "FAIL: $*"; exit 1; }
rules_redirect || fail "rules_redirect failed to load"
nft list table inet vpndesk | grep -q "redirect to :9040"      || fail "TCP redirect missing"
nft list table inet vpndesk | grep -q "redirect to :5353"      || fail "DNS redirect missing"
nft list table inet vpndesk | grep -q "meta skuid 1234 accept" || fail "tor uid exemption missing"
nft list table inet vpndesk | grep -q "drop"                   || fail "default drop missing"
rules_block || fail "rules_block failed to load"
nft list table inet vpndesk | grep -q "redirect" && fail "block mode must not redirect"
nft list table inet vpndesk | grep -q "drop"                   || fail "block mode drop missing"
rules_clear; rules_clear   # idempotent
nft list tables | grep -q vpndesk && fail "table still present after clear"
echo "netns: rules_redirect / rules_block / rules_clear OK"
'
AFTER="$(nft list tables 2>/dev/null | sort || true)"
[ "$BEFORE" = "$AFTER" ] && echo "host nft tables unchanged"
