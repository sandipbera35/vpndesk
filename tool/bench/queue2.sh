#!/usr/bin/env bash
# Phase 3 experiment queue (conflux). Sequential; each A/B is ~35 min. Usage: tool/bench/queue2.sh > log 2>&1
set -u
cd "$(dirname "$0")/../.."
export PATH=/opt/flutter/bin:$PATH
C="--country de --pairs 10 --ttfb-n 6 --dl-n 3 --par-n 3 --multidest"
dart tool/bench/bench.dart ab --a current --b conflux $C
dart tool/bench/bench.dart ab --a current --b confluxuxtp $C
dart tool/bench/bench.dart ab --a current --b confluxtp $C
echo QUEUE_DONE
