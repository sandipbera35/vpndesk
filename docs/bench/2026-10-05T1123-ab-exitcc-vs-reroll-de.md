# A/B: exitcc vs reroll (de, 10 interleaved pairs)

- date: 2026-10-05T10:46:32.674985
- country: de
- multidest: false
- reroll_mbps: 5
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### exitcc vs reroll

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| exitcc | 10 | 4.13 | 2.20 | 1.60 / 2.63 / 0.91 (60) | 4.49 / 6.58 / 1.81 (30) | 10.14 / 15.84 / 4.09 (30) | 0/120 |
| reroll | 10 | 4.55 | 2.55 | 1.75 / 4.06 / 2.76 (60) | 2.83 / 4.71 / 1.42 (30) | 7.48 / 13.29 / 3.72 (30) | 0/120 · rerolls 30, overhead med 49.48 s |
