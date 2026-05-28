import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const PORT = Number(process.env.PORT || 8787);
const DATA_FILE = process.env.VIDO_DATA_FILE || path.join(process.cwd(), 'data', 'vido-foody-state.json');

function createInitialState() {
  return {
  settings: {
    shop: {
      name: 'Vido Foody',
      branch: 'My Shop',
      taxRate: 0.0875,
      currencySymbol: '$',
      receiptFooter: 'Thank you! Visit us again',
    },
    payment: {
      connectionMode: 'tcp',
      ip: process.env.PAYMENT_TERMINAL_IP || '192.168.68.59',
      port: Number(process.env.PAYMENT_TERMINAL_PORT || 10009),
      timeoutMs: Number(process.env.PAYMENT_TIMEOUT_MS || 60000),
      protocolVersion: process.env.BROADPOS_VERSION || '1.28',
      separator: process.env.BROADPOS_SEPARATOR === 'FS' ? String.fromCharCode(0x1c) : '|',
      useLengthPrefix: process.env.BROADPOS_LENGTH_PREFIX === '1',
      lengthEndian: process.env.BROADPOS_LENGTH_ENDIAN || 'little',
      useLrc: process.env.BROADPOS_LRC !== '0',
      askTip: process.env.BROADPOS_ASK_TIP === '1',
      maxRetries: Number(process.env.BROADPOS_RETRIES || 3),
      autoSettlement: true,
      settlementTime: '03:00',
      settlementMode: 'pax_auto',
    },
    customerDisplay: {
      enabled: false,
      autoManage: true,
      brandName: 'Vido Foody',
      welcomeTitle: 'Welcome',
      welcomeSubtitle: 'Order when you are ready',
      footerText: 'Thank you for supporting us',
      fontScale: 0.84,
    },
  },
  menu: {
    categories: [
      { id: 'milk-tea', name: 'Milk Tea', icon: '🧋', order: 1 },
      { id: 'fruit-tea', name: 'Fruit Tea', icon: '🍑', order: 2 },
      { id: 'coffee', name: 'Coffee', icon: '☕', order: 3 },
      { id: 'smoothie', name: 'Smoothies', icon: '🥤', order: 4 },
      { id: 'snack', name: 'Snacks', icon: '🥐', order: 5 },
      { id: 'topping', name: 'Toppings', icon: '🟤', order: 6 },
    ],
    items: [
      item('classic', 'milk-tea', 'Classic Milk Tea', 5.50, '🧋'),
      item('brown-sugar', 'milk-tea', 'Brown Sugar Boba', 6.75, '🧋', true),
      item('oolong', 'milk-tea', 'Oolong Milk Tea', 5.75, '🧋'),
      item('matcha', 'milk-tea', 'Matcha Latte', 6.25, '🍵'),
      item('thai', 'milk-tea', 'Thai Milk Tea', 5.75, '🧋', true),
      item('taro', 'milk-tea', 'Taro Milk Tea', 6.25, '🧋'),
      item('jasmine', 'milk-tea', 'Jasmine Milk Tea', 5.75, '🌼'),
      item('honeydew', 'milk-tea', 'Honeydew Milk Tea', 6.00, '🍈'),
      item('mango', 'fruit-tea', 'Mango Green Tea', 5.75, '🥭'),
      item('strawberry', 'fruit-tea', 'Strawberry Tea', 6.25, '🍓'),
      item('passion', 'fruit-tea', 'Passion Fruit', 5.95, '🍊'),
      item('lychee', 'fruit-tea', 'Lychee Tea', 5.95, '🌸'),
      item('latte', 'coffee', 'Latte', 5.50, '☕'),
      item('iced-coffee', 'coffee', 'Iced Coffee', 4.95, '☕'),
      item('viet-coffee', 'coffee', 'Vietnamese Coffee', 5.25, '☕', true),
      item('mango-sm', 'smoothie', 'Mango Smoothie', 6.50, '🥤'),
      item('straw-sm', 'smoothie', 'Strawberry Smoothie', 6.50, '🥤'),
      item('waffle', 'snack', 'Bubble Waffle', 5.50, '🧇'),
      item('mochi', 'snack', 'Mochi (3 pcs)', 4.25, '🍡'),
      item('tapioca', 'topping', 'Tapioca Pearls', 0.75, '⚫', false, true),
      item('cheese-foam', 'topping', 'Cheese Foam', 1.25, '🧀', false, true),
      item('aloe', 'topping', 'Aloe Vera', 0.75, '🟢', false, true),
      item('jelly', 'topping', 'Lychee Jelly', 0.75, '🟣', false, true),
      item('pudding', 'topping', 'Egg Pudding', 0.95, '🟡', false, true),
    ],
  },
  orders: [],
  onlineOrders: [],
  settlements: [],
  };
}

