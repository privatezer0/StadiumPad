#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${STADIUMPAD_ANDROID_BUILD:?Build the Android app first}"
: "${ANDROID_JAR:?Set the Android SDK jar}"
: "${JAVA_HOME:?Set the external JDK}"
mkdir -p "$STADIUMPAD_ANDROID_BUILD/bluetooth-tests"
"$JAVA_HOME/bin/javac" --release 8 -cp "$ANDROID_JAR:$STADIUMPAD_ANDROID_BUILD/classes" -d "$STADIUMPAD_ANDROID_BUILD/bluetooth-tests" "$ROOT/tests/BluetoothCodecTests.java"
"$JAVA_HOME/bin/java" -cp "$ANDROID_JAR:$STADIUMPAD_ANDROID_BUILD/classes:$STADIUMPAD_ANDROID_BUILD/bluetooth-tests" com.privatezero.stadiumpad.BluetoothCodecTests
