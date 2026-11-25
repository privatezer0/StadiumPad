#!/bin/bash
# Real Java protocol classes, loopback-only peers. Never contacts a pedal.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUILD=${STADIUMPAD_ANDROID_BUILD:?Set external Android build folder}
TOOLS=${ANDROID_TOOLS_ROOT:-/Volumes/SoundStageAndroidBuild}
export JAVA_HOME=${JAVA_HOME:-$TOOLS/jdk-17.0.21+9/Contents/Home}
JAR=${ANDROID_JAR:-${ANDROID_SDK_ROOT:-$TOOLS/sdk}/platforms/android-35/android.jar}
TEST="$BUILD/parity-tests"
mkdir -p "$TEST"
"$JAVA_HOME/bin/javac" --release 8 -cp "$JAR:$BUILD/classes" -d "$TEST" "$ROOT/Android/tests/ParityTests.java" "$ROOT/Android/tests/ParitySessionTests.java"
export STADIUM_JAVA="$JAVA_HOME/bin/java" STADIUM_ANDROID_CLASSES="$TEST:$BUILD/classes:$JAR"
"$STADIUM_JAVA" -cp "$STADIUM_ANDROID_CLASSES" com.privatezero.stadiumpad.ParityTests
"${PYTHON:-python3}" -m unittest discover -s "$ROOT/Tests" -p android_parity_integration.py -v