const state = createInitialState();

function item(id, category, name, price, icon, popular = false, addon = false) {
  return { id, category, name, price, icon, popular, addon, available: true };
}

async function loadState() {
  try {
    const raw = await readFile(DATA_FILE, 'utf8');
    const saved = JSON.parse(raw);
    state.settings = {
      ...state.settings,
      ...(saved.settings || {}),
      shop: { ...state.settings.shop, ...(saved.settings?.shop || {}) },
      payment: { ...state.settings.payment, ...(saved.settings?.payment || {}) },
      customerDisplay: { ...state.settings.customerDisplay, ...(saved.settings?.customerDisplay || {}) },
    };
    if (saved.menu) state.menu = saved.menu;
    if (Array.isArray(saved.orders)) state.orders = saved.orders;
    if (Array.isArray(saved.onlineOrders)) state.onlineOrders = saved.onlineOrders;
    if (Array.isArray(saved.settlements)) state.settlements = saved.settlements;
  } catch (err) {
    if (err.code !== 'ENOENT') console.warn(`Could not load state file: ${err.message}`);
  }
}

let saveTimer = null;
function saveStateSoon() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    saveState().catch((err) => console.error(`Could not save state file: ${err.message}`));
  }, 150);
}

async function saveState() {
  await mkdir(path.dirname(DATA_FILE), { recursive: true });
  await writeFile(DATA_FILE, JSON.stringify(state, null, 2));
}

function sendJson(res, status, data) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,OPTIONS',
    'access-control-allow-headers': 'content-type',
  });
  res.end(body);
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function localIps() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((x) => x && x.family === 'IPv4' && !x.internal)
    .map((x) => x.address);
}

function mergedPaymentConfig(body = {}) {
  return { ...state.settings.payment, ...(body.payment || {}) };
}

function lrc(bytes) {
  let out = 0;
  for (const b of bytes) out ^= b;
  return out & 0xff;
}

function buildBroadposFrame(payload, cfg) {
  const payloadBytes = Buffer.from(payload, 'ascii');
  const parts = [Buffer.from([0x02])];
  if (cfg.useLengthPrefix) {
    const len = payloadBytes.length;
    parts.push(cfg.lengthEndian === 'big'
      ? Buffer.from([(len >> 8) & 0xff, len & 0xff])
      : Buffer.from([len & 0xff, (len >> 8) & 0xff]));
  }
  parts.push(payloadBytes, Buffer.from([0x03]));
  const noLrc = Buffer.concat(parts);
  if (!cfg.useLrc) return noLrc;
  return Buffer.concat([noLrc, Buffer.from([lrc(noLrc.subarray(1))])]);
}

function parseBroadposFrame(frame, cfg) {
  if (frame[0] !== 0x02) throw new Error(`No STX in response: 0x${frame[0]?.toString(16)}`);
  const start = cfg.useLengthPrefix ? 3 : 1;
  const etx = frame.indexOf(0x03, start);
  if (etx < 0) throw new Error('No ETX in response');
  return frame.subarray(start, etx).toString('ascii');
}

