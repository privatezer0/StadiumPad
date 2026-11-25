#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TOOLS=${ANDROID_TOOLS_ROOT:-/Volumes/SoundStageAndroidBuild}
BUILD=${STADIUMPAD_ANDROID_BUILD:?Set an external build folder}/live-selection-tests
export JAVA_HOME=${JAVA_HOME:-$TOOLS/jdk-17.0.21+9/Contents/Home}
JAR=${ANDROID_JAR:-${ANDROID_SDK_ROOT:-$TOOLS/sdk}/platforms/android-35/android.jar}
mkdir -p "$BUILD"
files=()
for name in Data Models Wire Session LiveSelection SelectionMemory Reorder Stomp PedalBridge GlobalEQ Matrix;do files+=("$ROOT/Android/app/src/main/java/com/privatezero/stadiumpad/$name.java");done
"$JAVA_HOME/bin/javac" --release 8 -cp "$JAR" -d "$BUILD" "${files[@]}" "$ROOT/Android/tests/LiveSelectionTests.java" "$ROOT/Android/tests/SelectionSessionTests.java" "$ROOT/Android/tests/SelectionMemoryTests.java"
"$JAVA_HOME/bin/java" -cp "$BUILD:$JAR" com.privatezero.stadiumpad.LiveSelectionTests
"$JAVA_HOME/bin/java" -cp "$BUILD:$JAR" com.privatezero.stadiumpad.SelectionMemoryTests
STADIUM_JAVA_SELECTION_CLASSES="$BUILD:$JAR" "${PYTHON:-python3}" -m unittest discover -s "$ROOT/Tests" -p selection_integration.py
