#!/bin/bash
# Monta o APK do emulador de mentira com as ferramentas do SDK do Android: gerar.sh <saida.apk>
set -ex
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(readlink -f "$1")
BT=$(ls -d $ANDROID_HOME/build-tools/*/ | sort -V | tail -1)
JAR=$(ls -d $ANDROID_HOME/platforms/android-*/ | sort -V | tail -1)android.jar
W=$(mktemp -d)
javac -source 8 -target 8 -cp "$JAR" -d "$W/obj" $(find "$HERE/src" -name "*.java")
"$BT/d8" --min-api 21 --lib "$JAR" --output "$W" $(find "$W/obj" -name "*.class")
"$BT/aapt2" link -o "$W/base.apk" --manifest "$HERE/AndroidManifest.xml" -I "$JAR" --min-sdk-version 21 --target-sdk-version 30
(cd "$W" && zip -q base.apk classes.dex)
"$BT/zipalign" -f 4 "$W/base.apk" "$W/aligned.apk"
keytool -genkeypair -keystore "$W/k.jks" -storepass teste1 -keypass teste1 -alias k -keyalg RSA -keysize 2048 -validity 100 -dname "CN=teste" >/dev/null
"$BT/apksigner" sign --ks "$W/k.jks" --ks-pass pass:teste1 --out "$OUT" "$W/aligned.apk"
ls -la "$OUT"