function readBroadposFrame(socket, cfg) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let started = false;
    let done = false;
    const timer = setTimeout(() => finish(new Error('timeout waiting for card terminal')), cfg.timeoutMs || 60000);

    function finish(err, frame) {
      if (done) return;
      done = true;
      clearTimeout(timer);
      socket.off('data', onData);
      socket.off('error', onError);
      if (err) reject(err);
      else resolve(frame);
    }

    function onError(err) { finish(err); }

    function onData(data) {
      for (const b of data) {
        if (!started) {
          if (b === 0x06) continue;
          if (b === 0x15) return finish(new Error('card terminal returned NAK'));
          if (b !== 0x02) continue;
          started = true;
        }
        chunks.push(b);
        if (!cfg.useLrc && b === 0x03) return finish(null, Buffer.from(chunks));
        if (cfg.useLrc && chunks.length > 2 && chunks[chunks.length - 2] === 0x03) {
          return finish(null, Buffer.from(chunks));
        }
      }
    }

    socket.on('data', onData);
    socket.on('error', onError);
    socket.on('close', () => {
      if (!done) finish(new Error(started ? 'connection closed before ETX' : 'connection closed before STX'));
    });
  });
}

function connectTerminal(cfg) {
  return new Promise((resolve, reject) => {
    if (!cfg.ip && cfg.connectionMode !== 'usb') return reject(new Error('Payment terminal IP is required for TCP/IP'));
    if (cfg.connectionMode === 'usb') return reject(new Error('USB payment requires Flutter Android POSLink MethodChannel, not Node.js backend.'));
    const socket = net.createConnection({ host: cfg.ip, port: Number(cfg.port || 10009) });
    socket.setNoDelay(true);
    socket.setTimeout(5000);
    socket.once('connect', () => {
      socket.setTimeout(0);
      resolve(socket);
    });
    socket.once('timeout', () => {
      socket.destroy();
      reject(new Error('connect timeout'));
    });
    socket.once('error', reject);
  });
}

async function broadposRequest(fields, cfg) {
  const sep = cfg.separator || '|';
  const payload = fields.join(sep);
  const frame = buildBroadposFrame(payload, cfg);
  const socket = await connectTerminal(cfg);
  try {
    let responseFrame;
    let lastError;
    const maxRetries = Math.max(1, Number(cfg.maxRetries || 3));
    for (let attempt = 1; attempt <= maxRetries; attempt += 1) {
      socket.write(frame);
      try {
        responseFrame = await readBroadposFrame(socket, cfg);
        break;
      } catch (err) {
        lastError = err;
        if (!String(err.message).includes('NAK') || attempt === maxRetries) throw err;
      }
    }
    if (!responseFrame) throw lastError || new Error('No response from card terminal');
    socket.write(Buffer.from([0x06]));
    return parseBroadposFrame(responseFrame, cfg).split(sep);
  } finally {
    socket.destroy();
  }
}

async function broadposSale({ amount, refNum, tipAmount = 0, cfg }) {
  const cents = Math.round(Number(amount) * 100);
  if (!Number.isFinite(cents) || cents <= 0) throw new Error('Sale amount must be greater than zero');
  const fields = [
    'T00',
    cfg.protocolVersion || '1.28',
    '01',
    String(cents),
    cfg.askTip || cfg.tipMode === 'paxTerminal' ? '1' : '0',
    refNum || `VF${Date.now().toString().slice(-8)}`,
    '',
    '',
    tipAmount ? `<TipAmt>${Math.round(Number(tipAmount) * 100)}</TipAmt>` : '',
  ];
  const response = await broadposRequest(fields, cfg);
  const responseCode = response[2] || '';
  const approved = responseCode === '000000' || responseCode === '000';
  return {
    ok: approved,
    approved,
    status: approved ? 'approved' : 'declined',
    responseCode,
    responseMessage: response[3] || '',
    authCode: response[4] || '',
    hostRefNum: response[5] || '',
    approvedAmount: (Number.parseInt(response[6] || String(cents), 10) || cents) / 100,
    tipAmount: (Number.parseInt(response[8] || String(Math.round(Number(tipAmount) * 100)), 10) || 0) / 100,
    cardType: response[9] || '',
    maskedCard: response[10] || '',
    raw: response,
  };
}

