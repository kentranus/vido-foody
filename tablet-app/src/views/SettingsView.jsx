import React, { useState, useEffect } from 'react';
import {
  Plus, Edit3, Trash2, Save, Check, X, RefreshCw, WifiOff,
} from 'lucide-react';
import { C } from '../theme';
import { SHOP, formatUSD } from '../config';
import { paxService, getDebugLog, clearDebugLog, PAX_STATUS } from '../services/paxBridge';
import { hardwareService } from '../services/hardwareBridge';
import { saveMenu, saveCategories, resetMenuToDefaults } from '../services/menuStorage';
import { loadStaff, addStaff, updateStaff, deleteStaff } from '../services/staffStorage';
import { APP_VERSION, BUILD_DATE, BUILD_NUMBER, COMMIT_SHORT } from '../version';
import { DEFAULT_MENU } from '../data/defaultMenu';
import { Modal, ModalClose, Button, Input, Field, PinLockScreen } from '../components/Shared';
import { useShop } from '../App';

export function SettingsView({ menu, categories, refreshMenu, staff }) {
  const [tab, setTab] = useState('pax');
  const [needsManagerPin, setNeedsManagerPin] = useState(false);
  const [unlockedTab, setUnlockedTab] = useState(null);

  const requiresManager = (tabId) => ['staff', 'pax', 'hardware'].includes(tabId);

  const switchTab = (tabId) => {
    if (requiresManager(tabId) && staff.role !== 'manager' && unlockedTab !== tabId) {
      setNeedsManagerPin(tabId);
    } else {
      setTab(tabId);
    }
  };

  return (
    <div style={s.container}>
      <div style={s.title}>Settings</div>

      <div style={s.tabs}>
        {[
          { id: 'pax',   label: 'PAX Terminal', requiresMgr: true },
          { id: 'hardware', label: 'Printer & Drawer', requiresMgr: true },
          { id: 'menu',  label: 'Menu Editor' },
          { id: 'staff', label: 'Staff', requiresMgr: true },
          { id: 'shop',  label: 'Shop Info' },
          { id: 'about', label: 'About' },
        ].map(t => (
          <button key={t.id}
            onClick={() => switchTab(t.id)}
            style={{
              padding: '8px 18px', fontWeight: 800, fontSize: 13,
              borderRadius: 8, border: 'none',
              background: tab === t.id ? C.primary : 'transparent',
              color: tab === t.id ? C.bg : C.textMute,
              cursor: 'pointer',
            }}>
            {t.label}
            {t.requiresMgr && staff.role !== 'manager' && (
              <span style={{ marginLeft: 4, fontSize: 10 }}>🔒</span>
            )}
          </button>
        ))}
      </div>

      <div style={s.tabContent}>
        {tab === 'pax' && <PaxSettings />}
        {tab === 'hardware' && <HardwareSettings />}
        {tab === 'menu' && <MenuEditor menu={menu} categories={categories} refreshMenu={refreshMenu} />}
        {tab === 'staff' && <StaffManager />}
        {tab === 'shop' && <ShopInfo />}
        {tab === 'about' && <AboutTab />}
      </div>

      {needsManagerPin && (
        <PinLockScreen
          title="Manager PIN"
          subtitle="Required to access this section"
          managerOnly={true}
          fullScreen={false}
          onUnlock={() => {
            setUnlockedTab(needsManagerPin);
            setTab(needsManagerPin);
            setNeedsManagerPin(false);
          }}
          onCancel={() => setNeedsManagerPin(false)}
        />
      )}
    </div>
  );
}

