#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS=${ANDROID_TOOLS_ROOT:-/Volumes/SoundStageAndroidBuild};BUILD=${STADIUMPAD_ANDROID_BUILD:?};TEST="$BUILD/tests";SDK=${ANDROID_SDK_ROOT:-$TOOLS/sdk};BT=${ANDROID_BUILD_TOOLS:-$SDK/build-tools/35.0.0};JAR=${ANDROID_JAR:-$SDK/platforms/android-35/android.jar}
export JAVA_HOME=${JAVA_HOME:-$TOOLS/jdk-17.0.21+9/Contents/Home};export PATH="$JAVA_HOME/bin:$PATH"
mkdir -p "$TEST/classes" "$TEST/dex"
javac --release 8 -encoding UTF-8 -classpath "$JAR:$BUILD/classes" -d "$TEST/classes" "$ROOT/tests/"*.java
find "$TEST/classes" -name '*.class' > "$TEST/classes.txt"
"$BT/d8" --min-api 26 --lib "$JAR" --classpath "$BUILD/classes" --output "$TEST/dex" @"$TEST/classes.txt"
"$BT/aapt2" link -o "$TEST/unsigned.apk" -I "$JAR" --manifest "$ROOT/tests/AndroidManifest.xml"
(cd "$TEST/dex" && zip -q -0 "$TEST/unsigned.apk" classes.dex)
"$BT/zipalign" -f 4 "$TEST/unsigned.apk" "$TEST/aligned.apk"
"$BT/apksigner" sign --ks "${STADIUMPAD_ANDROID_KEYSTORE:-$BUILD/signing/stadiumpad.jks}" --ks-pass pass:android --ks-key-alias stadiumpad --out "$TEST/StadiumPad-Tests.apk" "$TEST/aligned.apk"
