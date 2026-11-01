#!/usr/bin/env bash
# Runs every headless test in parallel, the same way CI judges them: a suite passes when it prints
# "<NAME> RESULT: PASS" and its log has no "SCRIPT ERROR" and no line starting with "ERROR".
# Usage: tools/run_tests.sh [godot-binary]     (logs go to /tmp/timber-tests)
GODOT=${1:-godot}
OUT=/tmp/timber-tests
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import > /dev/null 2>&1
SUITES="ChopTest LoopTest BuildTest AxeTest GearTest SaveTest MachineTest InputTest SoakTest ItemTest FactoryTest TutorialTest"
for t in $SUITES; do
  timeout 900 "$GODOT" --headless --path . "res://tests/$t.tscn" --fixed-fps 60 > "$OUT/$t.log" 2>&1 &
done
wait
fail=0
for t in $SUITES; do
  name=$(echo "$t" | sed 's/Test$//' | tr '[:lower:]' '[:upper:]')
  if grep -q "$name RESULT: PASS" "$OUT/$t.log" && ! grep -q "SCRIPT ERROR" "$OUT/$t.log" && ! grep -q "^ERROR" "$OUT/$t.log"; then
    echo "PASS  $t"
  else
    echo "FAIL  $t   (see $OUT/$t.log)"
    fail=1
  fi
done
exit $fail