// ============================================================================
// PAX SETTINGS — with protocol config, debug log, test sale
// ============================================================================
function PaxSettings() {
  const [cfg, setCfg] = useState({ ...paxService.config });
  const [testing, setTesting] = useState(false);
  const [result, setResult] = useState(null);
  const [saved, setSaved] = useState(false);
  const [testSaleRunning, setTestSaleRunning] = useState(false);
  const [testSaleResult, setTestSaleResult] = useState(null);
  const [log, setLog] = useState([]);
  const [showLog, setShowLog] = useState(false);

  useEffect(() => { setCfg({ ...paxService.config }); }, []);

  // Refresh log periodically while open
  useEffect(() => {
    const i = setInterval(() => setLog(getDebugLog()), 1000);
    return () => clearInterval(i);
  }, []);

  const test = async () => {
    setTesting(true);
    setResult(null);
    await paxService.updateConfig(cfg);
    const r = await paxService.ping();
    setTesting(false);
    setResult(r);
    setLog(getDebugLog());
  };

  const save = async () => {
    await paxService.updateConfig(cfg);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const runTestSale = async () => {
    if (!confirm('Run TEST SALE of $0.01? PAX will activate. Card holder can cancel on PAX. This is a real transaction if approved!')) return;
    setTestSaleRunning(true);
    setTestSaleResult(null);
    await paxService.updateConfig(cfg);
    try {
      const r = await paxService.sale(0.01, 'TEST' + Date.now().toString().slice(-6));
      setTestSaleResult({ ok: r.status.id === 'approved', detail: r });
    } catch (e) {
      setTestSaleResult({ ok: false, detail: { error: e.message } });
    } finally {
      setTestSaleRunning(false);
      setLog(getDebugLog());
    }
  };

  return (
    <div style={{ maxWidth: 720 }}>
      <div style={{
        background: C.primaryA, border: `1px solid ${C.primary}33`,
        padding: 14, borderRadius: 12, marginBottom: 18,
        fontSize: 13, color: C.primary, fontWeight: 700,
      }}>
        {paxService.isNative
          ? <>💡 Configure PAX terminal running BroadPOS US protocol. Use "Test Sale" to verify before going live.</>
          : <>🌐 Web preview — PAX calls are simulated.</>}
      </div>

      <div style={{ background: C.panel, padding: 18, borderRadius: 12, marginBottom: 14 }}>
        <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          Connection
        </div>
        <Field label="PAX IP Address">
          <Input value={cfg.ip} placeholder="e.g., 192.168.1.55"
            onChange={e => setCfg({ ...cfg, ip: e.target.value })} />
        </Field>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1 }}>
            <Field label="Port" hint="Default: 10009">
              <Input type="number" value={cfg.port}
                onChange={e => setCfg({ ...cfg, port: parseInt(e.target.value) || 10009 })} />
            </Field>
          </div>
          <div style={{ flex: 1 }}>
            <Field label="Timeout (ms)" hint="60000 = 60s">
              <Input type="number" value={cfg.timeout}
                onChange={e => setCfg({ ...cfg, timeout: parseInt(e.target.value) || 60000 })} />
            </Field>
          </div>
        </div>
      </div>

      <div style={{ background: C.panel, padding: 18, borderRadius: 12, marginBottom: 14 }}>
        <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          BroadPOS Protocol
        </div>
        <Field label="Protocol Version" hint="Match your BroadPOS version (1.28, 1.29, 2.0)">
          <Input value={cfg.protocolVersion || '1.28'}
            onChange={e => setCfg({ ...cfg, protocolVersion: e.target.value })} />
        </Field>
        <Field label="Field Separator" hint="Most BroadPOS use '|' (pipe). Some older use FS (0x1C).">
          <select value={cfg.separator || '|'}
            onChange={e => setCfg({ ...cfg, separator: e.target.value })}
            style={{
              width: '100%', padding: '10px 14px',
              background: C.card, color: C.text,
              border: `1px solid ${C.border}`, borderRadius: 10,
              fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
            }}>
            <option value="|">| (pipe) — standard</option>
            <option value={String.fromCharCode(0x1C)}>FS (0x1C) — older variant</option>
          </select>
        </Field>
        <div style={{ display: 'flex', gap: 20, marginTop: 10 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text }}>
            <input type="checkbox" checked={cfg.useLengthPrefix !== false}
              onChange={e => setCfg({ ...cfg, useLengthPrefix: e.target.checked })} />
            Length Prefix (2 bytes after STX)
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text }}>
            <input type="checkbox" checked={cfg.useLRC !== false}
              onChange={e => setCfg({ ...cfg, useLRC: e.target.checked })} />
            LRC checksum
          </label>
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 14 }}>
          <div style={{ flex: 1 }}>
            <Field label="Void Trans Type" hint="Match the PAX BroadPOS setting. Default: 16">
              <Input value={cfg.voidTransType || '16'}
                onChange={e => setCfg({ ...cfg, voidTransType: e.target.value.trim() || '16' })} />
            </Field>
          </div>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', paddingTop: 18 }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text }}>
              <input type="checkbox" checked={cfg.requestTipOnTerminal !== false}
                onChange={e => setCfg({ ...cfg, requestTipOnTerminal: e.target.checked })} />
              Ask tip on PAX terminal
            </label>
          </div>
        </div>
      </div>

      {result && (
        <div style={{
          padding: '10px 14px', borderRadius: 10,
          fontWeight: 700, fontSize: 13,
          background: result.ok ? C.primaryA : C.redA,
          color: result.ok ? C.primary : C.red,
          marginBottom: 12,
        }}>
          {result.ok ? `✓ Connected: ${result.model}` : `✗ Failed: ${result.error}`}
        </div>
      )}

      <div style={{ display: 'flex', gap: 10, marginBottom: 14, flexWrap: 'wrap' }}>
        <Button variant="ghost" onClick={test} disabled={testing || !cfg.ip}>
          {testing ? <><RefreshCw size={14} className="spin" /> Testing...</> : 'Test Connection'}
        </Button>
        <Button onClick={save}>
          {saved ? <><Check size={14} /> Saved</> : 'Save Settings'}
        </Button>
        <Button
          variant="danger"
          onClick={runTestSale}
          disabled={testSaleRunning || !cfg.ip}
          style={{ background: C.yellow, color: C.bg }}>
          {testSaleRunning ? <><RefreshCw size={14} className="spin" /> Running...</> : '🧪 Test Sale $0.01'}
        </Button>
      </div>

      {testSaleResult && (
        <div style={{
          padding: 14, borderRadius: 10,
          background: testSaleResult.ok ? C.primaryA : C.redA,
          color: testSaleResult.ok ? C.primary : C.red,
          marginBottom: 12, fontSize: 13, fontWeight: 700,
        }}>
          <div style={{ fontWeight: 900, marginBottom: 4 }}>
            {testSaleResult.ok ? '✓ Test Sale APPROVED' : '✗ Test Sale FAILED'}
          </div>
          <pre style={{ fontSize: 11, fontFamily: 'monospace', whiteSpace: 'pre-wrap', margin: 0 }}>
            {JSON.stringify(testSaleResult.detail, null, 2)}
          </pre>
        </div>
      )}

      {/* DEBUG LOG */}
      <div style={{ background: C.panel, padding: 18, borderRadius: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Debug Log ({log.length})
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <Button size="sm" variant="ghost" onClick={() => setShowLog(!showLog)}>
              {showLog ? 'Hide' : 'Show'}
            </Button>
            <Button size="sm" variant="ghost" onClick={() => { clearDebugLog(); setLog([]); }}>Clear</Button>
          </div>
        </div>
        {showLog ? (
          <div style={{ maxHeight: 360, overflowY: 'auto', fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>
            {log.length === 0 ? (
              <div style={{ color: C.textDim, padding: 12, textAlign: 'center' }}>
                No events yet. Try Test Connection or Test Sale.
              </div>
            ) : log.map((e, i) => (
              <div key={i} style={{
                padding: '8px 10px',
                borderBottom: `1px solid ${C.border}`,
                background: e.type === 'error' ? C.redA : e.type === 'tx' ? 'rgba(59,130,246,0.08)' : e.type === 'rx' ? C.primaryA : 'transparent',
              }}>
                <div style={{ display: 'flex', gap: 8, marginBottom: 4 }}>
                  <span style={{
                    background: e.type === 'error' ? C.red : e.type === 'tx' ? C.blue : e.type === 'rx' ? C.primary : C.textMute,
                    color: e.type === 'rx' ? C.bg : '#fff',
                    padding: '1px 6px', borderRadius: 4, fontSize: 10, fontWeight: 800,
                  }}>
                    {e.type.toUpperCase()}
                  </span>
                  <span style={{ color: C.textMute, fontSize: 10 }}>{new Date(e.time).toLocaleTimeString()}</span>
                  <span style={{ color: C.text, fontWeight: 700 }}>{e.message}</span>
                </div>
                {e.hex && (
                  <div style={{ marginLeft: 4, color: C.textMute }}>
                    <div>HEX: <span style={{ color: C.text }}>{e.hex}</span></div>
                    <div>ASCII: <span style={{ color: C.text }}>{e.ascii}</span></div>
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div style={{ fontSize: 12, color: C.textMute, fontWeight: 700 }}>
            Show log to see raw TCP traffic (TX/RX bytes in HEX + ASCII).
            Use this to verify protocol format with PAX support.
          </div>
        )}
      </div>
    </div>
  );
}

// ============================================================================
// HARDWARE SETTINGS — receipt printer + cash drawer through ESC/POS
// ============================================================================
function HardwareSettings() {
  const [cfg, setCfg] = useState({ ...hardwareService.config });
  const [saved, setSaved] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState(null);
  const [drawerBusy, setDrawerBusy] = useState(false);

  useEffect(() => { setCfg({ ...hardwareService.config }); }, []);

  const save = async () => {
    await hardwareService.updateConfig(cfg);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const testPrinter = async () => {
    setTesting(true);
    setTestResult(null);
    await hardwareService.updateConfig(cfg);
    const result = await hardwareService.testPrinter();
    setTestResult(result);
    setTesting(false);
  };

  const openDrawer = async () => {
    setDrawerBusy(true);
    setTestResult(null);
    await hardwareService.updateConfig(cfg);
    try {
      await hardwareService.openCashDrawer();
      setTestResult({ ok: true, model: 'Cash drawer pulse sent' });
    } catch (e) {
      setTestResult({ ok: false, error: e.message });
    } finally {
      setDrawerBusy(false);
    }
  };

  return (
    <div style={{ maxWidth: 720 }}>
      <div style={{
        background: C.primaryA, border: `1px solid ${C.primary}33`,
        padding: 14, borderRadius: 12, marginBottom: 18,
        fontSize: 13, color: C.primary, fontWeight: 700,
      }}>
        Receipt printing can use Android system print, or ESC/POS network printer on port 9100.
        RJ11 cash drawers usually open through the receipt printer.
      </div>

      <div style={{ background: C.panel, padding: 18, borderRadius: 12, marginBottom: 14 }}>
        <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          Receipt Printer
        </div>
        <Field label="Printer Mode">
          <select value={cfg.printerMode || 'system'}
            onChange={e => setCfg({ ...cfg, printerMode: e.target.value })}
            style={{
              width: '100%', padding: '10px 14px',
              background: C.card, color: C.text,
              border: `1px solid ${C.border}`, borderRadius: 10,
              fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
            }}>
            <option value="system">Android system print dialog</option>
            <option value="network">ESC/POS network printer (IP:9100)</option>
          </select>
        </Field>

        {cfg.printerMode === 'network' && (
          <>
            <Field label="Printer IP Address">
              <Input value={cfg.printerIp || ''} placeholder="e.g., 192.168.1.60"
                onChange={e => setCfg({ ...cfg, printerIp: e.target.value })} />
            </Field>
            <div style={{ display: 'flex', gap: 10 }}>
              <div style={{ flex: 1 }}>
                <Field label="Port" hint="Most ESC/POS printers use 9100">
                  <Input type="number" value={cfg.printerPort || 9100}
                    onChange={e => setCfg({ ...cfg, printerPort: parseInt(e.target.value) || 9100 })} />
                </Field>
              </div>
              <div style={{ flex: 1 }}>
                <Field label="Copies">
                  <Input type="number" min="1" max="3" value={cfg.printCopies || 1}
                    onChange={e => setCfg({ ...cfg, printCopies: parseInt(e.target.value) || 1 })} />
                </Field>
              </div>
            </div>
          </>
        )}
      </div>

      <div style={{ background: C.panel, padding: 18, borderRadius: 12, marginBottom: 14 }}>
        <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          Cash Drawer
        </div>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text, marginBottom: 12 }}>
          <input type="checkbox" checked={cfg.openDrawerAfterCash !== false}
            onChange={e => setCfg({ ...cfg, openDrawerAfterCash: e.target.checked })} />
          Open drawer automatically after cash payment
        </label>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1 }}>
            <Field label="RJ11 Pin">
              <select value={cfg.drawerPulsePin || 0}
                onChange={e => setCfg({ ...cfg, drawerPulsePin: parseInt(e.target.value) || 0 })}
                style={{
                  width: '100%', padding: '10px 14px',
                  background: C.card, color: C.text,
                  border: `1px solid ${C.border}`, borderRadius: 10,
                  fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
                }}>
                <option value={0}>Pin 2 / drawer 1</option>
                <option value={1}>Pin 5 / drawer 2</option>
              </select>
            </Field>
          </div>
          <div style={{ flex: 1 }}>
            <Field label="Pulse On (ms)">
              <Input type="number" value={cfg.drawerPulseOn || 50}
                onChange={e => setCfg({ ...cfg, drawerPulseOn: parseInt(e.target.value) || 50 })} />
            </Field>
          </div>
          <div style={{ flex: 1 }}>
            <Field label="Pulse Off (ms)">
              <Input type="number" value={cfg.drawerPulseOff || 250}
                onChange={e => setCfg({ ...cfg, drawerPulseOff: parseInt(e.target.value) || 250 })} />
            </Field>
          </div>
        </div>
      </div>

      {testResult && (
        <div style={{
          padding: '10px 14px', borderRadius: 10,
          fontWeight: 700, fontSize: 13,
          background: testResult.ok ? C.primaryA : C.redA,
          color: testResult.ok ? C.primary : C.red,
          marginBottom: 12,
        }}>
          {testResult.ok ? `OK: ${testResult.model}` : `Failed: ${testResult.error}`}
        </div>
      )}

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <Button onClick={save}>{saved ? <><Check size={14} /> Saved</> : 'Save Hardware Settings'}</Button>
        <Button variant="ghost" onClick={testPrinter} disabled={testing || cfg.printerMode !== 'network' || !cfg.printerIp}>
          {testing ? 'Testing...' : 'Test Printer Connection'}
        </Button>
        <Button variant="ghost" onClick={openDrawer} disabled={drawerBusy || cfg.printerMode !== 'network' || !cfg.printerIp}>
          {drawerBusy ? 'Opening...' : 'Open Cash Drawer'}
        </Button>
      </div>
    </div>
  );
}

// ============================================================================
// MENU EDITOR
// ============================================================================
function MenuEditor({ menu, categories, refreshMenu }) {
  const [editing, setEditing] = useState(null);
  const [editingCat, setEditingCat] = useState(null);
  const [showCatModal, setShowCatModal] = useState(false);

  const saveItem = async (item) => {
    const m = item.id && menu.some(x => x.id === item.id)
      ? menu.map(x => x.id === item.id ? item : x)
      : [...menu, { ...item, id: 'item_' + Date.now() }];
    await saveMenu(m);
    await refreshMenu();
    setEditing(null);
  };

  const removeItem = async (id) => {
    if (confirm('Delete this item?')) {
      await saveMenu(menu.filter(m => m.id !== id));
      await refreshMenu();
    }
  };

  const saveCat = async (cat) => {
    const c = cat.id && categories.some(x => x.id === cat.id)
      ? categories.map(x => x.id === cat.id ? cat : x)
      : [...categories, { ...cat, id: 'cat_' + Date.now(), order: categories.length + 1 }];
    await saveCategories(c);
    await refreshMenu();
    setShowCatModal(false);
    setEditingCat(null);
  };

  const removeCat = async (id) => {
    if (confirm('Delete this category?')) {
      await saveCategories(categories.filter(c => c.id !== id));
      await refreshMenu();
    }
  };

  const reset = async () => {
    if (confirm('Reset menu to defaults? Custom items will be lost.')) {
      await resetMenuToDefaults();
      await refreshMenu();
    }
  };

  const toggleAvailable = async (item) => {
    const m = menu.map(x => x.id === item.id ? { ...x, available: !x.available } : x);
    await saveMenu(m);
    await refreshMenu();
  };

  return (
    <div>
      {/* CATEGORIES */}
      <div style={{ marginBottom: 24 }}>
        <div style={s.sectionHead}>
          <div style={{ fontSize: 14, fontWeight: 900, color: C.text }}>Categories ({categories.length})</div>
          <Button size="sm" onClick={() => { setEditingCat({}); setShowCatModal(true); }}>
            <Plus size={12} style={{ verticalAlign: 'middle' }} /> Add Category
          </Button>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {categories.map(c => (
            <div key={c.id} style={s.catEditCard}>
              <span style={{ fontSize: 18 }}>{c.icon}</span>
              <span style={{ fontWeight: 800, fontSize: 13, color: C.text }}>{c.name}</span>
              <button onClick={() => { setEditingCat(c); setShowCatModal(true); }} style={s.iconBtn}><Edit3 size={12} /></button>
              <button onClick={() => removeCat(c.id)} style={s.iconBtn}><Trash2 size={12} /></button>
            </div>
          ))}
        </div>
      </div>

      {/* ITEMS */}
      <div style={s.sectionHead}>
        <div style={{ fontSize: 14, fontWeight: 900, color: C.text }}>Items ({menu.length})</div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button size="sm" variant="ghost" onClick={reset}>Reset to defaults</Button>
          <Button size="sm" onClick={() => setEditing({})}>
            <Plus size={12} style={{ verticalAlign: 'middle' }} /> Add Item
          </Button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 10 }}>
        {menu.map(item => {
          const cat = categories.find(c => c.id === item.category);
          return (
            <div key={item.id} style={{
              ...s.itemCard,
              opacity: item.available ? 1 : 0.5,
            }}>
              <div style={{
                width: 50, height: 50,
                background: item.image ? `url(${item.image}) center/cover` : item.gradient,
                borderRadius: 8, flexShrink: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24,
              }}>
                {!item.image && item.emoji}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 800, fontSize: 13, color: C.text }}>
                  {item.name}
                  {!item.available && <span style={{ marginLeft: 6, fontSize: 10, color: C.red, fontWeight: 900 }}>SOLD OUT</span>}
                </div>
                <div style={{ fontSize: 11, color: C.textMute, fontWeight: 700, marginTop: 2 }}>
                  {cat?.name || item.category} · {formatUSD(item.price)}
                </div>
              </div>
              <button onClick={() => toggleAvailable(item)} style={s.iconBtn} title={item.available ? 'Mark sold out' : 'Mark available'}>
                {item.available ? '✓' : '✕'}
              </button>
              <button onClick={() => setEditing(item)} style={s.iconBtn}><Edit3 size={14} /></button>
              <button onClick={() => removeItem(item.id)} style={s.iconBtn}><Trash2 size={14} /></button>
            </div>
          );
        })}
      </div>

      {editing !== null && (
        <ItemEditModal
          item={editing} categories={categories}
          onSave={saveItem} onClose={() => setEditing(null)}
        />
      )}
      {showCatModal && (
        <CategoryEditModal
          cat={editingCat || {}}
          onSave={saveCat}
          onClose={() => { setShowCatModal(false); setEditingCat(null); }}
        />
      )}
    </div>
  );
}