async function broadposBatchClose({ cfg, force = false }) {
  // BroadPOS raw fallback. Preferred production path is Flutter Android POSLink BatchRequest.
  const fields = [
    'B00',
    cfg.protocolVersion || '1.28',
    force ? 'FORCEBATCHCLOSE' : 'BATCHCLOSE',
    `BATCH${Date.now().toString().slice(-6)}`,
  ];
  const response = await broadposRequest(fields, cfg);
  const approved = ['000000', '000'].includes(response[2] || '');
  return {
    ok: approved,
    approved,
    batchNum: response[5] || response[4] || '',
    resultCode: response[2] || '',
    resultText: response[3] || '',
    raw: response,
  };
}

function reportSummary() {
  const active = state.orders.filter((o) => !['voided', 'refunded'].includes(o.status));
  const byTender = (method) => active.filter((o) => o.paymentMethod === method).reduce((s, o) => s + Number(o.total || 0), 0);
  return {
    netSales: active.reduce((s, o) => s + Number(o.total || 0), 0),
    grossSales: active.reduce((s, o) => s + Number(o.subtotal || 0), 0),
    tax: active.reduce((s, o) => s + Number(o.tax || 0), 0),
    tips: active.reduce((s, o) => s + Number(o.tip || 0), 0),
    orders: active.length,
    tenders: {
      cash: byTender('cash'),
      card: byTender('card'),
      giftcard: byTender('giftcard'),
      online: byTender('online'),
    },
    refunds: state.orders.filter((o) => o.status === 'refunded').reduce((s, o) => s + Number(o.total || 0), 0),
    voids: state.orders.filter((o) => o.status === 'voided').length,
  };
}

