import React, { useState, useEffect, createContext, useContext } from 'react';
import { ShoppingCart, Receipt, BarChart3, Settings as SettingsIcon, Wifi, WifiOff, LogOut, Moon, Sun } from 'lucide-react';
import { C, applyTheme, getInitialTheme } from './theme';
import { SHOP } from './config';
import { paxService } from './services/paxBridge';
import { getCurrentStaff, clearCurrentStaff } from './services/staffStorage';
import { loadMenu, loadCategories } from './services/menuStorage';
import { loadShop, saveShop } from './services/shopStorage';
import { DEFAULT_MENU, DEFAULT_CATEGORIES } from './data/defaultMenu';
import { APP_VERSION, BUILD_NUMBER } from './version';
import { PinLockScreen } from './components/Shared';
import { OrderView } from './views/OrderView';
import { HistoryView } from './views/HistoryView';
import { ReportsView } from './views/ReportsView';
import { SettingsView } from './views/SettingsView';

// =====================================================================
// SHOP CONTEXT — globally accessible shop info + updater
// =====================================================================
const ShopContext = createContext({ shop: SHOP, updateShop: async () => {} });
export const useShop = () => useContext(ShopContext);

export default function App() {
  const [theme, setTheme] = useState(getInitialTheme());
  const [view, setView] = useState('sell');
  const [staff, setStaff] = useState(null);
  const [shop, setShop] = useState(SHOP);
  const [menu, setMenu] = useState(DEFAULT_MENU);
  const [categories, setCategories] = useState(DEFAULT_CATEGORIES);
  const [loading, setLoading] = useState(true);

  useEffect(() => { applyTheme(theme); }, [theme]);

  useEffect(() => {
    Promise.all([loadMenu(), loadCategories(), loadShop()]).then(([m, c, s]) => {
      setMenu(m); setCategories(c); setShop(s); setLoading(false);
    });
  }, []);

  const updateShop = async (updates) => {
    const newShop = await saveShop({ ...shop, ...updates });
    setShop(newShop);
    return newShop;
  };

  const toggleTheme = () => setTheme(t => t === 'dark' ? 'light' : 'dark');
  const handleLogout = () => { clearCurrentStaff(); setStaff(null); };
  const refreshMenu = async () => {
    const [m, c] = await Promise.all([loadMenu(), loadCategories()]);
    setMenu(m); setCategories(c);
  };

  if (!staff) {
    return (
      <PinLockScreen
        title="Vido Foody"
        subtitle="Enter PIN to sign in"
        onUnlock={(s) => setStaff(s)}
      />
    );
  }

  if (loading) {
    return <div style={loadingStyle}>Loading...</div>;
  }

  return (
    <ShopContext.Provider value={{ shop, updateShop }}>
      <div style={appStyle}>
        <style>{`
          @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.5; } }
          @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
          .spin { animation: spin 1.5s linear infinite; }
          ::-webkit-scrollbar { width: 8px; height: 8px; }
          ::-webkit-scrollbar-track { background: var(--panel); }
          ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
        `}</style>

        <TopBar
          view={view} setView={setView}
          theme={theme} toggleTheme={toggleTheme}
          staff={staff} onLogout={handleLogout}
        />

        <div style={contentStyle}>
          {view === 'sell' && <OrderView menu={menu} categories={categories} staff={staff} />}
          {view === 'orders' && <HistoryView />}
          {view === 'reports' && <ReportsView />}
          {view === 'settings' && (
            <SettingsView
              menu={menu} categories={categories}
              refreshMenu={refreshMenu} staff={staff}
            />
          )}
        </div>
      </div>
    </ShopContext.Provider>
  );
}

