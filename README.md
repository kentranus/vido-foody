# Vido Foody

**Modern restaurant POS for boba/coffee/fast food shops.**
Yellow-orange Foody branding · Dark mode default · Web + Android APK from one codebase.

## Features

### Selling
- 🛒 Multi-order tabs (handle 3+ orders simultaneously)
- 🍔 Customize items: size, sugar %, ice %, toppings
- 🏠 Order types: Dine In / To Go / Delivery
- 🏷️ Discount ($ or %, manager PIN required)
- 📝 Order notes
- 🔍 Search menu items

### Payments
- 💵 **Cash** with quick amounts + change calculator
- 💳 **Card via PAX** (BroadPOS TCP, port 10009)
- 📱 **E-Wallet** (mark as paid)
- ✨ Customer chooses tip on PAX terminal
- 🖨️ Receipt printing via Android system print or ESC/POS network printer
- 💵 Cash drawer kick through receipt printer RJ11 port

### Reports
- 📅 Date range filter (Today / Week / Month / Custom)
- 💰 Stats: Sales, Tips, Orders, AOV, Tax
- 📊 Hourly sales chart
- 🥧 Payment method donut
- 🏆 Top sellers
- 📤 **Export CSV** for accounting

### Menu Management
- Add/Edit/Delete items + categories
- Mark items "Sold Out" temporarily
- Image URL or emoji+gradient
- Reset to defaults

### Staff & Security
- 🔐 PIN-based login (4-digit)
- 👤 Roles: Manager / Cashier
- 🔒 Manager-only: discounts, PAX settings, Staff management
- Default: Manager `1234` / Cashier `0000`

### System
- 🌑 Dark mode default + ☀️ Light mode toggle
- 💾 Persistent storage (orders, menu, settings)
- 📊 Order history with search
- 🌐 **Web preview** for debugging (open DevTools F12)
- ℹ️ About page with version + build info

## Brand

- **Primary**: `#F59E0B` (Foody yellow)
- **Accent**: `#FBBF24` (lighter yellow)
- **Logo**: White **F** on yellow-orange gradient

## Quick Start

### 1. Create GitHub repo
1. [github.com/new](https://github.com/new)
2. Name: `vido-foody`
3. **Public** (required for free GitHub Pages)
4. Don't add README
5. Create

### 2. Upload code
Use [GitHub Desktop](https://desktop.github.com) — handles hidden `.github` folder.

1. **File → Add Local Repository** → select `vido-pos-final` folder
2. **Publish repository**

### 3. Enable GitHub Pages
1. Repo → **Settings → Pages**
2. Source: **GitHub Actions**
3. Save

### 4. Wait for build (~5-10 min)
Tab **Actions** → workflow runs automatically, 3 jobs in parallel:
- ✅ Build web bundle
- ✅ Deploy to GitHub Pages → `https://USERNAME.github.io/vido-foody/`
- ✅ Build APK → Artifacts

### 5. Use it
- **Web preview**: open the GitHub Pages URL on any browser → see all errors in DevTools
- **Tablet APK**: Actions → latest run → download `vido-foody-apk-build-N`

### 6. PAX Setup
1. Open Vantiv/BroadPOS on PAX → note the IP
2. Vido Foody → **Settings → PAX Terminal** (Manager PIN required)
3. Enter IP, port `10009`
4. **Test Connection** → should say Connected

## Default Credentials

| Role     | PIN  |
|----------|------|
| Manager  | 1234 |
| Cashier  | 0000 |

**Change these in Settings → Staff after first sign in.**

## First-time setup for a NEW shop

When installing this app for a new customer/shop:

1. **Install APK** on the tablet
2. Sign in with Manager PIN (default `1234`)
3. **Settings → Shop Info** — Configure for this specific shop:
   - Shop name, branch, address, phone
   - Tax rate (e.g., 8.75%)
   - Currency symbol
   - Tip percentages
   - Receipt footer
4. **Settings → Menu Editor** — Customize menu for this shop
5. **Settings → Staff** — Change default PINs, add staff
6. **Settings → PAX Terminal** — Connect PAX A30 by IP
7. **Settings → Printer & Drawer** — Configure receipt printer and cash drawer
8. Ready to sell!

### Printer & Cash Drawer Setup

The app supports two receipt modes:

1. **Android system print dialog** — works with printers installed in Android print services.
2. **ESC/POS network printer** — sends raw receipt bytes to printer IP/port, usually `9100`.

For cash drawers, connect the drawer RJ11 cable to the receipt printer cash-drawer port, then use
**Settings → Printer & Drawer → Open Cash Drawer** to test. The drawer opens by ESC/POS pulse command
sent to the printer. Built-in POS printers from some vendors may require that vendor's Android SDK;
in that case use the Android print mode until a vendor-specific plugin is added.

All settings are saved on-device. Different tablets = different shops.

## Project Structure

```
vido-pos-final/
├── .github/workflows/build.yml      # Builds APK + deploys web
├── README.md
└── tablet-app/
    ├── package.json
    ├── vite.config.js
    ├── capacitor.config.ts
    ├── index.html
    ├── android-config/network_security_config.xml
    ├── android-plugin/              # Custom Java TCP plugin
    └── src/
        ├── main.jsx
        ├── App.jsx                  # Main shell + nav
        ├── theme.js                 # Foody yellow theme
        ├── config.js                # Shop info
        ├── version.js               # Build info (auto-injected)
        ├── components/Shared.jsx    # Modal, PIN, Button, Input
        ├── data/defaultMenu.js
        ├── services/
        │   ├── storage.js
        │   ├── menuStorage.js
        │   ├── orderStorage.js
        │   ├── staffStorage.js
        │   ├── hardwareBridge.js    # ESC/POS printer + cash drawer
        │   └── paxBridge.js         # PAX TCP + web simulation
        └── views/
            ├── OrderView.jsx        # Selling (main)
            ├── HistoryView.jsx
            ├── ReportsView.jsx
            └── SettingsView.jsx
```

## Customization

### Change shop info
Edit `tablet-app/src/config.js`:
```js
export const SHOP = {
  name: 'Your Shop',
  branch: 'Branch',
  address: '...',
  tax: 0.0875,  // 8.75%
};
```

### Change brand colors
Edit `tablet-app/src/theme.js` and `tablet-app/index.html` (for splash). Search and replace `#F59E0B` (primary) and `#FBBF24` (accent) with your brand colors.

### Change menu
In-app: **Settings → Menu Editor**. Or edit `tablet-app/src/data/defaultMenu.js`.

## Web vs Native

| Feature | Web preview | Tablet APK |
|---|---|---|
| Sell, cart, customize | ✅ | ✅ |
| Cash, E-Wallet | ✅ | ✅ |
| **PAX card payment** | 🤖 Simulated | ✅ Real TCP |
| **Receipt printing** | Browser print | Android print / ESC-POS network |
| **Cash drawer** | Not available | ESC/POS printer RJ11 pulse |
| Reports, History | ✅ | ✅ |
| Menu Editor | ✅ | ✅ |
| Storage | localStorage | Capacitor Preferences |

## Built with

- React 18 + Vite 5
- Capacitor 5 (Android)
- Lucide React icons
- Custom Java TCP plugin for BroadPOS and ESC/POS network printers

## License

Built for Vido Foody · Kenny · 2026
