# Vido Foody POS App

Flutter POS app package for staff/counter tablets.

## Folders

- `vido-foody-flutter/` - Flutter POS app.
- `vido-foody-backend/` - Node.js backend/API starter for store accounts, menu, orders, reports, online orders, kiosk orders, and payment bridge work.
- `docs/` - Platform, PAX/POSLink, and pilot scope notes.
- `.github/workflows/` - GitHub Actions workflow to build the POS APK and check the backend.

## Build POS APK On GitHub

Upload this whole folder to a GitHub repo. Then open:

```text
Actions -> Build Vido Foody POS APK -> Run workflow
```

The APK will be in the workflow artifact:

```text
vido-foody-pos-debug-apk
```

## Local Run

```bash
cd vido-foody-backend
npm install
npm start
```

```bash
cd vido-foody-flutter
flutter create .
flutter pub get
flutter run
```

## Notes

This POS app is separate from the kiosk app. It can still manage kiosk device/payment settings through the POS Settings screen.
