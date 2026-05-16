/**
 * hardwareBridge.js
 *
 * ESC/POS receipt printer + cash drawer support.
 * Drawer RJ11 is normally connected to the receipt printer, so the app sends
 * the drawer-kick command to the printer.
 */

import { Capacitor, registerPlugin } from '@capacitor/core';
import { getJSON, setJSON } from './storage';
import { SHOP, ORDER_TYPES, formatUSD } from '../config';

let TcpSocket = null;
function getTcpSocket() {
  if (!TcpSocket && Capacitor.isNativePlatform()) {
    TcpSocket = registerPlugin('TcpSocket');
  }
  return TcpSocket;
}

const CONFIG_KEY = 'vido_hardware_config';

const DEFAULT_CONFIG = {
  printerMode: 'system', // 'system' | 'network'
  printerIp: '',
  printerPort: 9100,
  printCopies: 1,
  openDrawerAfterCash: true,
  drawerPulsePin: 0,
  drawerPulseOn: 50,
  drawerPulseOff: 250,
};

function bytesToBase64(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

function cleanText(value, maxLen = 48) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\x20-\x7E]/g, '')
    .slice(0, maxLen);
}

function money(value) {
  return formatUSD(value || 0);
}

function line(left, right = '', width = 42) {
  const l = cleanText(left, width);
  const r = cleanText(right, width);
  if (!r) return l + '\n';
  const gap = Math.max(1, width - l.length - r.length);
  return l + ' '.repeat(gap) + r + '\n';
}

function wrapLine(text, indent = '  ', width = 42) {
  const raw = cleanText(text, 160);
  if (raw.length <= width - indent.length) return indent + raw + '\n';
  const words = raw.split(/\s+/);
  let out = '';
  let cur = indent;
  words.forEach(word => {
    if ((cur + word).length > width) {
      out += cur.trimEnd() + '\n';
      cur = indent + word + ' ';
    } else {
      cur += word + ' ';
    }
  });
  return out + cur.trimEnd() + '\n';
}

function textToBytes(text) {
  const out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) out[i] = text.charCodeAt(i) & 0xff;
  return out;
}

function concatBytes(parts) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  parts.forEach(part => {
    out.set(part, offset);
    offset += part.length;
  });
  return out;
}

function command(...values) {
  return new Uint8Array(values);
}

function drawerCommand(cfg) {
  const pin = Number(cfg.drawerPulsePin) === 1 ? 1 : 0;
  const on = Math.max(1, Math.min(255, Math.round((Number(cfg.drawerPulseOn) || 50) / 2)));
  const off = Math.max(1, Math.min(255, Math.round((Number(cfg.drawerPulseOff) || 250) / 2)));
  return command(0x1B, 0x70, pin, on, off);
}

