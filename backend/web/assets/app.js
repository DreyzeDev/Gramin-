const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const state = {
  token: localStorage.getItem("gramin-token") || window.__GRAMIN_NATIVE_TOKEN || "",
  profile: null, wallets: [], cards: [], transactions: [], notifications: [], period: "month"
};

const rates = { AZN: 1, USD: 1.7, EUR: 1.85, RUB: 0.018 };
const services = [
  ["mobile", "Мобильная связь", "⌕", ["Azercell", "Bakcell", "Nar"]],
  ["internet", "Интернет", "⌁", ["CityNet", "Baktelecom"]],
  ["utilities", "Коммунальные", "ϟ", ["Электричество", "Газ", "Вода"]],
  ["subscriptions", "Игры и подписки", "◇", ["App Store", "Игровой аккаунт", "Подписка"]],
  ["taxes", "Штрафы и налоги", "▤", ["Штраф", "Налог"]],
  ["charity", "Благотворительность", "♡", ["Помощь детям", "Защита животных"]]
];

function nativeMessage(type, value = null) {
  window.webkit?.messageHandlers?.gramin?.postMessage({ type, value });
}

function saveToken(token) {
  state.token = token;
  localStorage.setItem("gramin-token", token);
  nativeMessage("saveToken", token);
}

function clearToken() {
  state.token = "";
  localStorage.removeItem("gramin-token");
  nativeMessage("deleteToken");
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { "Content-Type": "application/json", ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}), ...(options.headers || {}) }
  });
  if (response.status === 401) { clearToken(); showAuth(); throw new Error("Сессия истекла. Войдите снова"); }
  if (!response.ok) {
    let message = `Ошибка сервера (${response.status})`;
    try {
      const body = await response.json();
      if (typeof body.detail === "string") message = body.detail;
      else if (Array.isArray(body.detail)) message = body.detail.map(x => x.msg).join(". ");
      else if (body.detail?.code === "large_transfer_confirmation") message = "Подтвердите крупный перевод и комиссию 2%";
    } catch {}
    throw new Error(message);
  }
  if (response.status === 204) return null;
  return response.json();
}

function money(value, currency = "AZN") {
  return new Intl.NumberFormat("ru-RU", { style: "currency", currency, maximumFractionDigits: 2 }).format(Number(value || 0));
}

