package com.vido.pos.dual

/**
 * HTML template rendered inside the Customer-Facing Display WebView.
 *
 * Native code calls `window.__updateState(jsonString)` with a payload that
 * follows this shape:
 *
 * {
 *   shop:    { name, currencySymbol, address?, phone? },
 *   state:   "idle" | "order" | "payment" | "done",
 *   orderNumber: int,
 *   items:   [ { name, emoji, details, qty, total } ],
 *   subtotal, discount, tax, total: number,
 *   method?:  "cash" | "card" | "ewallet",
 *   cashGiven?: number, change?: number,
 *   qrUrl?:   string   // optional, ewallet payment QR
 * }
 */
object CustomerDisplayHtml {
    const val TEMPLATE = """
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>Vido Foody — Customer Display</title>
<style>
:root {
  --bg: #0F1419;
  --panel: #1A1F26;
  --card: #252A33;
  --border: #374151;
  --text: #FFFFFF;
  --mute: #9CA3AF;
  --dim: #6B7280;
  --primary: #FFCC00;
  --primary-dim: #E0B000;
  --accent: #FFE066;
  --primary-glow: rgba(255, 204, 0, 0.18);
  --green: #4ADE80;
  --green-glow: rgba(74, 222, 128, 0.15);
  --red: #EF4444;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

html, body {
  width: 100vw; height: 100vh;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
               "Helvetica Neue", Arial, sans-serif;
  font-weight: 700;
  overflow: hidden;
  -webkit-font-smoothing: antialiased;
  user-select: none;
  -webkit-user-select: none;
}

/* Ambient gradient background */
body::before {
  content: '';
  position: fixed; inset: 0;
  background:
    radial-gradient(ellipse at top, rgba(255, 204, 0, 0.06), transparent 60%),
    radial-gradient(ellipse at bottom, rgba(255, 204, 0, 0.03), transparent 60%);
  pointer-events: none;
}

#root {
  position: relative;
  width: 100%; height: 100%;
}

.screen {
  position: absolute; inset: 0;
  display: flex; flex-direction: column;
  opacity: 0;
  transform: translateY(8px);
  transition: opacity 320ms ease, transform 320ms ease;
  pointer-events: none;
}
.screen.active {
  opacity: 1;
  transform: translateY(0);
  pointer-events: auto;
}

/* ============================================================
   IDLE — welcome screen
   ============================================================ */
#idle {
  align-items: center;
  justify-content: center;
  padding: 8vh 4vw;
  text-align: center;
}
.logo-mark {
  width: 22vmin; height: 22vmin;
  border-radius: 50%;
  background: linear-gradient(135deg, #FFE066 0%, #FFCC00 45%, #FF9500 100%);
  display: flex; align-items: center; justify-content: center;
  font-size: 11vmin;
  margin-bottom: 4vmin;
  box-shadow:
    0 0 0 1px rgba(255, 204, 0, 0.3),
    0 0 60px 4px rgba(255, 204, 0, 0.25);
  animation: float 4s ease-in-out infinite;
}
@keyframes float {
  0%, 100% { transform: translateY(0); }
  50%      { transform: translateY(-1vmin); }
}
.logo-name {
  font-size: 5vmin;
  font-weight: 900;
  letter-spacing: 0.02em;
  color: var(--text);
  margin-bottom: 1.5vmin;
}
.welcome {
  font-size: 4.2vmin;
  font-weight: 800;
  color: var(--primary);
  margin-top: 6vmin;
  letter-spacing: 0.02em;
}
.welcome-sub {
  font-size: 2.4vmin;
  font-weight: 700;
  color: var(--mute);
  margin-top: 1vmin;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

/* ============================================================
   ORDER — live cart
   ============================================================ */
#order {
  padding: 0;
}
.ord-header {
  padding: 3vmin 4vmin 2.4vmin;
  border-bottom: 1px solid var(--border);
  display: flex; align-items: center; justify-content: space-between;
  background: var(--panel);
}
.ord-shop {
  display: flex; align-items: center; gap: 2vmin;
}
.ord-shop-mark {
  width: 6vmin; height: 6vmin;
  border-radius: 50%;
  background: linear-gradient(135deg, #FFE066, #FFCC00, #FF9500);
  display: flex; align-items: center; justify-content: center;
  font-size: 3vmin;
}
.ord-shop-name {
  font-size: 2.4vmin;
  font-weight: 900;
  color: var(--text);
}
.ord-num {
  background: var(--primary-glow);
  border: 1px solid rgba(255, 204, 0, 0.35);
  color: var(--primary);
  padding: 1.2vmin 2.4vmin;
  border-radius: 999px;
  font-size: 2vmin;
  font-weight: 900;
  letter-spacing: 0.04em;
}

.ord-items {
  flex: 1;
  overflow-y: auto;
  padding: 2vmin 4vmin;
  scrollbar-width: thin;
  scrollbar-color: var(--border) transparent;
}
.ord-items::-webkit-scrollbar { width: 6px; }
.ord-items::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

.ord-empty {
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  height: 100%;
  color: var(--dim);
  font-size: 2.4vmin;
  font-weight: 700;
}
.ord-empty-icon { font-size: 8vmin; opacity: 0.4; margin-bottom: 2vmin; }

.item {
  display: grid;
  grid-template-columns: auto 1fr auto auto;
  gap: 2.5vmin;
  align-items: center;
  padding: 2.2vmin 0;
  border-bottom: 1px solid var(--border);
  animation: slideIn 240ms ease;
}
@keyframes slideIn {
  from { opacity: 0; transform: translateX(-8px); }
  to   { opacity: 1; transform: translateX(0); }
}
.item-emoji {
  font-size: 4vmin;
  width: 8vmin; height: 8vmin;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 1.5vmin;
  display: flex; align-items: center; justify-content: center;
}
.item-info { min-width: 0; }
.item-name {
  font-size: 2.4vmin;
  font-weight: 800;
  color: var(--text);
  margin-bottom: 0.5vmin;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.item-details {
  font-size: 1.8vmin;
  font-weight: 700;
  color: var(--mute);
}
.item-qty {
  font-size: 2.4vmin;
  font-weight: 900;
  color: var(--primary);
  padding: 0.8vmin 1.6vmin;
  background: var(--primary-glow);
  border-radius: 999px;
  min-width: 6vmin;
  text-align: center;
}
.item-total {
  font-size: 2.6vmin;
  font-weight: 900;
  color: var(--text);
  text-align: right;
  min-width: 12vmin;
}

.ord-totals {
  background: var(--panel);
  border-top: 1px solid var(--border);
  padding: 3vmin 4vmin;
}
.tot-row {
  display: flex; justify-content: space-between; align-items: baseline;
  padding: 0.8vmin 0;
  font-size: 2.2vmin;
  font-weight: 700;
  color: var(--mute);
}
.tot-row span:last-child { color: var(--text); font-weight: 800; }
.tot-row.discount span:last-child { color: var(--green); }
.tot-row.grand {
  margin-top: 1.5vmin;
  padding-top: 2vmin;
  border-top: 1px dashed var(--border);
  font-size: 3.4vmin;
  color: var(--text);
  font-weight: 900;
}
.tot-row.grand span:last-child {
  color: var(--primary);
  font-size: 4.4vmin;
  font-weight: 900;
}

/* ============================================================
   PAYMENT — waiting for payment
   ============================================================ */
#payment {
  align-items: center;
  justify-content: center;
  padding: 6vh 6vw;
  text-align: center;
}
.pay-label {
  font-size: 2.4vmin;
  font-weight: 800;
  color: var(--mute);
  letter-spacing: 0.15em;
  text-transform: uppercase;
  margin-bottom: 2vmin;
}
.pay-total {
  font-size: 14vmin;
  font-weight: 900;
  background: linear-gradient(135deg, #FFE066, #FFCC00, #FF9500);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  line-height: 1;
  margin-bottom: 4vmin;
  letter-spacing: -0.02em;
}
.pay-method-pill {
  display: inline-flex; align-items: center; gap: 2vmin;
  padding: 2vmin 4vmin;
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 999px;
  font-size: 2.6vmin;
  font-weight: 800;
  color: var(--text);
  margin-bottom: 4vmin;
}
.pay-method-pill .icon { font-size: 3vmin; }
.pay-instruction {
  font-size: 3vmin;
  font-weight: 800;
  color: var(--primary);
  margin-top: 2vmin;
  animation: pulse 2s ease-in-out infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50%      { opacity: 0.55; }
}
.pay-sub {
  font-size: 1.9vmin;
  font-weight: 700;
  color: var(--mute);
  margin-top: 2vmin;
}
.pay-cash {
  display: flex; gap: 3vmin;
  margin-top: 3vmin;
}
.pay-cash-box {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 2vmin;
  padding: 2vmin 3vmin;
  min-width: 20vmin;
}
.pay-cash-box .label {
  font-size: 1.6vmin; font-weight: 800;
  color: var(--mute); letter-spacing: 0.1em;
  text-transform: uppercase; margin-bottom: 0.8vmin;
}
.pay-cash-box .value {
  font-size: 3.2vmin; font-weight: 900; color: var(--text);
}
.pay-cash-box.change {
  background: var(--green-glow);
  border-color: rgba(255, 204, 0, 0.35);
}
.pay-cash-box.change .value { color: var(--green); }

/* ============================================================
   DONE — thank you
   ============================================================ */
#done {
  align-items: center;
  justify-content: center;
  padding: 6vh 6vw;
  text-align: center;
}
.done-check {
  width: 22vmin; height: 22vmin;
  border-radius: 50%;
  background: var(--green-glow);
  border: 0.6vmin solid var(--green);
  display: flex; align-items: center; justify-content: center;
  font-size: 13vmin;
  color: var(--green);
  margin-bottom: 4vmin;
  animation: checkPop 480ms cubic-bezier(.18,1.25,.4,1);
}
@keyframes checkPop {
  0%   { transform: scale(0); opacity: 0; }
  60%  { transform: scale(1.15); opacity: 1; }
  100% { transform: scale(1); }
}
.done-title {
  font-size: 4.4vmin;
  font-weight: 900;
  color: var(--text);
  margin-bottom: 1vmin;
}
.done-total {
  font-size: 7vmin;
  font-weight: 900;
  color: var(--primary);
  margin: 3vmin 0;
}
.done-thanks {
  font-size: 3vmin;
  font-weight: 800;
  color: var(--mute);
  margin-top: 2vmin;
  letter-spacing: 0.04em;
}
</style>
</head>
<body>
<div id="root">

  <!-- IDLE -->
  <div id="idle" class="screen active">
    <div class="logo-mark">🍱</div>
    <div class="logo-name" id="idle-shop-name">Vido Foody</div>
    <div class="welcome">Welcome</div>
    <div class="welcome-sub">Place your order with the cashier</div>
  </div>

  <!-- ORDER -->
  <div id="order" class="screen">
    <div class="ord-header">
      <div class="ord-shop">
        <div class="ord-shop-mark">🍱</div>
        <div class="ord-shop-name" id="ord-shop-name">Vido Foody</div>
      </div>
      <div class="ord-num" id="ord-num">#0000</div>
    </div>
    <div class="ord-items" id="ord-items"></div>
    <div class="ord-totals">
      <div class="tot-row"><span>Subtotal</span><span id="tot-subtotal">—</span></div>
      <div class="tot-row discount" id="tot-discount-row" style="display:none">
        <span>Discount</span><span id="tot-discount">—</span>
      </div>
      <div class="tot-row"><span>Tax</span><span id="tot-tax">—</span></div>
      <div class="tot-row grand"><span>TOTAL</span><span id="tot-grand">—</span></div>
    </div>
  </div>

  <!-- PAYMENT -->
  <div id="payment" class="screen">
    <div class="pay-label">Amount to pay</div>
    <div class="pay-total" id="pay-total">—</div>
    <div class="pay-method-pill">
      <span class="icon" id="pay-icon">💳</span>
      <span id="pay-method-label">—</span>
    </div>
    <div class="pay-instruction" id="pay-instruction">Please wait</div>
    <div class="pay-cash" id="pay-cash" style="display:none">
      <div class="pay-cash-box">
        <div class="label">Given</div>
        <div class="value" id="pay-cash-given">—</div>
      </div>
      <div class="pay-cash-box change">
        <div class="label">Change</div>
        <div class="value" id="pay-change">—</div>
      </div>
    </div>
  </div>

  <!-- DONE -->
  <div id="done" class="screen">
    <div class="done-check">✓</div>
    <div class="done-title">Payment successful</div>
    <div class="done-total" id="done-total">—</div>
    <div class="done-thanks">Thank you!</div>
  </div>

</div>

<script>
(function() {
  var currency = '\$';
  var idleTimer = null;

  function fmt(n) {
    var v = Number(n || 0);
    return currency + v.toLocaleString('en-US', {
      minimumFractionDigits: 2, maximumFractionDigits: 2,
    });
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function(m) {
      return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[m];
    });
  }
  function show(id) {
    var screens = document.querySelectorAll('.screen');
    for (var i = 0; i < screens.length; i++) screens[i].classList.remove('active');
    var el = document.getElementById(id);
    if (el) el.classList.add('active');
  }
  function clearIdleTimer() {
    if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; }
  }

  function renderOrder(s) {
    document.getElementById('ord-num').textContent =
      '#' + (s.orderNumber != null ? s.orderNumber : '0000');
    var box = document.getElementById('ord-items');
    var items = s.items || [];
    if (items.length === 0) {
      box.innerHTML =
        '<div class="ord-empty"><div class="ord-empty-icon">🛒</div>' +
        '<div>No items yet</div></div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        html +=
          '<div class="item">' +
            '<div class="item-emoji">' + esc(it.emoji || '•') + '</div>' +
            '<div class="item-info">' +
              '<div class="item-name">' + esc(it.name) + '</div>' +
              (it.details ? '<div class="item-details">' + esc(it.details) + '</div>' : '') +
            '</div>' +
            '<div class="item-qty">×' + (it.qty || 1) + '</div>' +
            '<div class="item-total">' + fmt(it.total) + '</div>' +
          '</div>';
      }
      box.innerHTML = html;
    }
    document.getElementById('tot-subtotal').textContent = fmt(s.subtotal);
    if (s.discount && Number(s.discount) > 0) {
      document.getElementById('tot-discount-row').style.display = 'flex';
      document.getElementById('tot-discount').textContent = '-' + fmt(s.discount);
    } else {
      document.getElementById('tot-discount-row').style.display = 'none';
    }
    document.getElementById('tot-tax').textContent = fmt(s.tax);
    document.getElementById('tot-grand').textContent = fmt(s.total);
    show('order');
  }

  function renderPayment(s) {
    document.getElementById('pay-total').textContent = fmt(s.total);
    var methodLabels = { cash: 'Cash', card: 'Card', ewallet: 'E-Wallet / QR' };
    var icons        = { cash: '💵',       card: '💳',           ewallet: '📱' };
    var instructions = {
      cash:    'Please hand cash to the cashier',
      card:    'Please tap or insert your card',
      ewallet: 'Please scan the QR code',
    };
    document.getElementById('pay-method-label').textContent =
      methodLabels[s.method] || (s.method ? String(s.method).toUpperCase() : 'Processing');
    document.getElementById('pay-icon').textContent = icons[s.method] || '💳';
    document.getElementById('pay-instruction').textContent =
      instructions[s.method] || 'Please wait';

    var cashBox = document.getElementById('pay-cash');
    if (s.method === 'cash' && (s.cashGiven != null)) {
      cashBox.style.display = 'flex';
      document.getElementById('pay-cash-given').textContent = fmt(s.cashGiven);
      document.getElementById('pay-change').textContent =
        fmt(Math.max(0, Number(s.cashGiven) - Number(s.total)));
    } else {
      cashBox.style.display = 'none';
    }
    show('payment');
  }

  function renderDone(s) {
    document.getElementById('done-total').textContent = fmt(s.total);
    show('done');
    clearIdleTimer();
    idleTimer = setTimeout(function() { show('idle'); }, 5000);
  }

  window.__updateState = function(jsonStr) {
    var s;
    try { s = JSON.parse(jsonStr); } catch (e) { return; }

    if (s.shop) {
      if (s.shop.currencySymbol) currency = s.shop.currencySymbol;
      if (s.shop.name) {
        document.getElementById('idle-shop-name').textContent = s.shop.name;
        document.getElementById('ord-shop-name').textContent = s.shop.name;
      }
    }

    var st = s.state || 'idle';
    if (st === 'idle')         { clearIdleTimer(); show('idle'); }
    else if (st === 'order')   { clearIdleTimer(); renderOrder(s); }
    else if (st === 'payment') { clearIdleTimer(); renderPayment(s); }
    else if (st === 'done')    { renderDone(s); }
  };
})();
</script>
</body>
</html>
"""
}
