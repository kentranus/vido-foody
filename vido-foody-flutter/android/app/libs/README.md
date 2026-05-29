# Drop POSLink JAR here

Place the PAX POSLink Android SDK JAR file in this folder to enable real
credit card payments through a PAX terminal.

**Filename format**: `POSLink_VX.XX.XX_YYYYMMDD.jar`
(e.g. `POSLink_V1.15.00_20240425.jar` or `POSLink_V1.14.00_20231101.jar`)

## How to get the JAR

1. Contact your PAX Technology representative or your payment processor's
   developer support (Worldpay, Heartland, TSYS, Elavon, etc.)
2. They will provide download access to `POSLink Java Android SDK`
3. Unzip the package and copy ONLY the `POSLink_VX.XX.XX_YYYYMMDD.jar` file
   into this `libs/` folder

## Known issues

- **E-series terminals (E500/E600/E700/E800) with V1.15**: USB communication
  has a bug causing Q20 network issues. Use V1.14.00_20231101 OR switch to
  TCP/HTTP/HTTPS/SSL communication. See PAX Known Critical Issues page.

## Verification

After dropping the JAR in, rebuild and the app log will show:

```
PosLinkSdk: POSLink SDK detected — real payments enabled
```

instead of:

```
PosLinkSdk: POSLink SDK not bundled — running in MOCK mode.
```

The CFD settings sheet → "PAX Terminal" section will also show
"Mode: Real" vs "Mode: Mock".

## Without the JAR

The app still builds and runs. All payment calls return a successful mock
response so you can develop and test the cashier UI without a physical PAX
terminal. The "Mock" badge is shown in the payment screen.
