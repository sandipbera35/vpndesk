# A/B: baseline vs exitset3 (de, 10 interleaved pairs)

- date: 2026-10-05T09:29:35.411272
- country: de
- os: Linux 7.2.8-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Sep 25 21:05:44 UTC 2026
- bytes: 3000000
- streams: 4

### baseline vs exitset3

| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | 4-stream Mbps med / p90 / sd (n) | failures |
|---|---|---|---|---|---|---|---|
| baseline | 10 | 3.91 | 2.06 | 1.49 / 1.78 / 0.26 (60) | 4.66 / 6.65 / 1.39 (30) | 11.49 / 15.95 / 3.21 (29) | 1/120 |
| exitset3 | 10 | 4.21 | 2.09 | 1.53 / 1.90 / 0.42 (60) | 5.14 / 7.07 / 1.82 (30) | 10.36 / 14.09 / 3.97 (30) | 0/120 |
