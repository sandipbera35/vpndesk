#!/usr/bin/env python3
"""Paired comparison of an A/B result: per-session medians, mean difference with a 95% CI, and how often B > A.
Usage: tool/bench/paired.py docs/bench/<stamp>-ab-<a>-vs-<b>-<cc>.json"""
import json, math, statistics as st, sys
d = json.load(open(sys.argv[1]))['results']
(an, A), (bn, B) = list(d.items())
med = lambda x: st.median(x) if x else float('nan')
print(f"{bn} minus {an}  (A={an}, B={bn})")
for key, label in [('ttfb_s', 'TTFB s (lower is better)'), ('single_mbps', '1-stream Mbps'), ('parallel_mbps', 'parallel Mbps')]:
    a = [med(s[key]) for s in A]; b = [med(s[key]) for s in B]
    n = min(len(a), len(b)); df = [b[i] - a[i] for i in range(n) if not (math.isnan(a[i]) or math.isnan(b[i]))]
    se = st.stdev(df) / math.sqrt(len(df))
    print(f"  {label}: {st.mean(df):+.2f} ± {1.96 * se:.2f} (95% CI), B higher in {sum(x > 0 for x in df)}/{len(df)} pairs")
