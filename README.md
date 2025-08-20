# Food Locator — CI-first Flutter starter (no local SDK required)

This repo is set up so you **do not need to install the Android SDK** or Flutter locally to get a Play-ready **.aab** build.

## What you do

1. Create a new GitHub repository and upload these files.
2. Go to **Actions** and run the workflow **"Build Android AAB (No local SDK needed)"** (or push to `main`).
3. Download the build artifact: `appbundle/*.aab`. (You can upload this to Google Play.)
4. On the **first run**, the workflow also uploads an **`upload-keystore.jks`** artifact. Download and keep it safe.
   - In Google Play Console, when creating your app and enabling **Play App Signing**, you may be asked for the upload key. Use this keystore to sign future builds.
   - Add the keystore to repo **Secrets** so future builds reuse it:

      - `ANDROID_KEYSTORE_BASE64` = base64 of your `upload-keystore.jks`
      - `ANDROID_KEY_ALIAS` = `upload`
      - `ANDROID_KEY_PASSWORD` = `tempPass123` (or whatever you set)

   To create base64 locally:
   ```bash
   base64 upload-keystore.jks > keystore.b64
   # copy contents into the secret
   ```

## Notes

- The workflow bootstraps a Flutter project in CI if `android/` and `ios/` folders are missing.
- Map rendering uses **MapLibre** demo tiles (development). Replace `assets/style.json` for production.
- Geocoding uses **Nominatim** (OpenStreetMap). Respect its usage policy and add your contact email in the User-Agent header in `lib/main.dart`.

## iOS builds

iOS requires Apple code signing. You can add a separate macOS workflow and provide App Store Connect API key or certificates as secrets. Without those, CI cannot produce a publishable `.ipa`.