# Vido Foody Flutter

Production-direction Flutter tablet POS app for Vido Foody with a Node.js backend.

The React/Capacitor version is only a UI/business-logic reference. This folder is the app your Flutter team should continue from.

## Run Backend

```bash
cd ../vido-foody-backend
npm start
```

Backend default URL: `http://localhost:8787`

Backend data is saved to:

```text
vido-foody-backend/data/vido-foody-state.json
```

Override with:

```bash
VIDO_DATA_FILE=/path/to/vido-foody-state.json npm start
```

For Android tablet testing, use the computer/server IP instead of `localhost`. Example:

```text
http://192.168.68.55:8787
```

## Run Flutter

```bash
flutter create .
flutter pub get
flutter run
```

After `flutter create .`, make sure Android allows cleartext HTTP for local backend testing by adding this to the generated Android manifest application tag:

```xml
android:usesCleartextTraffic="true"
```

## Included POS Features

- Sell screen with 4-column menu grid.
- Large category buttons and large Add buttons.
- Light/dark mode.
- Cash, Card Payment, and Gift Card payment labels.
- Tip flow on customer display/POS screen or PAX terminal mode.
- Operations screen with closeout, drawer, online order count, and batch status.
- Online Orders queue for website/marketplace orders.
- History and Reports screens.
- Payment Settings with TCP/IP, USB, timeout, settlement, and PAX mode controls.
- Vido Foody logo asset.

## Card Payment

Preferred production path:

```text
Flutter Android MethodChannel
→ PAX POSLink Java Android SDK
→ PAX/BroadPOS terminal
```

Method channel name reserved in the app:

```text
vido.foody/poslink
```

Required native methods:

```text
testConnection
sale
batchClose
openCashDrawer
printReceipt
customerDisplay
```

Development fallback:

```text
POST /api/payment/sale
```

The Node backend sends BroadPOS TCP to the card terminal on port `10009`. USB payment must be implemented through the Flutter Android native channel, not Node.js.
