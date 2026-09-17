const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const iconPaths = {
  refresh: '<path d="M20 6v5h-5"/><path d="M19 11a8 8 0 1 0 1.3 6.3"/>',
  home: '<path d="m3 10 9-7 9 7"/><path d="M5 9v11h14V9"/><path d="M9 20v-6h6v6"/>',
  card: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18"/><path d="M7 15h3"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  chart: '<path d="M4 19V9"/><path d="M10 19V5"/><path d="M16 19v-7"/><path d="M22 19V3"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  send: '<path d="M7 17 17 7"/><path d="M8 7h9v9"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  repeat: '<path d="m17 2 4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15"/><path d="m7 22-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/>',
  phone: '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
  wifi: '<path d="M5 12.6a11 11 0 0 1 14 0"/><path d="M8.5 16a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r="1" fill="currentColor" stroke="none"/>',
  contactless: '<path d="M6 5c4 4 4 10 0 14"/><path d="M10 8c2.5 2.5 2.5 5.5 0 8"/><path d="M14 11c1 1 1 1 0 2"/>',
  bolt: '<path d="m13 2-9 12h7l-1 8 9-12h-7z"/>',
  gamepad: '<path d="M7 8h10a5 5 0 0 1 4.7 6.8l-1 2.7a2.4 2.4 0 0 1-4.1.7L15 16H9l-1.6 2.2a2.4 2.4 0 0 1-4.1-.7l-1-2.7A5 5 0 0 1 7 8Z"/><path d="M7 12v4M5 14h4M16 13h.01M19 15h.01"/>',
  receipt: '<path d="M6 3v18l3-2 3 2 3-2 3 2V3l-3 2-3-2-3 2z"/><path d="M9 10h6M9 14h6"/>',
  heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
  down: '<path d="M7 7h10v10"/><path d="M17 7 7 17"/>',
  up: '<path d="M7 17 17 7"/><path d="M7 7h10v10"/>',
  snowflake: '<path d="M12 2v20M4.9 6l14.2 12M4.9 18 19.1 6M9 4l3 3 3-3M9 20l3-3 3 3"/>',
  eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>'
};

function icon(name, className = "") {
  return `<svg class="svg-icon ${className}" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${iconPaths[name] || iconPaths.grid}</svg>`;
}

function hydrateIcons(root = document) {
  $$('[data-icon]', root).forEach(node => { node.innerHTML = icon(node.dataset.icon); });
}

const state = {
  token: localStorage.getItem("gramin-token") || window.__GRAMIN_NATIVE_TOKEN || "",
  profile: null, wallets: [], cards: [], transactions: [], notifications: [], period: "month"
};

const rates = { AZN: 1, USD: 1.7, EUR: 1.85, RUB: 0.018 };
const services = [
  ["mobile", "Мобильная связь", "phone", ["Azercell", "Bakcell", "Nar"]],
  ["internet", "Интернет", "wifi", ["CityNet", "Baktelecom"]],
  ["utilities", "Коммунальные", "bolt", ["Электричество", "Газ", "Вода"]],
  ["subscriptions", "Игры и подписки", "gamepad", ["App Store", "Игровой аккаунт", "Подписка"]],
  ["taxes", "Штрафы и налоги", "receipt", ["Штраф", "Налог"]],
  ["charity", "Благотворительность", "heart", ["Помощь детям", "Защита животных"]]
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
  renderHomeCardControl();
  $("#transactions").innerHTML = state.transactions.length ? state.transactions.slice(0, 12).map(tx => `
    <div class="list-row"><div class="row-icon">${icon(tx.amount >= 0 ? "down" : "up")}</div><div><b>${escapeHTML(tx.title)}</b><small>${new Date(tx.created_at).toLocaleDateString("ru-RU")}</small></div><span class="amount">${money(tx.amount, tx.currency)}</span></div>`).join("") : `<div class="empty">Операций пока нет</div>`;
  renderCards();
  if (state.profile) {
    $("#profile-name").textContent = `${state.profile.first_name} ${state.profile.last_name}`;
    $("#profile-username").textContent = `@${state.profile.username}`;
    $("#avatar").textContent = `${state.profile.first_name[0] || ""}${state.profile.last_name[0] || ""}`.toUpperCase();
  }
}

