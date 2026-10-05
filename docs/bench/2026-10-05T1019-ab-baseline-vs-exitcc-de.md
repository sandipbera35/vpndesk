# A/B: baseline vs exitcc (de, 10 interleaved pairs)

- date: 2026-10-05T09:52:40.357600
- country: de
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs exitcc

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 3.92 | 2.01 | 1.59 / 1.93 / 0.28 (60) | 4.62 / 6.33 / 1.12 (30) | 11.96 / 16.38 / 4.18 (30) | 0/120 |
| exitcc | 10 | 4.06 | 2.29 | 1.61 / 2.07 / 0.29 (60) | 5.29 / 7.13 / 2.24 (30) | 13.18 / 17.89 / 5.37 (28) | 2/120 |
