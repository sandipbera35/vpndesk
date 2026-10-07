# Third-party notices

OnionDesk is Apache-2.0. It bundles or downloads the following third-party material.

## Flutter and Dart packages (compiled into the app)
The Flutter framework and engine (BSD-3-Clause, Copyright The Flutter Authors) and these packages, with all of their
dependencies, which were checked with `python3 tool/check_licenses.py` (51 hosted packages: all BSD-3-Clause, MIT or
Apache-2.0; none is GPL or otherwise copyleft): `bitsdojo_window` (MIT), `cupertino_icons` (MIT), `file_selector` (BSD-3-Clause),
`socks5_proxy` (MIT), `webview_cef` 0.6.2 (Apache-2.0, a patched copy in `third_party/webview_cef`, see ONIONDESK_PATCHES.md), plus the Dart team's `async`, `collection`, `path`, `http`, `meta` ... (BSD-3-Clause) and `clock`,
`material_color_utilities` (Apache-2.0). Run the script again whenever a dependency is added; it fails on anything that is not
permissive. The Material Icons font that Flutter embeds is Apache-2.0.

## Chromium Embedded Framework (bundled, OnionDesk Browser)
OnionDesk Browser's engine is the Chromium Embedded Framework 149 (https://bitbucket.org/chromiumembedded/cef, BSD-3-Clause),
the official standard distribution from https://cef-builds.spotifycdn.com, unmodified, downloaded by the build and shipped
as `libcef.so` / `libcef.dll` / the CEF framework. It contains Chromium (BSD-3-Clause) and many third-party components
under their own licenses (FFmpeg under LGPL, ICU, V8, Skia, HarfBuzz, zlib, BoringSSL ...): the CEF `LICENSE.txt` is shipped
as `licenses/CEF-LICENSE.txt` next to the app, and the complete Chromium credits are inside the engine (`about:credits`).
This build of CEF has no proprietary codecs, so H.264 and AAC video does not play; VP8/VP9/AV1, Opus, Vorbis and WebM/Ogg do.

## Tor (bundled)
The Tor Expert Bundle from the Tor Project (https://www.torproject.org) is shipped unmodified. Tor is under the 3-clause BSD license.

## i2pd (bundled)
The I2P tab runs i2pd (https://github.com/PurpleI2P/i2pd, PurpleI2P), shipped unmodified with its certificates folder:
the official release binary on Windows (x64) and macOS (x86_64), and a build from the unmodified 2.61.0 source on Linux
(boost, OpenSSL and zlib linked statically). i2pd is under the 3-clause BSD license (Copyright (c) 2013-2026, The PurpleI2P
Project). The Linux build also contains Boost (Boost Software License 1.0), OpenSSL (Apache-2.0) and zlib (zlib license).

## I2P seed address book (bundled)
`packaging/i2p/hosts.txt` (shipped next to i2pd) lists ~1500 .i2p names and their destinations so sites resolve on the first start. It starts with the I2P project's own `installer/resources/hosts.txt` (https://github.com/i2p/i2p.i2p) and adds names from the public subscription lists inr.i2p (alive-hosts), notbob.i2p and stats.i2p (newhosts), as fetched on 2026-10-07 through I2P.

## proxychains-ng (bundled on Linux)
The I2P tab's split tunneling preloads `libproxychains4.so` from proxychains-ng 4.17 (https://github.com/rofl0r/proxychains-ng,
GPL-2.0-or-later), built unmodified from the upstream release tarball (`build_proxychains_linux.sh` in this repository) and shipped as a
separate file, not linked into OnionDesk. Source: https://github.com/rofl0r/proxychains-ng/archive/refs/tags/v4.17.tar.gz

## Natural Earth (bundled map data)
Country outlines in `assets/world.json` derive from Natural Earth (public domain).

## StevenBlack/hosts (optional download)
If you choose **More > Download the full ad-block list**, OnionDesk downloads
https://github.com/StevenBlack/hosts (the `hosts` file) to your config folder. It is not bundled with the app.

The MIT License (MIT) — Copyright (c) 2013-present Steven Black

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