function renderHomeCardControl() {
  const host = $("#home-card-control");
  const card = state.cards[0];
  if (!card) {
    host.innerHTML = `<button class="home-card-empty" data-action="create-card">${icon("card")}<span><b>Выпустите карту</b><small>Можно выпустить до двух карт для аккаунта</small></span>${icon("plus")}</button>`;
    $("[data-action='create-card']", host).onclick = createCardModal;
    return;
  }
  const balance = state.wallets.find(item => item.currency === card.currency)?.balance || 0;
  const name = { graphite: "Black", obsidian: "Black", bronze: "Bronze", gold: "Gold", snow: "White" }[card.design] || "Black";
  host.innerHTML = `<div class="home-card-heading"><span>Ваша карта</span><button type="button" data-home-card-open>Управлять ${icon("down")}</button></div>
    <div class="home-card-row">
      <button type="button" class="home-card-visual ${escapeHTML(card.design)} ${card.frozen ? "frozen" : ""}" data-home-card-open aria-label="Открыть управление картой"><span class="home-card-brand">GRAMIN <i>VISA</i></span><b>${formatCardNumber(card.number)}</b><small>${name}</small></button>
      <div class="home-card-balance"><span>Баланс карты</span><strong>${money(balance, card.currency)}</strong><small>${card.frozen ? "Карта заморожена" : "Карта активна"}</small><button type="button" data-home-card-freeze>${icon("snowflake")} ${card.frozen ? "Разморозить" : "Заморозить"}</button></div>
    </div>`;
  $$('[data-home-card-open]', host).forEach(button => button.onclick = () => setView("cards"));
  $('[data-home-card-freeze]', host).onclick = () => freezeCard(card.id);
}

function renderCards() {
  $("#cards").innerHTML = state.cards.length ? state.cards.map(card => `
    <div class="card-item">
      <div class="card-scene">
        <button type="button" class="bank-card ${escapeHTML(card.design)} ${card.frozen ? "frozen" : ""}" data-card-flip="${card.id}" aria-label="Перевернуть карту" aria-pressed="false">
          <span class="card-inner">
            <span class="card-face card-front">
              <span class="card-identity"><b>GRAMIN</b><i aria-label="Visa">VISA</i></span>
              <span class="card-front-number">${formatCardNumber(card.number)}</span>
            </span>
            <span class="card-face card-back" hidden aria-hidden="true" inert>
              <span class="card-back-layout">
                <span class="card-identity"><b>GRAMIN</b><i aria-label="Visa">VISA</i></span>
                <span class="card-back-number"><small>НОМЕР КАРТЫ</small><b>${formatCardNumber(card.number)}</b></span>
                <span class="card-back-fields">
                  <span><small>СРОК</small><b>${card.expiry}</b></span>
                  <span><small>CVV</small><b>${card.cvv}</b></span>
                </span>
              </span>
            </span>
          </span>
        </button>
      </div>
      <span class="flip-hint">Нажмите на карту, чтобы увидеть реквизиты</span>
      ${cardBenefit(card)}
      <div class="card-actions"><button data-card-freeze="${card.id}">${icon("snowflake")}<span>${card.frozen ? "Разморозить" : "Заморозить"}</span></button><button data-card-flip="${card.id}">${icon("eye")}<span>Перевернуть</span></button></div>
    </div>`).join("") : `<div class="empty card"><div class="empty-icon">${icon("card")}</div><b>Карт пока нет</b><span>Выпустите одну виртуальную карту для этого аккаунта</span></div>`;
  $("#create-card").classList.toggle("hidden", state.cards.length >= 2);
  $$('[data-card-freeze]').forEach(button => button.onclick = () => freezeCard(button.dataset.cardFreeze));
  $$('[data-card-flip]').forEach(button => button.onclick = () => flipCard(button));
}

