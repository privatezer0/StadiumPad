#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS=${ANDROID_TOOLS_ROOT:-/Volumes/SoundStageAndroidBuild}
BUILD=${STADIUMPAD_ANDROID_BUILD:?Set STADIUMPAD_ANDROID_BUILD to an external build folder}
export JAVA_HOME=${JAVA_HOME:-$TOOLS/jdk-17.0.21+9/Contents/Home}
export PATH="$JAVA_HOME/bin:$PATH"
SDK=${ANDROID_SDK_ROOT:-$TOOLS/sdk};BT=${ANDROID_BUILD_TOOLS:-$SDK/build-tools/35.0.0};JAR=${ANDROID_JAR:-$SDK/platforms/android-35/android.jar}
[[ -f "$JAR" && -x "$JAVA_HOME/bin/javac" && "$BUILD" != / ]] || exit 1
mkdir -p "$BUILD/classes" "$BUILD/dex" "$BUILD/assets" "$BUILD/signing"
find "$BUILD/classes" -name '*.class' -delete
for name in ParameterCatalog FocusCatalog ModelNames CommandCatalog; do
 [[ -f "$ROOT/../iPad/Resources/$name.json" ]] || { echo "Prepare local $name.json first"; exit 1; }
 cp "$ROOT/../iPad/Resources/$name.json" "$BUILD/assets/"
done
find "$ROOT/app/src/main/java" -name '*.java' > "$BUILD/sources.txt"
javac --release 8 -encoding UTF-8 -classpath "$JAR" -d "$BUILD/classes" @"$BUILD/sources.txt"
"$BT/aapt2" compile --dir "$ROOT/app/src/main/res" -o "$BUILD/res.zip"
"$BT/aapt2" link -o "$BUILD/resources.apk" -I "$JAR" --manifest "$ROOT/app/src/main/AndroidManifest.xml" -A "$BUILD/assets" --version-code 13 --version-name 1.3.3 "$BUILD/res.zip"
find "$BUILD/classes" -name '*.class' > "$BUILD/classes.txt"
"$BT/d8" --min-api 26 --lib "$JAR" --output "$BUILD/dex" @"$BUILD/classes.txt"
cp "$BUILD/resources.apk" "$BUILD/unsigned.apk"
(cd "$BUILD/dex" && zip -q -0 "$BUILD/unsigned.apk" classes.dex)
"$BT/zipalign" -f 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
KEY=${STADIUMPAD_ANDROID_KEYSTORE:-$BUILD/signing/stadiumpad.jks}
if [[ ! -f "$KEY" ]]; then keytool -genkeypair -keystore "$KEY" --storepass android --keypass android -alias stadiumpad -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=StadiumPad Personal Android, O=Private Zero, C=US';chmod 600 "$KEY";fi
"$BT/apksigner" sign --ks "$KEY" --ks-pass pass:android --ks-key-alias stadiumpad --out "$BUILD/StadiumPad-Android-1.3.3.apk" "$BUILD/aligned.apk"
"$BT/apksigner" verify --verbose "$BUILD/StadiumPad-Android-1.3.3.apk"
shasum -a 256 "$BUILD/StadiumPad-Android-1.3.3.apk"
