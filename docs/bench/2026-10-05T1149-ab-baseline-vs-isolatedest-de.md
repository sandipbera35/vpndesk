# A/B: baseline vs isolatedest (de, 10 interleaved pairs)

- date: 2026-10-05T11:23:33.540986
- country: de
- multidest: true
- reroll_mbps: 5
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs isolatedest

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 4.10 | 2.32 | 1.48 / 1.94 / 0.35 (60) | 4.94 / 7.29 / 1.56 (29) | 10.24 / 15.16 / 3.81 (29) | 2/120 |
| isolatedest | 10 | 3.94 | 2.33 | 1.65 / 2.34 / 1.40 (60) | 5.77 / 7.75 / 2.06 (30) | 13.76 / 22.44 / 6.03 (30) | 0/120 |
