# OnionDesk changes to webview_cef 0.6.2 (Apache-2.0, upstream: https://github.com/hlwhl/webview_cef)

Vendored because an anonymity browser cannot use the upstream defaults:

1. `common/webview_app.cc`: removed `--disable-web-security` and `--allow-running-insecure-content` (they switch off the
   same-origin policy). The Chromium sandbox is now ON unless the environment variable `ONIONDESK_CEF_NO_SANDBOX` is set
   (upstream always passed `--no-sandbox`; `common/webview_plugin.cc` `cefs.no_sandbox` follows the same variable).
2. Added a `setProxy` method call (and `WebviewManager.initialize(proxyServer: ...)`): the proxy is passed to CEF as
   `--proxy-server`, with `--proxy-bypass-list=<-loopback>` and `--force-webrtc-ip-handling-policy=disable_non_proxied_udp`.
   OnionDesk points it at its own local SOCKS5 route (lib/browser_mux.dart), which only reaches Tor and I2P.

Everything else is unchanged. Large downloads (`third/cef`, `linux/prebuilt.zip`) are fetched by the build, never committed.
3. With the proxy set, background networking is switched off (`--disable-background-networking`, `--disable-sync`, `--disable-component-update`, `--no-pings`, ...), so Chromium itself makes no Google requests.
4. `setNoSandbox` (and `initialize(noSandbox: true)`): the app passes it only when the system cannot run the Chromium sandbox (see lib/browser_sandbox.dart); the browser then shows a warning.
5. GPU compositing is ON by default (upstream passed `--disable-gpu`): 1080p30 video went from 21 fps / 29% dropped frames to 30 fps / 0 dropped on an Intel HD 620 laptop; 720p60 stays at ~54 fps. `ONIONDESK_CEF_NO_GPU=1` switches it off.
6. `lib/src/webview.dart` / `webview_tooltip.dart`: `WebViewState.dispose` (upstream had none). A tab's page that leaves the screen now drops its text-input (IME) client, keyboard focus, cursor/tooltip callbacks and any pending tooltip. Before, a hidden tab kept the IME, so typing in the address bar of another tab did nothing, and its stale tooltip (a white "Home" box) popped up at random.
7. CI build fixes: Windows `_CRT_SECURE_NO_WARNINGS` (the `getenv` calls are errors under /WX), macOS helper compiled with `-DNDEBUG` when the wrapper is a Release build (link error on `RefCountedThreadSafeBase`). Linux needs clang >= 16 (22.04's clang 14 rejects CEF headers; the workflow installs clang 18).