function ItemEditModal({ item, categories, onSave, onClose }) {
  const [form, setForm] = useState({
    name: item.name || '',
    price: item.price || 0,
    category: item.category || categories[0]?.id,
    image: item.image || '',
    emoji: item.emoji || '🧋',
    gradient: item.gradient || 'linear-gradient(135deg, #F4D9B0, #C9A87C)',
    popular: item.popular || false,
    available: item.available !== false,
    isAddon: item.isAddon || false,
  });

  const handleSave = () => {
    if (!form.name.trim()) return;
    onSave({
      ...item,
      ...form,
      price: parseFloat(form.price) || 0,
    });
  };

  return (
    <Modal onClose={onClose}>
      <div style={{ padding: 24 }}>
        <ModalClose onClose={onClose} />
        <div style={{ fontSize: 20, fontWeight: 900, color: C.text, marginBottom: 18 }}>
          {item.id ? 'Edit Item' : 'New Item'}
        </div>

        <div style={{
          height: 100,
          background: form.image ? `url(${form.image}) center/cover` : form.gradient,
          borderRadius: 12,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 14,
        }}>
          {!form.image && <span style={{ fontSize: 50 }}>{form.emoji}</span>}
        </div>

        <Field label="Name">
          <Input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })}
            placeholder="e.g., Brown Sugar Boba" autoFocus />
        </Field>
        <Field label="Price (USD)">
          <Input type="number" step="0.25" value={form.price}
            onChange={e => setForm({ ...form, price: e.target.value })} />
        </Field>
        <Field label="Category">
          <select value={form.category} onChange={e => setForm({ ...form, category: e.target.value })}
            style={{
              width: '100%', padding: '10px 14px',
              background: C.card, color: C.text,
              border: `1px solid ${C.border}`, borderRadius: 10,
              fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
            }}>
            {categories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
          </select>
        </Field>
        <Field label="Image URL (optional)" hint="Paste any image URL. Leave empty to use emoji + gradient.">
          <Input value={form.image} onChange={e => setForm({ ...form, image: e.target.value })}
            placeholder="https://..." />
        </Field>
        <Field label="Emoji">
          <Input value={form.emoji} onChange={e => setForm({ ...form, emoji: e.target.value })} maxLength={2} />
        </Field>
        <Field label="Background gradient" hint="CSS gradient — used when no image">
          <Input value={form.gradient} onChange={e => setForm({ ...form, gradient: e.target.value })} />
        </Field>

        <div style={{ display: 'flex', gap: 20, marginTop: 10 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text }}>
            <input type="checkbox" checked={form.popular}
              onChange={e => setForm({ ...form, popular: e.target.checked })} />
            ★ Popular (HOT badge)
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text }}>
            <input type="checkbox" checked={form.available}
              onChange={e => setForm({ ...form, available: e.target.checked })} />
            Available
          </label>
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button onClick={handleSave} style={{ flex: 1 }}>
            <Save size={14} style={{ verticalAlign: 'middle', marginRight: 6 }} /> Save
          </Button>
        </div>
      </div>
    </Modal>
  );
}

