# A/B: baseline vs nopad (de, 10 interleaved pairs)

- date: 2026-10-05T11:49:59.984464
- country: de
- multidest: false
- reroll_mbps: 5
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs nopad

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 3.91 | 2.18 | 1.52 / 2.04 / 0.35 (60) | 4.55 / 6.22 / 1.36 (30) | 10.29 / 15.10 / 3.85 (30) | 0/120 |
| nopad | 10 | 4.05 | 2.05 | 1.52 / 1.93 / 0.40 (60) | 4.96 / 6.74 / 1.47 (30) | 11.87 / 14.60 / 3.87 (30) | 0/120 |
