#!/usr/bin/env bash
# Phase 2 experiment queue (sequential; each A/B is ~35 min). Usage: tool/bench/queue.sh > log 2>&1
set -u
cd "$(dirname "$0")/../.."
export PATH=/opt/flutter/bin:$PATH
C="--country de --pairs 10 --ttfb-n 6 --dl-n 3 --par-n 3 --telemetry"
dart tool/bench/bench.dart ab --a exitcc --b reroll $C
dart tool/bench/bench.dart ab --a baseline --b isolatedest $C --multidest
dart tool/bench/bench.dart ab --a baseline --b nopad $C
dart tool/bench/bench.dart ab --a baseline --b defaultcirc $C
echo QUEUE_DONE