function cardBenefit(card) {
  const benefits = {
    graphite: ["shield", "Gramin Black", "Мгновенная заморозка и спокойный контроль"],
    obsidian: ["shield", "Gramin Black", "Мгновенная заморозка и спокойный контроль"],
    bronze: ["receipt", "Gramin Bronze", `Лимит ${money(card.daily_limit, card.currency)} в день для плановых трат`],
    gold: ["bolt", "Gramin Gold", `Расширенный лимит ${money(card.daily_limit, card.currency)} в день`],
    snow: ["card", "Gramin White", "Лёгкий минимализм для ежедневных покупок"]
  };
  const [iconName, title, description] = benefits[card.design] || benefits.graphite;
  return `<div class="card-benefit ${escapeHTML(card.design)}"><span>${icon(iconName)}</span><p><b>${title}</b><small>${description}</small></p></div>`;
}

function formatCardNumber(number) {
  return String(number).match(/.{1,4}/g)?.join(" ") || number;
}

const cardFlipOutDuration = 150;
const cardFlipInDuration = 210;

function setCardFaceVisible(face, visible) {
  face.hidden = !visible;
  face.inert = !visible;
  face.setAttribute("aria-hidden", String(!visible));
}

function updateCardFlipLabels(item, showingBack) {
  const card = item.querySelector(".bank-card");
  const action = item.querySelector(".card-actions [data-card-flip]");
  const hint = item.querySelector(".flip-hint");
  const label = showingBack ? "Показать лицевую сторону карты" : "Показать оборот карты";
  card?.setAttribute("aria-label", label);
  card?.setAttribute("aria-pressed", String(showingBack));
  action?.setAttribute("aria-label", label);
  if (action?.querySelector("span")) action.querySelector("span").textContent = showingBack ? "Вернуть" : "Перевернуть";
  if (hint) hint.textContent = showingBack ? "Нажмите на карту, чтобы скрыть реквизиты" : "Нажмите на карту, чтобы увидеть реквизиты";
}

function flipCard(trigger) {
  const item = trigger.closest(".card-item");
  const card = item?.querySelector(".bank-card");
  if (!card || card.dataset.flipping === "true") return;

  const front = card.querySelector(".card-front");
  const back = card.querySelector(".card-back");
  const showingBack = item.classList.contains("showing-back");
  const outgoing = showingBack ? back : front;
  const incoming = showingBack ? front : back;
  if (!outgoing || !incoming) return;

  card.dataset.flipping = "true";
  card.classList.add("is-flipping");
  item.querySelectorAll("[data-card-flip]").forEach(button => { button.disabled = true; });
  outgoing.classList.add("card-face-leaving");

  window.setTimeout(() => {
    outgoing.classList.remove("card-face-leaving");
    setCardFaceVisible(outgoing, false);
    setCardFaceVisible(incoming, true);
    incoming.classList.add("card-face-entering");
    item.classList.toggle("showing-back", !showingBack);
    updateCardFlipLabels(item, !showingBack);
    nativeMessage("haptic", "selection");

    window.setTimeout(() => {
      incoming.classList.remove("card-face-entering");
      card.classList.remove("is-flipping");
      delete card.dataset.flipping;
      item.querySelectorAll("[data-card-flip]").forEach(button => { button.disabled = false; });
    }, cardFlipInDuration);
  }, cardFlipOutDuration);
}

