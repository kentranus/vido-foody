# Vido POS — Dual-Screen

Mobile-first Android POS with Customer-Facing Display on a secondary screen.

- **App ID**: `com.vido.pos.dual`
- **Label**: "Vido POS Dual"
- **Use case**: dual-screen POS terminal (Sunmi, Imin, Pax, RK3588…) where the
  customer sees a separate live receipt on the back screen
- **Hardware**: any Android device with a secondary display exposed via the
  Android Presentation API (HDMI / USB-C / built-in second screen)

## Features

Everything in the Single version, plus:

- **Customer Display** plugin (Kotlin Presentation API + WebView)
- Live receipt sync — cart updates push to the secondary screen in real time
- Payment state transitions (welcome → order → waiting → done)
- Diagnostic UI showing all detected displays + troubleshooting steps for RK3588
- "Test on first secondary" button to force-render demo data
- **PAX terminal integration** (same as Single) — when "Card" is selected,
  the customer screen shows "Please tap or insert your card" while the
  PAX terminal handles the transaction

## Build

```bash
flutter pub get
flutter build apk --release
```

Or push to GitHub → Actions builds debug + release APKs automatically.

## Setup

1. **PAX**: see `android/app/libs/README.md`
2. **Customer screen**: connect a second display, open app → tap "CFD" pill in
   top bar → toggle on. If no secondary display detected, follow the
   on-screen troubleshooting steps.

## Side-by-side install

Different `applicationId` from Single (`com.vido.pos.dual` vs
`com.vido.pos.single`) → both can be installed on the same device for testing.
