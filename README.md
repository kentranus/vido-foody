# Vido Foody POS - Flutter + Node.js Handoff

This is the final handoff package for the dev team.

Important: the React/Capacitor prototype is intentionally not included as the production app. The app direction is Flutter for the tablet POS and Node.js for backend/API work.

## Folders

- `vido-foody-flutter/` - Flutter tablet POS app. This is the app your Flutter team should continue.
- `vido-foody-backend/` - Node.js backend/API starter.
- `docs/` - PAX/POSLink integration and migration notes.
- `.github/workflows/` - GitHub Actions checks for Flutter and Node.js.

## Current Status

This package is a Flutter + Node.js product-pilot handoff, not a completed Toast/Square/Clover-level production POS.

Implemented in the Flutter starting point:

- Sell screen with Vido Foody branding.
- 4-column menu grid.
- Large category and Add controls.
- Light and dark mode.
- Cash, Card Payment, and Gift Card labels.
- Payment settings screen for TCP/IP and USB direction.
- Operations, online orders, history, reports, and settings screens.
- Node backend integration path.

Still required for production:

- Complete 1:1 port of all final prototype behavior into Flutter.
- Native Android MethodChannel for PAX POSLink Java Android SDK.
- Real Card Payment sale, void, and refund through PAX/POSLink.
- Receipt printer and cash drawer native MethodChannel.
- Customer display native MethodChannel.
- Persistent database instead of only in-memory/demo state.
- Online ordering sync from `https://vidocenter.com/foody/`.
- Manager approval and audit trail for refund, void, discount, and ticket changes.
- Full settlement/batch reconciliation.

For pilot readiness, see `docs/PRODUCT_PILOT_SCOPE.md`.

## Run Backend

```bash
cd vido-foody-backend
npm install
npm start
```

Default backend:

```text
http://localhost:8787
```

For Android tablet testing, use the machine/server LAN IP instead of localhost.

Example:

```text
http://192.168.68.55:8787
```

## Run Flutter

```bash
cd vido-foody-flutter
flutter create .
flutter pub get
flutter run
```

For local backend testing on Android, enable cleartext HTTP in the generated Android app while developing:

```xml
android:usesCleartextTraffic="true"
```

## Payment / PAX Direction

Preferred production path:

```text
Flutter
-> Android MethodChannel
-> PAX POSLink Java Android SDK
-> PAX/BroadPOS terminal
```

TCP/IP can go through either native POSLink or backend BroadPOS TCP during development.
USB payment must be native Android through Flutter MethodChannel; Node.js cannot talk to the Android USB terminal directly.

See:

- `docs/PAX_POSLINK_INTEGRATION.md`
- `docs/FLUTTER_NODEJS_MIGRATION.md`

## What To Give The Dev Team

Give them this entire zip/folder. Tell them:

1. Flutter is the production app target.
2. Node.js is the backend target.
3. Do not continue React/Capacitor as production.
4. Use the docs to finish PAX, printer, cash drawer, customer display, and online ordering.