async function freezeCard(id) {
  try { await api(`/api/cards/${id}/freeze`, { method: "POST" }); await refreshAll(); toast("Статус карты обновлён"); }
  catch (error) { toast(error.message); }
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
  const designs = [
    ["graphite", "Чёрная", "Защита и контроль", "shield", "Мгновенная заморозка в одно касание", "2 500"],
    ["bronze", "Бронзовая", "Режим накоплений", "receipt", "Больше пространства для плановых трат", "5 000"],
    ["gold", "Золотая", "Премиальный лимит", "bolt", "Расширенный ежедневный лимит", "10 000"]
  ];
  openModal("Выберите карту", `
    <div class="issuance-steps" aria-label="Шаги выпуска"><span class="active">1&nbsp; Дизайн</span><span>2&nbsp; Валюта</span><span>3&nbsp; PIN</span></div>
    <p class="issuance-lead">Проведите по коллекции и выберите дизайн. Для аккаунта доступно до двух виртуальных карт.</p>
    <div class="design-rail" role="radiogroup" aria-label="Дизайн карты">${designs.map(([id, title, note, glyph], index) => `
      <button type="button" class="design-choice ${index === 0 ? "selected" : ""}" data-design-choice="${id}" role="radio" aria-checked="${index === 0}">
        <span class="design-preview ${id}"><span class="design-preview-brand">GRAMIN <i>VISA</i></span><span class="design-preview-glyph">${icon(glyph)}</span></span>
        <b>${title}</b><small>${note}</small>
      </button>`).join("")}</div>
    <div class="issuance-perk"><span>${icon("shield")}</span><p><b id="issuance-perk-title">Gramin Black</b><small id="issuance-perk-copy">Мгновенная заморозка в одно касание</small></p><strong id="issuance-perk-limit">2 500 AZN</strong></div>
    <div class="issuance-form"><label>Валюта</label><div class="currency-pills" role="radiogroup">${["AZN", "USD", "EUR", "RUB"].map((currency, index) => `<button type="button" class="currency-pill ${index === 0 ? "selected" : ""}" data-currency="${currency}" role="radio" aria-checked="${index === 0}">${currency}</button>`).join("")}</div>
    <input name="currency" type="hidden" value="AZN">
    <input name="design" type="hidden" value="graphite">
    <label>Придумайте PIN <small class="field-hint">4 цифры — он понадобится для операций</small><input class="pin-entry" name="pin" type="password" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" placeholder="••••" required></label></div>`, async data => {
      const card = await api("/api/cards", { method: "POST", body: JSON.stringify(data) });
      state.cards.push(card); renderCards(); toast("Карта создана"); nativeMessage("haptic", "success");
    }, "Выпустить карту");
  const form = $("#modal-form");
  $$('[data-design-choice]', form).forEach(choice => choice.onclick = () => {
    $$('[data-design-choice]', form).forEach(item => { const selected = item === choice; item.classList.toggle("selected", selected); item.setAttribute("aria-checked", String(selected)); });
    $('input[name="design"]', form).value = choice.dataset.designChoice;
    const design = designs.find(item => item[0] === choice.dataset.designChoice);
    $("#issuance-perk-title", form).textContent = `Gramin ${design[1]}`;
    $("#issuance-perk-copy", form).textContent = design[4];
    $("#issuance-perk-limit", form).textContent = `${design[5]} ${$('input[name="currency"]', form).value}`;
    $(".issuance-perk .svg-icon", form).outerHTML = icon(design[3]);
    nativeMessage("haptic", "light");
  });
  $$('[data-currency]', form).forEach(choice => choice.onclick = () => {
    $$('[data-currency]', form).forEach(item => { const selected = item === choice; item.classList.toggle("selected", selected); item.setAttribute("aria-checked", String(selected)); });
    $('input[name="currency"]', form).value = choice.dataset.currency;
    const design = designs.find(item => item[0] === $('input[name="design"]', form).value);
    $("#issuance-perk-limit", form).textContent = `${design[5]} ${choice.dataset.currency}`;
    nativeMessage("haptic", "light");
  });
  $('input[name="pin"]', form).oninput = event => { event.target.value = event.target.value.replace(/\D/g, "").slice(0, 4); };
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
  $("#services").innerHTML = services.map(item => `<button class="service" data-service="${item[0]}"><b>${icon(item[2])}</b><span>${item[1]}</span></button>`).join("");
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
  setTheme(localStorage.getItem("gramin-dark") === "1"); hydrateIcons(); bind();
  if (state.token) await refreshAll(); else showAuth();
});