export function buildEscPosReceipt({ order, totals, grandTotal, isCard, calcLineTotal }) {
  const d = order.completedAt ? new Date(order.completedAt) : new Date();
  const orderType = ORDER_TYPES.find(x => x.id === order.type);
  const parts = [
    command(0x1B, 0x40),                 // Initialize
    command(0x1B, 0x61, 0x01),           // Center
    command(0x1B, 0x45, 0x01),           // Bold on
    textToBytes(cleanText(SHOP.name || 'Shop', 32).toUpperCase() + '\n'),
    command(0x1B, 0x45, 0x00),           // Bold off
  ];

  if (SHOP.address) parts.push(textToBytes(cleanText(SHOP.address, 42) + '\n'));
  if (SHOP.phone) parts.push(textToBytes(cleanText(SHOP.phone, 42) + '\n'));

  parts.push(
    command(0x1B, 0x61, 0x00),
    textToBytes('-'.repeat(42) + '\n'),
    textToBytes(line('Receipt #:', String(order.number).padStart(6, '0'))),
    textToBytes(line('Type:', orderType?.label || '')),
    textToBytes(order.staffName ? line('Server:', order.staffName) : ''),
    textToBytes(line('Date:', d.toLocaleDateString())),
    textToBytes(line('Time:', d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }))),
    textToBytes('-'.repeat(42) + '\n')
  );

  (order.items || []).forEach(item => {
    const qtyName = `${item.qty || 1}x ${item.name}`;
    parts.push(textToBytes(line(qtyName, money(calcLineTotal(item)))));
    if (item.category !== 'snack' && item.category !== 'topping' && (item.size || item.sugar != null || item.ice != null)) {
      parts.push(textToBytes(wrapLine(`${item.size === 'L' ? 'Large' : 'Reg'}, ${item.sugar ?? 100}% sugar, ${item.ice ?? 100}% ice`)));
    }
    if (item.toppings?.length) {
      parts.push(textToBytes(wrapLine('+ ' + item.toppings.map(tp => tp.name).join(', '))));
    }
  });

  parts.push(
    textToBytes('-'.repeat(42) + '\n'),
    textToBytes(line('Subtotal', money(totals.sub))),
    textToBytes(totals.discount > 0 ? line('Discount', '-' + money(totals.discount)) : ''),
    textToBytes(line('Tax', money(totals.tax)))
  );

  if (isCard) {
    parts.push(
      textToBytes('-'.repeat(42) + '\n'),
      textToBytes(line('Credit Card', money(totals.total))),
      textToBytes(line('Card Type', order.cardType || '-')),
      textToBytes(line('Card Last 4', '**** ' + (order.cardLast4 || '----'))),
      textToBytes(line('Auth Code', order.authCode || '-')),
      textToBytes(line('Tip', money(order.tip || 0))),
      command(0x1B, 0x45, 0x01),
      textToBytes(line('TOTAL', money(grandTotal))),
      command(0x1B, 0x45, 0x00)
    );
  } else {
    parts.push(
      command(0x1B, 0x45, 0x01),
      textToBytes(line('TOTAL', money(grandTotal))),
      command(0x1B, 0x45, 0x00),
      textToBytes('-'.repeat(42) + '\n'),
      textToBytes(line('Cash', money(order.cashReceived || grandTotal))),
      textToBytes(order.changeGiven > 0 ? line('Change', money(order.changeGiven)) : '')
    );
  }

  parts.push(
    textToBytes('-'.repeat(42) + '\n'),
    command(0x1B, 0x61, 0x01),
    textToBytes(cleanText(SHOP.receiptFooter || 'Thank you!', 42) + '\n'),
    textToBytes('Customer Copy\n\n\n\n'),
    command(0x1D, 0x56, 0x41, 0x10)      // Partial cut
  );

  return concatBytes(parts);
}

class HardwareService {
  constructor() {
    this.config = { ...DEFAULT_CONFIG };
    this.isNative = Capacitor.isNativePlatform();
    this._loadConfig();
  }

  async _loadConfig() {
    const saved = await getJSON(CONFIG_KEY, null);
    if (saved) this.config = { ...DEFAULT_CONFIG, ...saved };
  }

  async updateConfig(cfg) {
    this.config = { ...this.config, ...cfg };
    await setJSON(CONFIG_KEY, this.config);
  }

  canUseNetworkPrinter() {
    return this.isNative && this.config.printerMode === 'network' && !!this.config.printerIp;
  }

  async testPrinter() {
    if (!this.canUseNetworkPrinter()) {
      return { ok: false, error: 'Network printer is not configured or app is not running as Android APK.' };
    }
    let socketId = null;
    try {
      socketId = await this._connect();
      await this._close(socketId);
      return { ok: true, model: 'ESC/POS network printer', ip: this.config.printerIp };
    } catch (e) {
      if (socketId) {
        try { await this._close(socketId); } catch {}
      }
      return { ok: false, error: e.message || 'Printer connection failed' };
    }
  }

  async printReceipt(args) {
    if (!this.canUseNetworkPrinter()) {
      throw new Error('Network printer is not configured');
    }
    const copies = Math.max(1, Math.min(3, Number(this.config.printCopies) || 1));
    const receipt = buildEscPosReceipt(args);
    for (let i = 0; i < copies; i++) {
      await this._sendBytes(receipt);
    }
    return { ok: true, copies };
  }

  async openCashDrawer() {
    if (!this.canUseNetworkPrinter()) {
      throw new Error('Network printer is not configured');
    }
    await this._sendBytes(drawerCommand(this.config));
    return { ok: true };
  }

  async _connect() {
    const plugin = getTcpSocket();
    if (!plugin) throw new Error('TcpSocket plugin not available');
    const res = await plugin.connect({
      host: this.config.printerIp,
      port: Number(this.config.printerPort) || 9100,
      timeout: 5000,
    });
    return res.socketId;
  }

  async _sendBytes(bytes) {
    const plugin = getTcpSocket();
    const socketId = await this._connect();
    try {
      await plugin.send({ socketId, data: bytesToBase64(bytes) });
    } finally {
      try { await this._close(socketId); } catch {}
    }
  }

  async _close(socketId) {
    const plugin = getTcpSocket();
    return plugin.close({ socketId });
  }
}

export const hardwareService = new HardwareService();
