# Hardware Notes

## PAX

- PAX sales use the existing BroadPOS TCP bridge on port `10009`.
- Tip prompt is now enabled by default with `requestTipOnTerminal`.
- The approved payment stores `hostRefNum` when returned by PAX.
- The Void button now sends a PAX void request instead of only closing the socket.
- If your processor/PAX build uses a different BroadPOS void transaction type, update
  **Settings -> PAX Terminal -> Void Trans Type**. The default is `16`.

## Receipt Printer

Two receipt modes are available in **Settings -> Printer & Drawer**:

1. **Android system print dialog**
   - Uses Android/WebView printing.
   - Best fallback for built-in printers that expose an Android print service.

2. **ESC/POS network printer**
   - Sends raw ESC/POS receipt bytes to a printer IP and port, usually `9100`.
   - Works for many Ethernet/Wi-Fi thermal printers and some POS printers that expose
     a network print port.

Built-in Android POS printers are not universal. Some brands require a vendor SDK.
If the built-in printer does not appear in Android print services and does not expose
ESC/POS over network, add a vendor-specific Capacitor plugin for that hardware model.

## Cash Drawer RJ11

Most cash drawers connect by RJ11 to the receipt printer, not directly to the tablet.
The app sends the ESC/POS drawer pulse command to the printer:

```text
ESC p m t1 t2
```

Use **Settings -> Printer & Drawer -> Open Cash Drawer** to test. If the drawer does
not open, try the alternate RJ11 pin setting or confirm the drawer cable is connected
to the printer cash-drawer port.