// ============================================================================
// TOP BAR (inline component)
// ============================================================================
function TopBar({ view, setView, theme, toggleTheme, staff, onLogout }) {
  const { shop } = useShop();
  const [paxOnline, setPaxOnline] = useState(false);
  const [userMenuOpen, setUserMenuOpen] = useState(false);

  useEffect(() => {
    const check = async () => {
      const res = await paxService.ping();
      setPaxOnline(res.ok);
    };
    check();
    const i = setInterval(check, 30000);
    return () => clearInterval(i);
  }, []);

  const tabs = [
    { id: 'sell',     label: 'Sell',     icon: ShoppingCart },
    { id: 'orders',   label: 'Orders',   icon: Receipt },
    { id: 'reports',  label: 'Reports',  icon: BarChart3 },
    { id: 'settings', label: 'Settings', icon: SettingsIcon },
  ];

  return (
    <header style={tbStyles.header}>
      <div style={tbStyles.brand}>
        <div style={tbStyles.logo}>F</div>
        <div>
          <div style={tbStyles.brandName}>{shop.name}</div>
          <div style={tbStyles.brandSub}>{shop.branch}</div>
        </div>
      </div>

      <nav style={tbStyles.nav}>
        {tabs.map(t => {
          const Icon = t.icon;
          const active = view === t.id;
          return (
            <button key={t.id} onClick={() => setView(t.id)}
              style={{ ...tbStyles.navBtn, ...(active ? tbStyles.navBtnActive : {}) }}>
              <Icon size={14} style={{ marginRight: 6, verticalAlign: 'middle' }} />
              {t.label}
            </button>
          );
        })}
      </nav>

      <div style={tbStyles.meta}>
        <div style={{
          ...tbStyles.paxPill,
          background: paxOnline ? C.primaryA : C.redA,
          color: paxOnline ? C.primary : C.red,
        }}>
          {paxOnline ? <Wifi size={12} /> : <WifiOff size={12} />}
          <span style={{ marginLeft: 5 }}>PAX {paxOnline ? 'Online' : 'Offline'}</span>
        </div>

        <button onClick={toggleTheme} style={tbStyles.themeBtn}>
          {theme === 'dark' ? <Moon size={14} /> : <Sun size={14} />}
        </button>

        <div style={{ position: 'relative' }}>
          <button onClick={() => setUserMenuOpen(!userMenuOpen)} style={tbStyles.userBtn}>
            👤 {staff?.name || 'User'}
          </button>
          {userMenuOpen && (
            <>
              <div onClick={() => setUserMenuOpen(false)} style={tbStyles.menuOverlay} />
              <div style={tbStyles.userMenu}>
                <div style={tbStyles.userMenuInfo}>
                  <div style={{ fontWeight: 800, fontSize: 13 }}>{staff?.name}</div>
                  <div style={{ fontSize: 11, color: C.textMute, fontWeight: 700, marginTop: 2, textTransform: 'capitalize' }}>
                    {staff?.role}
                  </div>
                  <div style={{ fontSize: 10, color: C.textDim, fontWeight: 700, marginTop: 4 }}>
                    v{APP_VERSION} · #{BUILD_NUMBER === '__BUILD_NUMBER__' ? 'dev' : BUILD_NUMBER}
                  </div>
                </div>
                <button onClick={() => { setUserMenuOpen(false); onLogout(); }} style={tbStyles.userMenuItem}>
                  <LogOut size={14} /> Sign out
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

// ============================================================================
// STYLES
// ============================================================================
const appStyle = {
  display: 'flex', flexDirection: 'column',
  height: '100vh', background: C.bg, color: C.text,
  overflow: 'hidden',
};
const contentStyle = { flex: 1, overflow: 'hidden', display: 'flex' };
const loadingStyle = {
  height: '100vh', display: 'flex',
  alignItems: 'center', justifyContent: 'center',
  background: C.bg, color: C.text,
  fontSize: 18, fontWeight: 800,
};

const tbStyles = {
  header: {
    background: C.panel, padding: '12px 20px',
    borderBottom: `1px solid ${C.border}`,
    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    flexShrink: 0,
  },
  brand: { display: 'flex', alignItems: 'center' },
  logo: {
    width: 46, height: 46,
    background: C.primaryG,
    borderRadius: 12, textAlign: 'center', lineHeight: '46px',
    fontSize: 28, fontWeight: 900, color: '#fff',
    marginRight: 12,
    boxShadow: C.primaryGShadow,
    fontFamily: 'Arial Black, sans-serif',
    letterSpacing: -1,
  },
  brandName: { fontSize: 20, fontWeight: 900, color: C.text },
  brandSub: { fontSize: 11, color: C.textMute, fontWeight: 700 },
  nav: { display: 'flex', background: C.card, padding: 4, borderRadius: 14, gap: 2 },
  navBtn: {
    padding: '8px 16px', fontWeight: 800, fontSize: 13,
    color: C.textMute, background: 'transparent',
    border: 'none', borderRadius: 10, cursor: 'pointer',
    display: 'flex', alignItems: 'center',
  },
  navBtnActive: { background: C.primaryG, color: C.bg, boxShadow: C.primaryGShadow },
  meta: { display: 'flex', alignItems: 'center', gap: 8 },
  paxPill: {
    padding: '6px 12px', borderRadius: 999,
    fontWeight: 800, fontSize: 12,
    display: 'flex', alignItems: 'center',
  },
  themeBtn: {
    background: C.card, color: C.text, border: 'none',
    width: 32, height: 32, borderRadius: 999, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  },
  userBtn: {
    background: C.card, color: C.text, border: 'none',
    padding: '7px 14px', borderRadius: 999,
    cursor: 'pointer', fontWeight: 800, fontSize: 13,
  },
  menuOverlay: { position: 'fixed', inset: 0, zIndex: 99 },
  userMenu: {
    position: 'absolute', top: '100%', right: 0, marginTop: 6,
    background: C.panel, border: `1px solid ${C.border}`,
    borderRadius: 12, minWidth: 200,
    boxShadow: `0 10px 30px ${C.shadow}`,
    zIndex: 100, overflow: 'hidden',
  },
  userMenuInfo: { padding: '12px 14px', borderBottom: `1px solid ${C.border}`, background: C.card },
  userMenuItem: {
    width: '100%', background: 'transparent', color: C.text,
    border: 'none', padding: '10px 14px',
    fontSize: 13, fontWeight: 700, textAlign: 'left', cursor: 'pointer',
    display: 'flex', alignItems: 'center', gap: 8,
  },
};
