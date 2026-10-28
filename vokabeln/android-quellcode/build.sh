#!/bin/bash
set -e
BT=/home/claude/sdk/android-15; PF=/home/claude/sdk/android-34/android.jar
cd "$(dirname "$0")"; rm -rf build; mkdir -p build/obj build/dex
$BT/aapt2 compile --dir res -o build/res.zip
$BT/aapt2 link -o build/base.apk -I $PF --manifest AndroidManifest.xml -A assets --java build/gen build/res.zip --min-sdk-version 24 --target-sdk-version 34 --version-code ${VC:-1} --version-name ${VN:-1.0}
javac -source 8 -target 8 -g -nowarn -encoding UTF-8 -classpath $PF -d build/obj $(find src build/gen -name '*.java') 2>&1 | grep -v "warning\|^Note" || true
$BT/d8 --min-api 24 --lib $PF --output build/dex $(find build/obj -name '*.class')
cp build/base.apk build/unsigned.apk; (cd build/dex && zip -q -u ../unsigned.apk classes.dex)
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
[ -f release.keystore ] || keytool -genkeypair -keystore release.keystore -alias vokabeln -keyalg RSA -keysize 2048 -validity 10000 -storepass pagsvokabeln -keypass pagsvokabeln -dname "CN=Thorsten von Plotho-Kettner, O=Pater-Alois-Grimm-Schule Kuelsheim, C=DE" 2>/dev/null
$BT/apksigner sign --ks release.keystore --ks-pass pass:pagsvokabeln --key-pass pass:pagsvokabeln --out PAGS-Vokabeltrainer.apk build/aligned.apk
$BT/apksigner verify --print-certs PAGS-Vokabeltrainer.apk | head -2
ls -la PAGS-Vokabeltrainer.apk