function CategoryEditModal({ cat, onSave, onClose }) {
  const [name, setName] = useState(cat.name || '');
  const [icon, setIcon] = useState(cat.icon || '🍴');

  return (
    <Modal onClose={onClose} maxWidth={400}>
      <div style={{ padding: 24 }}>
        <ModalClose onClose={onClose} />
        <div style={{ fontSize: 20, fontWeight: 900, color: C.text, marginBottom: 18 }}>
          {cat.id ? 'Edit Category' : 'New Category'}
        </div>
        <Field label="Name">
          <Input value={name} onChange={e => setName(e.target.value)} placeholder="e.g., Specials" autoFocus />
        </Field>
        <Field label="Icon (emoji)">
          <Input value={icon} onChange={e => setIcon(e.target.value)} maxLength={2} />
        </Field>
        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button onClick={() => name && onSave({ ...cat, name, icon })} style={{ flex: 1 }}>Save</Button>
        </div>
      </div>
    </Modal>
  );
}

// ============================================================================
// STAFF MANAGER
// ============================================================================
function StaffManager() {
  const [staff, setStaff] = useState([]);
  const [editing, setEditing] = useState(null);

  const load = async () => {
    const s = await loadStaff();
    setStaff(s);
  };

  useEffect(() => { load(); }, []);

  const handleSave = async (member) => {
    if (member.id && staff.some(s => s.id === member.id)) {
      await updateStaff(member.id, member);
    } else {
      await addStaff(member);
    }
    await load();
    setEditing(null);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this staff member?')) {
      try {
        await deleteStaff(id);
        await load();
      } catch (e) {
        alert(e.message);
      }
    }
  };

  return (
    <div>
      <div style={s.sectionHead}>
        <div>
          <div style={{ fontSize: 14, fontWeight: 900, color: C.text }}>Staff ({staff.length})</div>
          <div style={{ fontSize: 12, color: C.textMute, fontWeight: 700, marginTop: 4 }}>
            Manager role required for: refunds, discounts, settings (PAX, Staff)
          </div>
        </div>
        <Button size="sm" onClick={() => setEditing({})}>
          <Plus size={12} style={{ verticalAlign: 'middle' }} /> Add Staff
        </Button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {staff.map(m => (
          <div key={m.id} style={s.itemCard}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: m.role === 'manager'
                ? `linear-gradient(135deg, ${C.primary}, ${C.primaryD})`
                : C.card,
              color: m.role === 'manager' ? C.bg : C.text,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 18, fontWeight: 900,
            }}>
              {m.name?.[0] || '?'}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 800, fontSize: 14, color: C.text }}>
                {m.name}
                {!m.active && <span style={{ marginLeft: 6, fontSize: 10, color: C.red, fontWeight: 900 }}>INACTIVE</span>}
              </div>
              <div style={{ fontSize: 12, color: C.textMute, fontWeight: 700, marginTop: 2, textTransform: 'capitalize' }}>
                {m.role} · PIN: ••••
              </div>
            </div>
            <button onClick={() => setEditing(m)} style={s.iconBtn}><Edit3 size={14} /></button>
            <button onClick={() => handleDelete(m.id)} style={s.iconBtn}><Trash2 size={14} /></button>
          </div>
        ))}
      </div>

      {editing !== null && (
        <StaffEditModal member={editing} onSave={handleSave} onClose={() => setEditing(null)} />
      )}
    </div>
  );
}

