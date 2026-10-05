# A/B: baseline vs isolatedest (de, 10 interleaved pairs)

- date: 2026-10-05T12:34:45.480771
- country: de
- multidest: true
- reroll_mbps: 5
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs isolatedest

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 4.01 | 2.02 | 1.64 / 2.15 / 0.37 (60) | 4.68 / 6.76 / 1.49 (30) | 9.14 / 14.01 / 3.51 (30) | 0/120 |
| isolatedest | 10 | 4.13 | 2.20 | 1.79 / 2.24 / 2.11 (60) | 4.54 / 6.32 / 1.61 (30) | 13.20 / 17.95 / 4.65 (30) | 0/120 |