function escapeHTML(value = "") {
  return String(value).replace(/[&<>'"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[c]));
}

function toast(message) {
  const node = $("#toast"); node.textContent = message; node.classList.remove("hidden");
  clearTimeout(toast.timer); toast.timer = setTimeout(() => node.classList.add("hidden"), 2600);
}

function setBusy(button, busy) {
  if (!button) return; button.disabled = busy;
  if (busy) { button.dataset.label = button.textContent; button.textContent = "Подождите…"; }
  else if (button.dataset.label) button.textContent = button.dataset.label;
}

function showAuth() {
  $("#boot").classList.add("hidden"); $("#shell").classList.add("hidden"); $("#auth").classList.remove("hidden");
}

function showShell() {
  $("#boot").classList.add("hidden"); $("#auth").classList.add("hidden"); $("#shell").classList.remove("hidden");
}

async function refreshAll() {
  try {
    const [profile, wallets, cards, transactions, notifications] = await Promise.all([
      api("/api/me"), api("/api/wallets"), api("/api/cards"), api("/api/transactions"), api("/api/notifications")
    ]);
    Object.assign(state, { profile, wallets, cards, transactions, notifications });
    render(); showShell();
  } catch (error) { if (state.token) toast(error.message); }
}

function render() {
  const total = state.wallets.reduce((sum, item) => sum + Number(item.balance) * (rates[item.currency] || 1), 0);
  $("#total-balance").textContent = money(total, "AZN");
  $("#wallets").innerHTML = state.wallets.map(item => `<div class="wallet"><span>${item.currency}</span><b>${money(item.balance, item.currency)}</b></div>`).join("");
  $("#transactions").innerHTML = state.transactions.length ? state.transactions.slice(0, 12).map(tx => `
    <div class="list-row"><div class="row-icon">${tx.amount >= 0 ? "↓" : "↑"}</div><div><b>${escapeHTML(tx.title)}</b><small>${new Date(tx.created_at).toLocaleDateString("ru-RU")}</small></div><span class="amount">${money(tx.amount, tx.currency)}</span></div>`).join("") : `<div class="empty">Операций пока нет</div>`;
  renderCards();
  if (state.profile) {
    $("#profile-name").textContent = `${state.profile.first_name} ${state.profile.last_name}`;
    $("#profile-username").textContent = `@${state.profile.username}`;
    $("#avatar").textContent = `${state.profile.first_name[0] || ""}${state.profile.last_name[0] || ""}`.toUpperCase();
  }
}

function renderCards() {
  $("#cards").innerHTML = state.cards.length ? state.cards.map(card => `
    <article class="bank-card ${escapeHTML(card.design)} ${card.frozen ? "frozen" : ""}">
      <div class="card-top"><b>GRAMIN</b><span>${card.frozen ? "ЗАМОРОЖЕНА" : "VIRTUAL"}</span></div>
      <div class="card-number">•••• &nbsp;•••• &nbsp;•••• &nbsp;${card.number.slice(-4)}</div>
      <div class="card-bottom"><span>${card.expiry}</span><b>${card.currency}</b></div>
    </article>
    <div class="card-actions"><button data-card-freeze="${card.id}">${card.frozen ? "Разморозить" : "Заморозить"}</button><button data-card-details="${card.id}">Реквизиты</button></div>`).join("") : `<div class="empty card">Создайте первую виртуальную карту Gramin</div>`;
  $$('[data-card-freeze]').forEach(button => button.onclick = () => freezeCard(button.dataset.cardFreeze));
  $$('[data-card-details]').forEach(button => button.onclick = () => showCardDetails(button.dataset.cardDetails));
}

async function freezeCard(id) {
  try { await api(`/api/cards/${id}/freeze`, { method: "POST" }); await refreshAll(); toast("Статус карты обновлён"); }
  catch (error) { toast(error.message); }
}

function showCardDetails(id) {
  const card = state.cards.find(item => item.id === id); if (!card) return;
  openModal("Реквизиты карты", `
    <label>Номер карты<input readonly value="${card.number.replace(/(.{4})/g, "$1 ").trim()}"></label>
    <div class="pair"><label>Срок<input readonly value="${card.expiry}"></label><label>CVV<input readonly value="${card.cvv}"></label></div>`, null, "Закрыть");
}

function openModal(title, fields, onSubmit, submitLabel = "Продолжить") {
  const form = $("#modal-form");
  form.innerHTML = `<h3>${title}</h3>${fields}<div class="modal-actions"><button type="button" class="secondary" id="modal-cancel">Отмена</button><button type="submit" class="primary">${submitLabel}</button></div>`;
  $("#modal-cancel", form).onclick = () => $("#modal").close();
  form.onsubmit = async event => {
    event.preventDefault(); if (!onSubmit) { $("#modal").close(); return; }
    const submit = $('button[type="submit"]', form); setBusy(submit, true);
    try { await onSubmit(Object.fromEntries(new FormData(form))); $("#modal").close(); }
    catch (error) { toast(error.message); }
    finally { setBusy(submit, false); }
  };
  $("#modal").showModal();
}

function createCardModal() {
  openModal("Новая карта", `
    <label>Валюта<select name="currency"><option>AZN</option><option>USD</option><option>EUR</option><option>RUB</option></select></label>
    <label>Дизайн<select name="design"><option value="obsidian">Чёрная</option><option value="snow">Белая</option><option value="graphite">Графит</option></select></label>
    <label>PIN<input name="pin" type="password" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" placeholder="4 цифры" required></label>`, async data => {
      const card = await api("/api/cards", { method: "POST", body: JSON.stringify(data) });
      state.cards.push(card); renderCards(); toast("Карта создана"); nativeMessage("haptic", "success");
    }, "Выпустить карту");
}

function topupModal() {
  openModal("Демо-пополнение", `<label>Валюта<select name="currency"><option>AZN</option><option>USD</option><option>EUR</option><option>RUB</option></select></label><label>Сумма<input name="amount" type="number" min="0.01" step="0.01" required></label>`, async data => {
    await api("/api/wallets/top-up", { method: "POST", body: JSON.stringify({ ...data, amount: Number(data.amount) }) }); await refreshAll(); toast("Баланс пополнен");
  }, "Пополнить");
}

function exchangeModal() {
  openModal("Обмен валют", `<div class="pair"><label>Отдаёте<select name="from_currency"><option>AZN</option><option>USD</option><option>EUR</option><option>RUB</option></select></label><label>Получаете<select name="to_currency"><option>USD</option><option>EUR</option><option>RUB</option><option>AZN</option></select></label></div><label>Сумма<input name="amount" type="number" min="0.01" step="0.01" required></label>`, async data => {
    if (data.from_currency === data.to_currency) throw new Error("Выберите разные валюты");
    await api("/api/exchange", { method: "POST", body: JSON.stringify({ ...data, amount: Number(data.amount) }) }); await refreshAll(); toast("Обмен выполнен");
  }, "Обменять");
}

function transferModal() {
  openModal("Новый перевод", `<label>Получатель<input name="recipient" placeholder="@username или номер карты" required minlength="4"></label><label>Валюта<select name="currency"><option>AZN</option><option>USD</option><option>EUR</option><option>RUB</option></select></label><label>Сумма<input name="amount" type="number" min="0.01" step="0.01" required></label><label class="switch-row"><span>Подтверждаю крупный перевод и комиссию 2%</span><input name="confirm_large" type="checkbox"></label>`, async data => {
    await api("/api/transfers", { method: "POST", body: JSON.stringify({ recipient: data.recipient, currency: data.currency, amount: Number(data.amount), confirm_large: data.confirm_large === "on" }) }); await refreshAll(); toast("Перевод отправлен");
  }, "Перевести");
}

function paymentModal(category) {
  const item = services.find(x => x[0] === category); if (!item) return;
  openModal(item[1], `<label>Поставщик<select name="provider">${item[3].map(x => `<option>${x}</option>`).join("")}</select></label><label>Лицевой счёт или номер<input name="account" required minlength="2"></label><div class="pair"><label>Валюта<select name="currency"><option>AZN</option><option>USD</option><option>EUR</option><option>RUB</option></select></label><label>Сумма<input name="amount" type="number" min="0.01" step="0.01" required></label></div>`, async data => {
    await api("/api/payments", { method: "POST", body: JSON.stringify({ ...data, category, amount: Number(data.amount) }) }); await refreshAll(); toast("Оплата выполнена");
  }, "Оплатить");
}

async function loadAnalytics() {
  try {
    const analytics = await api(`/api/analytics?period=${state.period}`);
    $("#analytics-total").textContent = money(analytics.total, "AZN");
    renderBars("#categories", analytics.categories.map(x => [x.name, Number(x.amount)]));
    renderBars("#daily", analytics.daily.map(x => [new Date(x.date).toLocaleDateString("ru-RU", { day: "2-digit", month: "short" }), Number(x.amount)]));
  } catch (error) { toast(error.message); }
}

function renderBars(selector, items) {
  const max = Math.max(1, ...items.map(x => x[1]));
  $(selector).innerHTML = items.length ? items.map(([name, value]) => `<div class="bar-row"><span>${escapeHTML(name)}</span><div class="bar-track"><div class="bar-fill" style="width:${value / max * 100}%"></div></div><b>${money(value, "AZN")}</b></div>`).join("") : `<div class="empty">Недостаточно данных</div>`;
}

function setView(name) {
  $$(".view").forEach(x => x.classList.toggle("active", x.id === `view-${name}`));
  $$(".tabbar button").forEach(x => x.classList.toggle("active", x.dataset.view === name));
  $("#page-title").textContent = ({ home: "Главная", cards: "Карты", payments: "Платежи", analytics: "Аналитика", profile: "Профиль" })[name];
  if (name === "analytics") loadAnalytics();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function bind() {
  $$('[data-auth-mode]').forEach(button => button.onclick = () => {
    $$('[data-auth-mode]').forEach(x => x.classList.toggle("active", x === button));
    $("#login-form").classList.toggle("hidden", button.dataset.authMode !== "login");
    $("#register-form").classList.toggle("hidden", button.dataset.authMode !== "register");
  });
  $("#login-form").onsubmit = event => authenticate(event, "/api/auth/login");
  $("#register-form").onsubmit = event => authenticate(event, "/api/auth/register");
  $$(".tabbar button").forEach(button => button.onclick = () => setView(button.dataset.view));
  $$('[data-action]').forEach(button => button.onclick = () => ({ transfer: transferModal, topup: topupModal, exchange: exchangeModal, "create-card": createCardModal })[button.dataset.action]?.());
  $("#refresh").onclick = refreshAll;
  $("#logout").onclick = () => { clearToken(); showAuth(); toast("Вы вышли из аккаунта"); };
  $("#dark-mode").checked = localStorage.getItem("gramin-dark") === "1";
  $("#dark-mode").onchange = event => setTheme(event.target.checked);
  $$("#periods button").forEach(button => button.onclick = () => { state.period = button.dataset.period; $$("#periods button").forEach(x => x.classList.toggle("active", x === button)); loadAnalytics(); });
  $("#services").innerHTML = services.map(item => `<button class="service" data-service="${item[0]}"><b>${item[2]}</b><span>${item[1]}</span></button>`).join("");
  $$('[data-service]').forEach(button => button.onclick = () => paymentModal(button.dataset.service));
}

async function authenticate(event, path) {
  event.preventDefault(); const button = $('button[type="submit"]', event.currentTarget); setBusy(button, true);
  try {
    const data = Object.fromEntries(new FormData(event.currentTarget));
    if (data.username) data.username = data.username.trim().replace(/^@/, "").toLowerCase();
    const auth = await api(path, { method: "POST", body: JSON.stringify(data) });
    saveToken(auth.access_token); await refreshAll(); nativeMessage("haptic", "success");
  } catch (error) { toast(error.message); }
  finally { setBusy(button, false); }
}

function setTheme(dark) {
  document.documentElement.classList.toggle("dark", dark); localStorage.setItem("gramin-dark", dark ? "1" : "0");
}

document.addEventListener("DOMContentLoaded", async () => {
  setTheme(localStorage.getItem("gramin-dark") === "1"); bind();
  if (state.token) await refreshAll(); else showAuth();
});
