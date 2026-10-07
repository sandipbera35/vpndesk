# Privacy policy

_Last updated: 2026-10-07 (OnionDesk 1.4.0). This is a plain-language description of what the software does, not legal advice._

OnionDesk is free, open-source software that runs on your computer. The author (Sandip Bera) runs **no server for it**, has **no accounts**, and receives **no data** from your use of it: there is no analytics, crash reporting, advertising or tracking code in the app. Everything below is what the software itself does, so you can check it against the source code (https://github.com/sandipbera35/vpndesk).

## What is stored on your computer
Only in your own user folder (Linux `~/.config/oniondesk`, macOS `~/Library/Application Support/oniondesk`, Windows `%APPDATA%\oniondesk`), and nothing is sent anywhere by the app because it is stored:
- `settings.json`: your choices (selected country, favorites, excluded countries, language, theme, options, the paths of apps you added for split tunneling, and bridge lines if you entered any).
- Tor and I2P working files (`torrc`, Tor data, the I2P router's data and address book, a cache of the Tor relay list, measured speeds).
- Downloaded ad-block list (only if you chose to download it), a cache of the last geolocation lookup, a log kept in memory only.
- OnionDesk Browser keeps **no history, cookies, cache or saved passwords on disk** (it runs without a profile folder); they are gone when you close the app. Tabs you have open exist only in memory.
You can delete all of it with **Settings > Uninstall > delete my data**, or by removing that folder.

## What the app sends over the network, and to whom
OnionDesk is a tool for using Tor and I2P, so what a website or server sees depends on whether you are connected.

| When | Contacts | What that party can see |
|---|---|---|
| Not connected to Tor (the Tor tab shows your "Real IP") | `api.ipify.org`, `icanhazip.com`, `ifconfig.me` (to learn your public IP), then `ipinfo.io`, `get.geojs.io`, `ipwho.is`, `ipapi.co` (to place that IP on the map) | **Your real IP address**, sent directly, repeated about every 30 seconds while you are not connected |
| Connected to Tor | The same kinds of services, `check.torproject.org` and `api.country.is` | The Tor exit relay's IP, not yours |
| Connecting to Tor | The Tor network, and the Tor Project's relay directory `onionoo.torproject.org` (cached on disk) | Normal Tor client traffic; the directory sees a request for relay lists |
| Speed test (when you run it) | `speed.cloudflare.com` | Your IP (the Tor exit's IP when connected) |
| Update notice (on by default, every 6 hours, can be turned off in Settings) | `api.github.com` | Your IP (the Tor exit's IP when connected) and that you use OnionDesk |
| Ad-block list (only if you press download) | `raw.githubusercontent.com` | Your IP (the Tor exit's IP when connected) |
| I2P tab running | I2P reseed servers and the I2P network, address-book subscriptions | Normal I2P router traffic; your router is known to the I2P network as a peer (it does not relay for others unless you turn that on) |
| OnionDesk Browser | The sites you open, only through Tor (web) or I2P (`.i2p`); anything else is refused | What those sites normally see through Tor or I2P. A search typed in the address bar goes to DuckDuckGo through Tor |
| Using an app via split tunneling | Whatever that app contacts | Whatever that app normally sends, through Tor or I2P |

If you do not want any direct request that reveals your real IP, connect Tor first and turn off the update check in Settings; the "Real IP" card is the one feature that has to ask an outside service for it.

## What is not collected
No names, e-mail addresses, device identifiers, usage statistics, browsing history, or location are collected by the author. The country and city shown on the map come from the IP lookups in the table above and stay on your computer.

## Third parties
They have their own policies: the services above, GitHub, the Tor Project, the I2P network and the sites you visit. A Tor exit operator can see unencrypted traffic that leaves the Tor network. OnionDesk cannot make a website, a service or an operator safe or trustworthy.

## Children
OnionDesk is not directed at children and knowingly collects nothing from anyone.

## Changes and contact
If the software changes what it sends, this file is updated in the same release. Questions or privacy concerns: sandipbera35@outlook.com or https://github.com/sandipbera35/vpndesk/issues. Your rights under privacy laws (for example GDPR) apply to data a controller holds about you; the author holds none from this software.