function StaffEditModal({ member, onSave, onClose }) {
  const [form, setForm] = useState({
    name: member.name || '',
    role: member.role || 'cashier',
    pin: member.pin || '',
    active: member.active !== false,
  });

  const valid = form.name.trim() && /^\d{4}$/.test(form.pin);

  return (
    <Modal onClose={onClose} maxWidth={400}>
      <div style={{ padding: 24 }}>
        <ModalClose onClose={onClose} />
        <div style={{ fontSize: 20, fontWeight: 900, color: C.text, marginBottom: 18 }}>
          {member.id ? 'Edit Staff' : 'New Staff'}
        </div>
        <Field label="Name">
          <Input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} autoFocus />
        </Field>
        <Field label="Role">
          <select value={form.role} onChange={e => setForm({ ...form, role: e.target.value })}
            style={{
              width: '100%', padding: '10px 14px',
              background: C.card, color: C.text,
              border: `1px solid ${C.border}`, borderRadius: 10,
              fontSize: 14, fontWeight: 700, fontFamily: 'inherit',
            }}>
            <option value="cashier">Cashier</option>
            <option value="manager">Manager</option>
          </select>
        </Field>
        <Field label="4-digit PIN" hint={!valid && form.pin ? 'Must be exactly 4 digits' : ''}>
          <Input value={form.pin}
            onChange={e => setForm({ ...form, pin: e.target.value.replace(/\D/g, '').slice(0, 4) })}
            maxLength={4} placeholder="0000" />
        </Field>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 13, color: C.text, marginTop: 10 }}>
          <input type="checkbox" checked={form.active}
            onChange={e => setForm({ ...form, active: e.target.checked })} />
          Active (can sign in)
        </label>
        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button onClick={() => valid && onSave({ ...member, ...form })}
            style={{ flex: 1, opacity: valid ? 1 : 0.4 }}>
            Save
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ============================================================================
// SHOP INFO — Full editor (configurable per shop)
// ============================================================================
function ShopInfo() {
  const { shop, updateShop } = useShop();
  const [form, setForm] = useState({
    name:           shop.name || '',
    branch:         shop.branch || '',
    address:        shop.address || '',
    phone:          shop.phone || '',
    tax:            shop.tax != null ? (shop.tax * 100).toFixed(2) : '8.75',
    currency:       shop.currency || 'USD',
    currencySymbol: shop.currencySymbol || '$',
    sizeLargeBonus: shop.sizeLargeBonus != null ? shop.sizeLargeBonus : 0.75,
    tipPercents:    (shop.tipPercents || [15, 18, 20, 25]).join(', '),
    receiptFooter:  shop.receiptFooter || 'Thank you! Visit us again',
  });
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);

  // When shop changes externally (after save), sync form values
  useEffect(() => {
    setForm({
      name:           shop.name || '',
      branch:         shop.branch || '',
      address:        shop.address || '',
      phone:          shop.phone || '',
      tax:            shop.tax != null ? (shop.tax * 100).toFixed(2) : '8.75',
      currency:       shop.currency || 'USD',
      currencySymbol: shop.currencySymbol || '$',
      sizeLargeBonus: shop.sizeLargeBonus != null ? shop.sizeLargeBonus : 0.75,
      tipPercents:    (shop.tipPercents || [15, 18, 20, 25]).join(', '),
      receiptFooter:  shop.receiptFooter || 'Thank you! Visit us again',
    });
  }, [shop]);

  const valid = form.name.trim().length > 0;

  const handleSave = async () => {
    if (!valid) return;
    setSaving(true);
    try {
      // Parse tip percents from comma-separated string
      const tips = form.tipPercents
        .split(',')
        .map(s => parseFloat(s.trim()))
        .filter(n => !isNaN(n) && n >= 0 && n <= 100);

      await updateShop({
        name:           form.name.trim(),
        branch:         form.branch.trim(),
        address:        form.address.trim(),
        phone:          form.phone.trim(),
        tax:            (parseFloat(form.tax) || 0) / 100,
        currency:       form.currency.trim().toUpperCase(),
        currencySymbol: form.currencySymbol.trim() || '$',
        sizeLargeBonus: parseFloat(form.sizeLargeBonus) || 0,
        tipPercents:    tips.length ? tips : [15, 18, 20, 25],
        receiptFooter:  form.receiptFooter.trim(),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (e) {
      alert('Failed to save: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{ maxWidth: 640 }}>
      <div style={{
        background: C.primaryA, border: `1px solid ${C.primary}33`,
        padding: 14, borderRadius: 12, marginBottom: 18,
        fontSize: 13, color: C.primary, fontWeight: 700,
      }}>
        💡 These settings apply to this shop only and are saved on this device.
        Set them up once when you install for a new customer.
      </div>

      <div style={{ background: C.panel, padding: 20, borderRadius: 14 }}>
        <SectionTitle>Shop Identity</SectionTitle>
        <Field label="Shop Name *" hint="Shown in top bar and receipts">
          <Input value={form.name}
            onChange={e => setForm({ ...form, name: e.target.value })}
            placeholder="e.g., Boba Bliss" />
        </Field>
        <Field label="Branch / Location" hint="Optional subtitle (e.g., 'Downtown', 'Main Street')">
          <Input value={form.branch}
            onChange={e => setForm({ ...form, branch: e.target.value })}
            placeholder="e.g., Main Street" />
        </Field>
        <Field label="Address" hint="Printed on receipts">
          <Input value={form.address}
            onChange={e => setForm({ ...form, address: e.target.value })}
            placeholder="123 Main St, City, ST 12345" />
        </Field>
        <Field label="Phone Number">
          <Input value={form.phone}
            onChange={e => setForm({ ...form, phone: e.target.value })}
            placeholder="(555) 123-4567" />
        </Field>

        <SectionTitle>Pricing & Tax</SectionTitle>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <Field label="Tax Rate (%)" hint="Sales tax applied to subtotal">
              <Input type="number" step="0.01" min="0" max="50"
                value={form.tax}
                onChange={e => setForm({ ...form, tax: e.target.value })}
                placeholder="8.75" />
            </Field>
          </div>
          <div style={{ flex: 1 }}>
            <Field label="Large Size Upcharge" hint={`Added when customer picks "Large"`}>
              <Input type="number" step="0.25" min="0"
                value={form.sizeLargeBonus}
                onChange={e => setForm({ ...form, sizeLargeBonus: e.target.value })}
                placeholder="0.75" />
            </Field>
          </div>
        </div>

        <SectionTitle>Currency</SectionTitle>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <Field label="Code" hint="ISO code (display only)">
              <Input value={form.currency} maxLength={3}
                onChange={e => setForm({ ...form, currency: e.target.value })}
                placeholder="USD" />
            </Field>
          </div>
          <div style={{ flex: 1 }}>
            <Field label="Symbol" hint="Shown before prices">
              <Input value={form.currencySymbol} maxLength={3}
                onChange={e => setForm({ ...form, currencySymbol: e.target.value })}
                placeholder="$" />
            </Field>
          </div>
        </div>

        <SectionTitle>Receipts</SectionTitle>
        <Field label="Suggested Tips (%)" hint="Comma-separated, shown on PAX terminal">
          <Input value={form.tipPercents}
            onChange={e => setForm({ ...form, tipPercents: e.target.value })}
            placeholder="15, 18, 20, 25" />
        </Field>
        <Field label="Receipt Footer Message">
          <Input value={form.receiptFooter}
            onChange={e => setForm({ ...form, receiptFooter: e.target.value })}
            placeholder="Thank you! Visit us again" />
        </Field>

        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <Button
            onClick={handleSave}
            disabled={!valid || saving}
            style={{ flex: 1, opacity: (valid && !saving) ? 1 : 0.5 }}>
            {saving ? 'Saving...' : saved ? <><Check size={14} style={{ verticalAlign: 'middle', marginRight: 6 }} /> Saved</> : <><Save size={14} style={{ verticalAlign: 'middle', marginRight: 6 }} /> Save Shop Info</>}
          </Button>
        </div>
      </div>
    </div>
  );
}

function SectionTitle({ children }) {
  return (
    <div style={{
      fontSize: 11, fontWeight: 800, color: C.textMute,
      textTransform: 'uppercase', letterSpacing: 1,
      marginTop: 20, marginBottom: 10,
      paddingBottom: 6, borderBottom: `1px solid ${C.border}`,
    }}>{children}</div>
  );
}

// ============================================================================
// ABOUT
// ============================================================================
function AboutTab() {
  const [tapCount, setTapCount] = useState(0);
  const [debug, setDebug] = useState(false);

  const isDev = BUILD_DATE === '__BUILD_DATE__';
  const buildDate = isDev ? 'Development build' : new Date(BUILD_DATE).toLocaleString();
  const buildNum = BUILD_NUMBER === '__BUILD_NUMBER__' ? 'local' : `#${BUILD_NUMBER}`;
  const commit = COMMIT_SHORT === '__COMMIT_SHORT__' ? 'local' : COMMIT_SHORT;

  const copy = () => {
    const text = `Vido Foody Debug
Version: ${APP_VERSION}
Build: ${buildNum}
Built: ${buildDate}
Commit: ${commit}
UA: ${navigator.userAgent}
Screen: ${window.screen.width}x${window.screen.height}
Online: ${navigator.onLine}`;
    navigator.clipboard?.writeText(text);
    alert('Copied to clipboard');
  };

  return (
    <div style={{ maxWidth: 520 }}>
      <div style={{
        background: C.primaryG,
        padding: 24, borderRadius: 14,
        textAlign: 'center', color: '#fff',
        marginBottom: 14,
        boxShadow: C.primaryGShadow,
      }}>
        <div style={{
          fontSize: 56, fontWeight: 900, marginBottom: 4,
          fontFamily: 'Arial Black, sans-serif', letterSpacing: -2,
        }}>F</div>
        <div style={{ fontSize: 24, fontWeight: 900 }}>Vido Foody</div>
        <div
          onClick={() => { const n = tapCount + 1; setTapCount(n); if (n >= 7) setDebug(true); }}
          style={{ fontSize: 14, opacity: 0.92, fontWeight: 800, marginTop: 4, cursor: 'pointer', userSelect: 'none' }}>
          Version {APP_VERSION} · Build {buildNum}
        </div>
      </div>

      <div style={{ background: C.panel, padding: 18, borderRadius: 12, marginBottom: 12 }}>
        <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          Build Information
        </div>
        <InfoRow label="Version" value={APP_VERSION} mono />
        <InfoRow label="Build" value={buildNum} mono />
        <InfoRow label="Built On" value={buildDate} />
        <InfoRow label="Commit" value={commit} mono />
        <InfoRow label="Environment" value={isDev ? '🔧 Development' : '🚀 Production'} />
      </div>

      <Button onClick={copy} variant="ghost" style={{ width: '100%' }}>
        📋 Copy Debug Info
      </Button>

      {debug && (
        <div style={{
          background: C.panel, padding: 18, borderRadius: 12,
          border: `2px solid ${C.yellow}`, marginTop: 12,
        }}>
          <div style={{ fontSize: 11, fontWeight: 800, color: C.yellow, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
            🔓 Developer Info
          </div>
          <InfoRow label="Screen" value={`${window.screen.width}×${window.screen.height}`} mono />
          <InfoRow label="Viewport" value={`${window.innerWidth}×${window.innerHeight}`} mono />
          <InfoRow label="Pixel Ratio" value={`${window.devicePixelRatio}x`} mono />
          <InfoRow label="Online" value={navigator.onLine ? '✓ Yes' : '✗ No'} />
          <InfoRow label="Language" value={navigator.language} mono />
        </div>
      )}

      <div style={{ fontSize: 11, color: C.textDim, fontWeight: 700, textAlign: 'center', marginTop: 16 }}>
        Built for Vido Booking · {new Date().getFullYear()}
      </div>
    </div>
  );
}

function InfoRow({ label, value, mono }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between',
      alignItems: 'center', padding: '6px 0',
      borderBottom: `1px dashed ${C.border}`,
    }}>
      <span style={{ fontSize: 12, color: C.textMute, fontWeight: 700 }}>{label}</span>
      <span style={{
        fontSize: 12, color: C.text, fontWeight: 800,
        fontFamily: mono ? 'ui-monospace, "SF Mono", Menlo, monospace' : 'inherit',
        textAlign: 'right',
      }}>{value}</span>
    </div>
  );
}

// ============================================================================
const s = {
  container: { padding: 24, color: C.text, flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' },
  title: { fontSize: 22, fontWeight: 900, marginBottom: 18, color: C.text },
  tabs: {
    display: 'flex', gap: 4, background: C.panel,
    padding: 4, borderRadius: 12, marginBottom: 18,
    flexWrap: 'wrap',
    alignSelf: 'flex-start',
    maxWidth: '100%',
  },
  tabContent: { flex: 1, overflowY: 'auto' },
  sectionHead: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, gap: 10 },
  catEditCard: {
    background: C.card, padding: '8px 12px',
    borderRadius: 10, display: 'flex',
    alignItems: 'center', gap: 8,
  },
  itemCard: {
    background: C.panel, padding: 10,
    borderRadius: 12, display: 'flex',
    alignItems: 'center', gap: 10,
  },
  iconBtn: {
    width: 28, height: 28,
    background: C.card, color: C.textMute,
    border: 'none', borderRadius: 6, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  },
};
