# Security policy

## Reporting a vulnerability
Please report security problems **privately** to sandipbera35@outlook.com (subject "OnionDesk security"), or use GitHub's private "Report a vulnerability" form on https://github.com/sandipbera35/vpndesk/security. Include the version, your system, and steps to reproduce. This is a one-person, volunteer project: I aim to acknowledge within 7 days, but there is no guaranteed response time or bug bounty. Please give me reasonable time to fix a problem before disclosing it publicly.

## Supported versions
Only the latest release receives fixes.

## What OnionDesk does and does not protect
- It runs the Tor client (and an I2P router) for you and routes the traffic you send to it. It does **not** make you anonymous by itself: your behaviour, logins, browser fingerprint, malware, and unencrypted traffic leaving a Tor exit can still identify you or expose content.
- The default mode is a local SOCKS5 proxy: programs that ignore the proxy are not covered. System-wide mode (Linux) is designed to send all TCP and DNS traffic through Tor and to block what Tor cannot carry, but it has not been independently audited. Use the built-in leak test and the Tor Project's own tools to check your setup.
- OnionDesk Browser and the I2P tab are **beta**. The browser engine (Chromium) needs prompt updates, and OnionDesk can only ship a new version when I release one: for sensitive use, prefer the Tor Browser from the Tor Project.
- The software has not been security-audited by a third party.

## Provided as is
See the Apache License 2.0 (sections 7 and 8): no warranty, and no liability for damages.