async function handle(req, res) {
  if (req.method === 'OPTIONS') return sendJson(res, 200, { ok: true });

  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const body = req.method === 'GET' ? {} : await readJson(req);

    if (req.method === 'GET' && url.pathname === '/api/health') {
      return sendJson(res, 200, { ok: true, service: 'vido-foody-backend', stack: 'nodejs', port: PORT, ips: localIps() });
    }
    if (req.method === 'GET' && url.pathname === '/api/settings') {
      return sendJson(res, 200, { ok: true, settings: state.settings });
    }
    if (req.method === 'POST' && url.pathname === '/api/settings') {
      state.settings = {
        ...state.settings,
        ...body,
        shop: { ...state.settings.shop, ...(body.shop || {}) },
        payment: { ...state.settings.payment, ...(body.payment || {}) },
        customerDisplay: { ...state.settings.customerDisplay, ...(body.customerDisplay || {}) },
      };
      saveStateSoon();
      return sendJson(res, 200, { ok: true, settings: state.settings });
    }
    if (req.method === 'GET' && url.pathname === '/api/menu') {
      return sendJson(res, 200, { ok: true, menu: state.menu });
    }
    if (req.method === 'POST' && url.pathname === '/api/menu') {
      if (Array.isArray(body.categories)) state.menu.categories = body.categories;
      if (Array.isArray(body.items)) state.menu.items = body.items;
      saveStateSoon();
      return sendJson(res, 200, { ok: true, menu: state.menu });
    }
    if (req.method === 'GET' && url.pathname === '/api/orders') {
      return sendJson(res, 200, { ok: true, orders: state.orders });
    }
    if (req.method === 'POST' && url.pathname === '/api/orders') {
      const order = { ...body, id: body.id || `ord_${Date.now()}`, completedAt: body.completedAt || new Date().toISOString() };
      state.orders.unshift(order);
      saveStateSoon();
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'POST' && url.pathname.startsWith('/api/orders/')) {
      const parts = url.pathname.split('/');
      const id = decodeURIComponent(parts[3] || '');
      const action = parts[4] || '';
      const order = state.orders.find((o) => String(o.id) === id || String(o.number) === id);
      if (!order) return sendJson(res, 404, { ok: false, error: 'Order not found' });
      if (action === 'refund') {
        order.status = 'refunded';
        order.refundAmount = Math.max(0, Number(body.amount || order.total || 0));
        order.refundReason = body.reason || '';
        order.refundedAt = new Date().toISOString();
      } else if (action === 'void') {
        order.status = 'voided';
        order.voidReason = body.reason || '';
        order.voidedAt = new Date().toISOString();
      } else {
        Object.assign(order, body, { updatedAt: new Date().toISOString() });
      }
      saveStateSoon();
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'GET' && url.pathname === '/api/online-orders') {
      return sendJson(res, 200, { ok: true, orders: state.onlineOrders });
    }
    if (req.method === 'POST' && url.pathname === '/api/online-orders') {
      const order = {
        id: body.id || `WEB-${Date.now().toString().slice(-6)}`,
        source: body.source || 'Website',
        customer: body.customer || 'Online Customer',
        paymentStatus: body.paymentStatus || 'pay at store',
        status: body.status || 'new',
        total: Number(body.total || 0),
        items: body.items || [],
        createdAt: new Date().toISOString(),
      };
      state.onlineOrders.unshift(order);
      saveStateSoon();
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'POST' && url.pathname.startsWith('/api/online-orders/')) {
      const id = decodeURIComponent(url.pathname.split('/').pop());
      const order = state.onlineOrders.find((o) => o.id === id);
      if (!order) return sendJson(res, 404, { ok: false, error: 'Online order not found' });
      Object.assign(order, body);
      saveStateSoon();
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'GET' && url.pathname === '/api/reports/summary') {
      return sendJson(res, 200, { ok: true, summary: reportSummary() });
    }
    if (req.method === 'POST' && url.pathname === '/api/payment/test-connection') {
      const cfg = mergedPaymentConfig(body);
      const socket = await connectTerminal(cfg);
      socket.destroy();
      return sendJson(res, 200, { ok: true, message: 'Connected to card terminal' });
    }
    if (req.method === 'POST' && url.pathname === '/api/payment/sale') {
      const cfg = mergedPaymentConfig(body);
      const result = await broadposSale({ amount: body.amount, refNum: body.refNum, tipAmount: body.tipAmount, cfg });
      return sendJson(res, 200, { ok: result.ok, result });
    }
    if (req.method === 'POST' && url.pathname === '/api/payment/batch-close') {
      const cfg = mergedPaymentConfig(body);
      const result = await broadposBatchClose({ cfg, force: body.forceClose === true });
      const settlement = { ...result, createdAt: new Date().toISOString() };
      state.settlements.unshift(settlement);
      saveStateSoon();
      return sendJson(res, 200, settlement);
    }
    if (req.method === 'GET' && url.pathname === '/api/payment/settlements') {
      return sendJson(res, 200, { ok: true, settlements: state.settlements });
    }
    if (req.method === 'POST' && url.pathname === '/api/hardware/open-drawer') {
      return sendJson(res, 501, { ok: false, error: 'Cash drawer must be implemented in Flutter Android platform channel for the POS device/printer.' });
    }
    if (req.method === 'POST' && url.pathname === '/api/receipt/print') {
      return sendJson(res, 501, { ok: false, error: 'Receipt printing must be implemented in Flutter Android platform channel for USB/network printer.' });
    }
    return sendJson(res, 404, { ok: false, error: 'Not found' });
  } catch (err) {
    return sendJson(res, 500, { ok: false, error: err.message || String(err) });
  }
}

await loadState();

http.createServer(handle).listen(PORT, '0.0.0.0', () => {
  console.log(`Vido Foody Node.js backend running on http://0.0.0.0:${PORT}`);
  console.log(`Local IPs: ${localIps().join(', ') || 'none'}`);
  console.log(`Data file: ${DATA_FILE}`);
});
