# A/B: baseline vs defaultcirc (de, 10 interleaved pairs)

- date: 2026-10-05T12:12:04.610901
- country: de
- multidest: false
- reroll_mbps: 5
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs defaultcirc

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 4.03 | 2.01 | 1.54 / 1.94 / 0.32 (60) | 5.23 / 6.78 / 1.42 (30) | 9.67 / 15.45 / 3.78 (30) | 0/120 |
| defaultcirc | 10 | 4.08 | 2.11 | 1.83 / 2.27 / 0.43 (60) | 4.22 / 5.32 / 0.82 (30) | 8.57 / 11.00 / 1.75 (30) | 0/120 |
