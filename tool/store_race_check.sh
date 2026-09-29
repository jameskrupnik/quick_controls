#!/bin/sh
# Races TAPPERS processes x TAPS taps against one draining process through
# QuickControlsStore, and checks every tap is drained exactly once.
# See store_race_check.swift for what this does and does not prove.
set -eu
cd "$(dirname "$0")"
TAPPERS=${TAPPERS:-4}
TAPS=${TAPS:-250}
SUITE="com.illuminationdevelopment.quick_controls.racecheck.$$"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Top-level code in a multi-file build must be in a file named main.swift.
cp store_race_check.swift "$WORK/main.swift"
xcrun swiftc -O -o "$WORK/check" \
  ../ios/quick_controls/Sources/QuickControlsKit/QuickControlsStore.swift "$WORK/main.swift"

"$WORK/check" clear "$SUITE"
"$WORK/check" drain "$SUITE" "$WORK/stop" > "$WORK/result" &
DRAINER=$!
PIDS=""
i=0
while [ $i -lt "$TAPPERS" ]; do
  "$WORK/check" tap "$SUITE" "$TAPS" &
  PIDS="$PIDS $!"
  i=$((i + 1))
done
for p in $PIDS; do wait "$p"; done
touch "$WORK/stop"
wait $DRAINER
"$WORK/check" clear "$SUITE"

EXPECTED=$((TAPPERS * TAPS))
RESULT=$(cat "$WORK/result")
echo "expected=$EXPECTED $RESULT"
case "$RESULT" in
  "drained=$EXPECTED unique=$EXPECTED "*) ;;
  *) echo "FAIL: taps lost or doubled"; exit 1 ;;
esac
