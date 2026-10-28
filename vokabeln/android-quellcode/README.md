# PAGS Vokabeltrainer – Android-Hülle

WebView-App (ohne Fremdbibliotheken), die die Web-App aus `assets/www` ausliefert.
Ergänzt Kamera-/Galerie-Auswahl, Sprachausgabe über Android-TextToSpeech, Speichern von Sicherungen in „Download/Vokabeltrainer“ und die Zurück-Taste.

Bauen: `index.html`, Logo und Icons aus `../` nach `assets/www/` kopieren, dann `./build.sh` (Android build-tools 35, platform android-34).
Der Signaturschlüssel (`release.keystore`) liegt bewusst nicht im Repository.

Entwickelt von Thorsten von Plotho-Kettner, Pater-Alois-Grimm-Schule Külsheim.
