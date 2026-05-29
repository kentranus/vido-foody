import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import crypto from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const PORT = Number(process.env.PORT || 8787);
const DATA_FILE = process.env.VIDO_DATA_FILE || path.join(process.cwd(), 'data', 'vido-foody-state.json');
const DEFAULT_STORE_ID = 'store_demo';
const DEFAULT_OWNER_EMAIL = process.env.VIDO_OWNER_EMAIL || 'owner@vidofoody.local';
const DEFAULT_OWNER_PASSWORD = process.env.VIDO_OWNER_PASSWORD || 'demo1234';

function createInitialState() {
  return {
  platform: {
    name: 'Vido Foody Platform',
    mode: 'pilot',
  },
  accounts: [
    {
      id: 'acct_owner_demo',
      storeId: DEFAULT_STORE_ID,
      role: 'owner',
      name: 'Demo Owner',
      email: DEFAULT_OWNER_EMAIL,
      passwordHash: hashPassword(DEFAULT_OWNER_PASSWORD),
      status: 'active',
      createdAt: new Date().toISOString(),
    },
  ],
  stores: [
    {
      id: DEFAULT_STORE_ID,
      slug: 'vido-foody-demo',
      name: 'Vido Foody Demo',
      status: 'active',
      subscriptionStatus: 'active',
      onlineOrderingEnabled: true,
      onlineOrderUrl: 'https://vidocenter.com/foody/vido-foody-demo',
      requireOnlineOrderAccept: true,
      autoPrintKioskPaidOrders: true,
      createdAt: new Date().toISOString(),
    },
  ],
  devices: [],
  sessions: [],
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
    kiosks: [
      {
        deviceId: 'KIOSK-1',
        name: 'Front Kiosk 1',
        enabled: true,
        connectionMode: 'tcp',
        terminalIp: process.env.KIOSK_PAX_IP || '192.168.68.59',
        terminalPort: Number(process.env.KIOSK_PAX_PORT || 10009),
        timeoutMs: 60000,
        requirePaymentBeforeSend: true,
      },
    ],
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

function hashPassword(password) {
  return crypto.createHash('sha256').update(String(password)).digest('hex');
}

function publicStore(store) {
  if (!store) return null;
  return {
    id: store.id,
    slug: store.slug,
    name: store.name,
    status: store.status,
    subscriptionStatus: store.subscriptionStatus,
    onlineOrderingEnabled: store.onlineOrderingEnabled,
    onlineOrderUrl: store.onlineOrderUrl,
    requireOnlineOrderAccept: store.requireOnlineOrderAccept,
    autoPrintKioskPaidOrders: store.autoPrintKioskPaidOrders,
  };
}

function defaultStore() {
  return state.stores.find((store) => store.id === DEFAULT_STORE_ID) || state.stores[0];
}

function findStoreByIdOrSlug(value) {
  return state.stores.find((store) => store.id === value || store.slug === value);
}

function tokenFromReq(req) {
  const auth = req.headers.authorization || '';
  if (auth.toLowerCase().startsWith('bearer ')) return auth.slice(7).trim();
  return req.headers['x-vido-token'] || '';
}

function authContext(req, { required = false } = {}) {
  const token = tokenFromReq(req);
  const session = state.sessions.find((s) => s.token === token && new Date(s.expiresAt).getTime() > Date.now());
  if (!session) {
    if (required) throw Object.assign(new Error('Login required'), { statusCode: 401 });
    const store = defaultStore();
    return { account: null, store, storeId: store?.id || DEFAULT_STORE_ID };
  }
  const account = state.accounts.find((a) => a.id === session.accountId && a.status === 'active');
  const store = state.stores.find((s) => s.id === session.storeId && s.status === 'active');
  if (!account || !store) throw Object.assign(new Error('Account or store is not active'), { statusCode: 403 });
  return { account, store, storeId: store.id, session };
}

function normalizeOrder(body = {}, source = 'POS', storeId = DEFAULT_STORE_ID) {
  const now = new Date().toISOString();
  const paid = ['paid', 'paid online', 'approved'].includes(String(body.paymentStatus || '').toLowerCase());
  return {
    id: body.id || `${source.toLowerCase()}_${Date.now()}_${Math.random().toString(16).slice(2, 6)}`,
    storeId,
    source,
    deviceId: body.deviceId || '',
    customer: body.customer || body.customerName || '',
    customerPhone: body.customerPhone || '',
    status: body.status || (source === 'Online' ? 'pending_accept' : 'new'),
    paymentStatus: body.paymentStatus || (paid ? 'paid' : 'unpaid'),
    paymentMethod: body.paymentMethod || '',
    total: Number(body.total || 0),
    subtotal: Number(body.subtotal || 0),
    tax: Number(body.tax || 0),
    tip: Number(body.tip || 0),
    items: Array.isArray(body.items) ? body.items : [],
    notes: body.notes || '',
    shouldPrint: body.shouldPrint === true,
    acceptedAt: body.acceptedAt || null,
    printedAt: body.printedAt || null,
    createdAt: body.createdAt || now,
    completedAt: body.completedAt || null,
  };
}

const eventClients = new Map();

function sendEvent(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

function notifyStore(storeId, event, data) {
  const clients = eventClients.get(storeId) || [];
  for (const res of clients) {
    try { sendEvent(res, event, data); } catch {}
  }
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
    if (saved.platform) state.platform = { ...state.platform, ...saved.platform };
    if (Array.isArray(saved.accounts)) state.accounts = saved.accounts;
    if (Array.isArray(saved.stores)) state.stores = saved.stores;
    if (Array.isArray(saved.devices)) state.devices = saved.devices;
    if (Array.isArray(saved.sessions)) {
      state.sessions = saved.sessions.filter((session) => new Date(session.expiresAt).getTime() > Date.now());
    }
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
    'access-control-allow-headers': 'content-type, authorization, x-vido-token',
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

function reportSummary(storeId = DEFAULT_STORE_ID) {
  const active = state.orders.filter((o) => (o.storeId || DEFAULT_STORE_ID) === storeId && !['voided', 'refunded'].includes(o.status));
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
    refunds: state.orders.filter((o) => (o.storeId || DEFAULT_STORE_ID) === storeId && o.status === 'refunded').reduce((s, o) => s + Number(o.refundAmount || o.total || 0), 0),
    voids: state.orders.filter((o) => (o.storeId || DEFAULT_STORE_ID) === storeId && o.status === 'voided').length,
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

    if (req.method === 'POST' && url.pathname === '/api/auth/login') {
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      const account = state.accounts.find((a) => String(a.email).toLowerCase() === email && a.status === 'active');
      if (!account || account.passwordHash !== hashPassword(password)) {
        return sendJson(res, 401, { ok: false, error: 'Invalid email or password' });
      }
      const store = state.stores.find((s) => s.id === account.storeId && s.status === 'active');
      if (!store) return sendJson(res, 403, { ok: false, error: 'Store is not active' });
      if (store.subscriptionStatus !== 'active' && store.subscriptionStatus !== 'trial') {
        return sendJson(res, 402, { ok: false, error: 'Subscription is not active' });
      }
      const token = crypto.randomBytes(32).toString('hex');
      const session = {
        token,
        accountId: account.id,
        storeId: store.id,
        deviceId: body.deviceId || '',
        createdAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      };
      state.sessions.unshift(session);
      saveStateSoon();
      return sendJson(res, 200, {
        ok: true,
        token,
        account: { id: account.id, name: account.name, email: account.email, role: account.role },
        store: publicStore(store),
      });
    }

    if (req.method === 'POST' && url.pathname === '/api/auth/logout') {
      const token = tokenFromReq(req);
      state.sessions = state.sessions.filter((session) => session.token !== token);
      saveStateSoon();
      return sendJson(res, 200, { ok: true });
    }

    if (req.method === 'GET' && url.pathname === '/api/auth/me') {
      const ctx = authContext(req, { required: true });
      return sendJson(res, 200, {
        ok: true,
        account: { id: ctx.account.id, name: ctx.account.name, email: ctx.account.email, role: ctx.account.role },
        store: publicStore(ctx.store),
      });
    }

    if (req.method === 'GET' && url.pathname === '/api/stores/me') {
      const ctx = authContext(req, { required: true });
      return sendJson(res, 200, { ok: true, store: publicStore(ctx.store), settings: state.settings, menu: state.menu });
    }

    if (req.method === 'POST' && url.pathname === '/api/devices/register') {
      const ctx = authContext(req, { required: true });
      const device = {
        id: body.deviceId || `dev_${Date.now()}`,
        storeId: ctx.storeId,
        type: body.type || 'pos',
        name: body.name || body.deviceId || 'Device',
        status: 'online',
        appVersion: body.appVersion || '',
        lastSeenAt: new Date().toISOString(),
      };
      const index = state.devices.findIndex((d) => d.id === device.id && d.storeId === ctx.storeId);
      if (index >= 0) state.devices[index] = { ...state.devices[index], ...device };
      else state.devices.unshift(device);
      saveStateSoon();
      return sendJson(res, 200, { ok: true, device });
    }

    if (req.method === 'GET' && url.pathname === '/api/devices') {
      const ctx = authContext(req, { required: true });
      return sendJson(res, 200, { ok: true, devices: state.devices.filter((d) => d.storeId === ctx.storeId) });
    }

    if (req.method === 'GET' && url.pathname === '/api/events') {
      const ctx = authContext(req, { required: true });
      res.writeHead(200, {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        connection: 'keep-alive',
        'access-control-allow-origin': '*',
      });
      const clients = eventClients.get(ctx.storeId) || [];
      clients.push(res);
      eventClients.set(ctx.storeId, clients);
      sendEvent(res, 'ready', { ok: true, storeId: ctx.storeId });
      req.on('close', () => {
        const next = (eventClients.get(ctx.storeId) || []).filter((client) => client !== res);
        eventClients.set(ctx.storeId, next);
      });
      return;
    }

    if (req.method === 'GET' && url.pathname.startsWith('/api/public/stores/')) {
      const slug = decodeURIComponent(url.pathname.split('/')[4] || '');
      const store = findStoreByIdOrSlug(slug);
      if (!store || !store.onlineOrderingEnabled) return sendJson(res, 404, { ok: false, error: 'Store not found or online ordering disabled' });
      return sendJson(res, 200, { ok: true, store: publicStore(store), menu: state.menu, settings: { shop: state.settings.shop } });
    }

    if (req.method === 'POST' && url.pathname === '/api/admin/stores') {
      const adminSecret = process.env.VIDO_ADMIN_SECRET || 'dev-admin';
      if ((req.headers['x-admin-secret'] || body.adminSecret) !== adminSecret) {
        return sendJson(res, 403, { ok: false, error: 'Admin secret required' });
      }
      const slug = String(body.slug || body.name || `store-${Date.now()}`)
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');
      if (findStoreByIdOrSlug(slug)) return sendJson(res, 409, { ok: false, error: 'Store slug already exists' });
      const store = {
        id: body.storeId || `store_${Date.now()}`,
        slug,
        name: body.name || 'New Vido Foody Store',
        status: 'active',
        subscriptionStatus: body.subscriptionStatus || 'trial',
        onlineOrderingEnabled: body.onlineOrderingEnabled !== false,
        onlineOrderUrl: `https://vidocenter.com/foody/${slug}`,
        requireOnlineOrderAccept: body.requireOnlineOrderAccept !== false,
        autoPrintKioskPaidOrders: body.autoPrintKioskPaidOrders !== false,
        createdAt: new Date().toISOString(),
      };
      const account = {
        id: `acct_${Date.now()}`,
        storeId: store.id,
        role: 'owner',
        name: body.ownerName || 'Store Owner',
        email: String(body.email || '').trim().toLowerCase(),
        passwordHash: hashPassword(body.password || 'changeme123'),
        status: 'active',
        createdAt: new Date().toISOString(),
      };
      if (!account.email) return sendJson(res, 400, { ok: false, error: 'Owner email is required' });
      state.stores.unshift(store);
      state.accounts.unshift(account);
      saveStateSoon();
      return sendJson(res, 200, { ok: true, store: publicStore(store), account: { id: account.id, email: account.email, role: account.role } });
    }
    if (req.method === 'GET' && url.pathname === '/api/settings') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, store: publicStore(ctx.store), settings: state.settings });
    }
    if (req.method === 'POST' && url.pathname === '/api/settings') {
      state.settings = {
        ...state.settings,
        ...body,
        shop: { ...state.settings.shop, ...(body.shop || {}) },
        payment: { ...state.settings.payment, ...(body.payment || {}) },
        customerDisplay: { ...state.settings.customerDisplay, ...(body.customerDisplay || {}) },
        kiosks: Array.isArray(body.kiosks) ? body.kiosks : state.settings.kiosks,
      };
      saveStateSoon();
      return sendJson(res, 200, { ok: true, settings: state.settings });
    }
    if (req.method === 'GET' && url.pathname === '/api/menu') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, store: publicStore(ctx.store), menu: state.menu });
    }
    if (req.method === 'POST' && url.pathname === '/api/menu') {
      if (Array.isArray(body.categories)) state.menu.categories = body.categories;
      if (Array.isArray(body.items)) state.menu.items = body.items;
      saveStateSoon();
      return sendJson(res, 200, { ok: true, menu: state.menu });
    }
    if (req.method === 'GET' && url.pathname === '/api/orders') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, orders: state.orders.filter((order) => (order.storeId || DEFAULT_STORE_ID) === ctx.storeId) });
    }
    if (req.method === 'POST' && url.pathname === '/api/orders') {
      const ctx = authContext(req);
      const order = {
        ...normalizeOrder(body, body.source || 'POS', ctx.storeId),
        status: body.status || 'completed',
        completedAt: body.completedAt || new Date().toISOString(),
      };
      state.orders.unshift(order);
      saveStateSoon();
      notifyStore(ctx.storeId, 'order.created', { order });
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'POST' && url.pathname.startsWith('/api/orders/')) {
      const parts = url.pathname.split('/');
      const id = decodeURIComponent(parts[3] || '');
      const action = parts[4] || '';
      const ctx = authContext(req);
      const order = state.orders.find((o) => (o.storeId || DEFAULT_STORE_ID) === ctx.storeId && (String(o.id) === id || String(o.number) === id));
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
      notifyStore(ctx.storeId, `order.${action || 'updated'}`, { order });
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'GET' && url.pathname === '/api/online-orders') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, orders: state.onlineOrders.filter((order) => (order.storeId || DEFAULT_STORE_ID) === ctx.storeId) });
    }
    if (req.method === 'POST' && url.pathname === '/api/online-orders') {
      const store = findStoreByIdOrSlug(body.storeId || body.storeSlug || '') || defaultStore();
      const order = normalizeOrder({
        ...body,
        id: body.id || `WEB-${Date.now().toString().slice(-6)}`,
        status: body.status || (store.requireOnlineOrderAccept ? 'pending_accept' : 'new'),
        paymentStatus: body.paymentStatus || 'pay at store',
      }, body.source || 'Online', store.id);
      state.onlineOrders.unshift(order);
      saveStateSoon();
      notifyStore(store.id, 'online_order.created', { order });
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'POST' && url.pathname === '/api/kiosk/orders') {
      const store = findStoreByIdOrSlug(body.storeId || body.storeSlug || '') || defaultStore();
      const order = normalizeOrder({
        ...body,
        id: body.id || `KIOSK-${Date.now().toString().slice(-6)}`,
        status: body.status || 'new',
        paymentStatus: body.paymentStatus || 'paid',
        shouldPrint: store.autoPrintKioskPaidOrders !== false && String(body.paymentStatus || 'paid').toLowerCase().includes('paid'),
      }, body.source || `Kiosk${body.deviceId ? `-${body.deviceId}` : ''}`, store.id);
      state.onlineOrders.unshift(order);
      saveStateSoon();
      notifyStore(store.id, 'kiosk_order.created', { order });
      return sendJson(res, 200, { ok: true, order });
    }
    const kioskReceiptMatch = url.pathname.match(/^\/api\/kiosk\/orders\/([^/]+)\/receipt-phone$/);
    if (req.method === 'POST' && kioskReceiptMatch) {
      const store = findStoreByIdOrSlug(body.storeId || body.storeSlug || '') || defaultStore();
      const orderId = decodeURIComponent(kioskReceiptMatch[1]);
      const order = state.onlineOrders.find((o) => o.id === orderId && (o.storeId || DEFAULT_STORE_ID) === store.id);
      if (!order) return sendJson(res, 404, { ok: false, error: 'Order not found' });
      order.customerPhone = body.customerPhone || '';
      order.receiptRequested = Boolean(order.customerPhone);
      order.updatedAt = new Date().toISOString();
      saveStateSoon();
      notifyStore(store.id, 'kiosk_order.receipt_phone_updated', { order });
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'POST' && url.pathname.startsWith('/api/online-orders/')) {
      const ctx = authContext(req);
      const parts = url.pathname.split('/');
      const id = decodeURIComponent(parts[3] || '');
      const action = parts[4] || '';
      const order = state.onlineOrders.find((o) => o.id === id && (o.storeId || DEFAULT_STORE_ID) === ctx.storeId);
      if (!order) return sendJson(res, 404, { ok: false, error: 'Online order not found' });
      if (action === 'accept') {
        order.status = 'accepted';
        order.acceptedAt = new Date().toISOString();
        order.shouldPrint = true;
      } else if (action === 'reject') {
        order.status = 'rejected';
        order.rejectedAt = new Date().toISOString();
        order.rejectReason = body.reason || '';
        order.shouldPrint = false;
      } else if (action === 'print') {
        order.status = body.status || order.status;
        order.printedAt = new Date().toISOString();
        order.shouldPrint = false;
      } else {
        Object.assign(order, body);
        if (body.status === 'accepted') {
          order.acceptedAt = new Date().toISOString();
          order.shouldPrint = true;
        }
        if (body.status === 'printed') {
          order.printedAt = new Date().toISOString();
          order.shouldPrint = false;
        }
      }
      saveStateSoon();
      notifyStore(ctx.storeId, `online_order.${action || 'updated'}`, { order });
      return sendJson(res, 200, { ok: true, order });
    }
    if (req.method === 'GET' && url.pathname === '/api/reports/summary') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, summary: reportSummary(ctx.storeId) });
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
      const ctx = authContext(req);
      const settlement = { ...result, storeId: ctx.storeId, createdAt: new Date().toISOString() };
      state.settlements.unshift(settlement);
      saveStateSoon();
      return sendJson(res, 200, settlement);
    }
    if (req.method === 'GET' && url.pathname === '/api/payment/settlements') {
      const ctx = authContext(req);
      return sendJson(res, 200, { ok: true, settlements: state.settlements.filter((s) => (s.storeId || DEFAULT_STORE_ID) === ctx.storeId) });
    }
    if (req.method === 'POST' && url.pathname === '/api/hardware/open-drawer') {
      return sendJson(res, 501, { ok: false, error: 'Cash drawer must be implemented in Flutter Android platform channel for the POS device/printer.' });
    }
    if (req.method === 'POST' && url.pathname === '/api/receipt/print') {
      return sendJson(res, 501, { ok: false, error: 'Receipt printing must be implemented in Flutter Android platform channel for USB/network printer.' });
    }
    return sendJson(res, 404, { ok: false, error: 'Not found' });
  } catch (err) {
    return sendJson(res, err.statusCode || 500, { ok: false, error: err.message || String(err) });
  }
}

await loadState();

http.createServer(handle).listen(PORT, '0.0.0.0', () => {
  console.log(`Vido Foody Node.js backend running on http://0.0.0.0:${PORT}`);
  console.log(`Local IPs: ${localIps().join(', ') || 'none'}`);
  console.log(`Data file: ${DATA_FILE}`);
});
