#!/usr/bin/env python3
"""Lists every Dart/Flutter package in pubspec.lock with its license and fails (exit 1) if one is not permissive.
Run after `flutter pub get`:  python3 tool/check_licenses.py
Allowed: BSD-3-Clause, MIT, Apache-2.0 (and BSD-2). Anything else must be reviewed by hand before it is shipped."""
import os, re, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
cache = os.path.expanduser(os.environ.get('PUB_CACHE', '~/.pub-cache')) + '/hosted/pub.dev'
pk, cur = {}, None
for l in open('pubspec.lock').read().split('\n'):
    m = re.match(r'^  (\w+):$', l)
    if m:
        cur = m.group(1); pk[cur] = {}; continue
    if cur:
        m = re.match(r'^    (\w+): "?([^"\n]+)"?$', l)
        if m and m.group(1) in ('dependency', 'source', 'version'): pk[cur][m.group(1)] = m.group(2)

def kind(text):
    t = re.sub(r'\s+', ' ', text)
    if 'Redistribution and use in source and binary forms' in t:
        return 'BSD-3-Clause' if 'Neither the name' in t or 'endorse or promote' in t else 'BSD-2-Clause'
    if 'Permission is hereby granted, free of charge' in t: return 'MIT'
    if 'Apache License' in t and 'Version 2.0' in t: return 'Apache-2.0'
    if 'GNU' in t or 'GPL' in t: return 'GPL?'
    return 'UNKNOWN'

ok, bad = 0, []
for name, v in sorted(pk.items()):
    if 'version' not in v: continue
    if v.get('source') != 'hosted':
        print(f"{name:34} {v['version']:12} (SDK / local path)"); continue
    d = f"{cache}/{name}-{v['version']}"
    lic = 'NO LICENSE FILE'
    for f in ('LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING'):
        if os.path.exists(f'{d}/{f}'):
            lic = kind(open(f'{d}/{f}', errors='replace').read()); break
    print(f"{name:34} {v['version']:12} {lic}")
    if lic in ('BSD-3-Clause', 'BSD-2-Clause', 'MIT', 'Apache-2.0'): ok += 1
    else: bad.append((name, lic))
print(f"\n{ok} permissive, {len(bad)} to review")
for n, l in bad: print('  REVIEW:', n, l)
sys.exit(1 if bad else 0)
