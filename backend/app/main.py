from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session
from .config import get_settings
from .database import Base, engine, get_db
from .models import Card, Notification, Transaction, User, Wallet
from .schemas import (
    CardCreateIn, CardLimitIn, CardOut, CardPinIn, ExchangeIn, LoginIn, MoneyIn,
    NotificationOut, PaymentIn, RegisterIn, TokenOut, TransactionOut, TransferIn,
    UserOut, WalletOut,
)
from .security import create_token, current_user, hash_secret, verify_secret
from .services import CURRENCIES, RATES_TO_AZN, add_transaction, convert, issue_card, money, notify, wallet


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    yield


app = FastAPI(title="Gramin Demo Bank API", version="0.1.0", lifespan=lifespan)
origins = get_settings().cors_origins.split(",")
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])
WEB_DIR = Path(__file__).resolve().parent.parent / "web"
app.mount("/app-assets", StaticFiles(directory=WEB_DIR / "assets"), name="app-assets")


@app.middleware("http")
async def prevent_stale_web_shell(request, call_next):
    response = await call_next(request)
    if request.url.path == "/app" or request.url.path.startswith("/app-assets/"):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    return response


@app.get("/app", include_in_schema=False)
def web_app():
    return FileResponse(WEB_DIR / "index.html", headers={"Cache-Control": "no-store"})


@app.get("/health")
def health():
    return {"status": "ok", "service": "gramin-api"}


@app.post("/api/auth/register", response_model=TokenOut, status_code=201)
def register(data: RegisterIn, db: Session = Depends(get_db)):
    if db.scalar(select(User).where(User.username == data.username)):
        raise HTTPException(409, "Username is already taken")
    user = User(first_name=data.first_name.strip(), last_name=data.last_name.strip(),
                username=data.username, password_hash=hash_secret(data.password),
                birth_date=data.birth_date, avatar_url=data.avatar_url)
    db.add(user)
    db.flush()
    for currency in CURRENCIES:
        db.add(Wallet(user_id=user.id, currency=currency, balance=Decimal("0")))
    notify(db, user.id, "Добро пожаловать в Gramin", "Ваш демо-счёт готов к работе.", "welcome")
    db.commit()
    return TokenOut(access_token=create_token(user.id))


@app.post("/api/auth/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    username = data.username.removeprefix("@").lower()
    user = db.scalar(select(User).where(User.username == username))
    if not user or not verify_secret(data.password, user.password_hash):
        raise HTTPException(401, "Invalid username or password")
    notify(db, user.id, "Новый вход", "Выполнен вход в аккаунт Gramin.", "security")
    db.commit()
    return TokenOut(access_token=create_token(user.id))


@app.get("/api/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user


@app.get("/api/rates")
def rates():
    return {"base": "AZN", "rates_to_azn": {key: float(value) for key, value in RATES_TO_AZN.items()}}


@app.get("/api/wallets", response_model=list[WalletOut])
def wallets(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Wallet).where(Wallet.user_id == user.id).order_by(Wallet.currency)).all()


@app.post("/api/wallets/top-up", response_model=WalletOut)
def top_up(data: MoneyIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = wallet(db, user.id, data.currency)
    target.balance = money(target.balance + data.amount)
    add_transaction(db, user.id, "top_up", data.amount, data.currency, "Демо-пополнение", "income")
    notify(db, user.id, "Счёт пополнен", f"+{money(data.amount)} {data.currency}", "money")
    db.commit()
    db.refresh(target)
    return target


@app.post("/api/exchange")
def exchange(data: ExchangeIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    source_code, target_code = data.from_currency.upper(), data.to_currency.upper()
    if source_code == target_code:
        raise HTTPException(400, "Choose two different currencies")
    source, target = wallet(db, user.id, source_code), wallet(db, user.id, target_code)
    if source.balance < data.amount:
        raise HTTPException(400, "Insufficient funds")
    received = convert(data.amount, source_code, target_code)
    source.balance = money(source.balance - data.amount)
    target.balance = money(target.balance + received)
    add_transaction(db, user.id, "exchange_out", -data.amount, source_code, f"Обмен на {target_code}", "exchange")
    add_transaction(db, user.id, "exchange_in", received, target_code, f"Обмен из {source_code}", "exchange")
    db.commit()
    return {"spent": money(data.amount), "received": received, "rate": money(received / data.amount)}


@app.get("/api/cards", response_model=list[CardOut])
def cards(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Card).where(Card.user_id == user.id, Card.closed.is_(False))).all()


@app.post("/api/cards", response_model=CardOut, status_code=201)
def create_card(data: CardCreateIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    active_cards = db.scalars(select(Card).where(Card.user_id == user.id, Card.closed.is_(False))).all()
    if len(active_cards) >= 2:
        raise HTTPException(409, "Account already has two active cards")
    card = issue_card(db, user, data.currency.upper(), data.design, data.pin)
    notify(db, user.id, "Новая карта", f"Виртуальная карта {data.currency.upper()} создана.", "card")
    db.commit()
    db.refresh(card)
    return card


def owned_card(card_id: str, user: User, db: Session) -> Card:
    card = db.scalar(select(Card).where(Card.id == card_id, Card.user_id == user.id))
    if not card or card.closed:
        raise HTTPException(404, "Card not found")
    return card


@app.post("/api/cards/{card_id}/freeze", response_model=CardOut)
def freeze_card(card_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    card = owned_card(card_id, user, db)
    card.frozen = not card.frozen
    db.commit(); db.refresh(card)
    return card


@app.put("/api/cards/{card_id}/pin", status_code=204)
def change_pin(card_id: str, data: CardPinIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    card = owned_card(card_id, user, db)
    card.pin_hash = hash_secret(data.pin)
    db.commit()


@app.put("/api/cards/{card_id}/limit", response_model=CardOut)
def change_limit(card_id: str, data: CardLimitIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    card = owned_card(card_id, user, db)
    card.daily_limit = money(data.amount)
    db.commit(); db.refresh(card)
    return card


@app.delete("/api/cards/{card_id}", status_code=204)
def close_card(card_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    card = owned_card(card_id, user, db)
    card.closed = True
    db.commit()


def resolve_recipient(db: Session, value: str) -> User:
    clean = value.removeprefix("@").lower().replace(" ", "")
    if clean.isdigit() and len(clean) == 16:
        card = db.scalar(select(Card).where(Card.number == clean, Card.closed.is_(False)))
        if card:
            return card.user
    user = db.scalar(select(User).where(User.username == clean))
    if not user:
        raise HTTPException(404, "Recipient not found")
    return user


@app.post("/api/transfers")
def transfer(data: TransferIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    code = data.currency.upper()
    sender = wallet(db, user.id, code)
    recipient = resolve_recipient(db, data.recipient)
    if recipient.id == user.id:
        raise HTTPException(400, "Cannot transfer to yourself")
    azn_value = convert(data.amount, code, "AZN")
    fee = money(data.amount * Decimal("0.02")) if azn_value >= Decimal("5000") else Decimal("0")
    if fee and not data.confirm_large:
        raise HTTPException(409, {"code": "large_transfer_confirmation", "fee": str(fee)})
    total = money(data.amount + fee)
    if sender.balance < total:
        raise HTTPException(400, "Insufficient funds")
    receiver = wallet(db, recipient.id, code)
    sender.balance = money(sender.balance - total)
    receiver.balance = money(receiver.balance + data.amount)
    add_transaction(db, user.id, "transfer_out", -total, code, f"Перевод @{recipient.username}", "transfer", recipient.username)
    add_transaction(db, recipient.id, "transfer_in", data.amount, code, f"Перевод от @{user.username}", "income", user.username)
    notify(db, user.id, "Перевод отправлен", f"{money(data.amount)} {code} → @{recipient.username}", "money")
    notify(db, recipient.id, "Получен перевод", f"+{money(data.amount)} {code} от @{user.username}", "money")
    db.commit()
    return {"amount": money(data.amount), "fee": fee, "currency": code, "recipient": recipient.username}


@app.post("/api/payments")
def payment(data: PaymentIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    code = data.currency.upper()
    source = wallet(db, user.id, code)
    if source.balance < data.amount:
        raise HTTPException(400, "Insufficient funds")
    source.balance = money(source.balance - data.amount)
    add_transaction(db, user.id, "payment", -data.amount, code, data.provider, data.category, data.account)
    notify(db, user.id, "Оплата выполнена", f"{data.provider}: {money(data.amount)} {code}", "payment")
    db.commit()
    return {"status": "completed", "provider": data.provider, "amount": money(data.amount), "currency": code}


@app.get("/api/transactions", response_model=list[TransactionOut])
def transactions(limit: int = Query(100, ge=1, le=500), user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Transaction).where(Transaction.user_id == user.id)
                      .order_by(Transaction.created_at.desc()).limit(limit)).all()


@app.get("/api/analytics")
def analytics(period: str = "month", user: User = Depends(current_user), db: Session = Depends(get_db)):
    days = {"week": 7, "month": 31, "year": 366}.get(period)
    if not days:
        raise HTTPException(400, "Period must be week, month or year")
    since = datetime.now(timezone.utc) - timedelta(days=days)
    txs = db.scalars(select(Transaction).where(Transaction.user_id == user.id,
                                               Transaction.created_at >= since,
                                               Transaction.amount < 0)).all()
    categories: dict[str, Decimal] = {}
    daily: dict[str, Decimal] = {}
    for tx in txs:
        azn = abs(convert(tx.amount, tx.currency, "AZN"))
        categories[tx.category] = categories.get(tx.category, Decimal("0")) + azn
        key = tx.created_at.date().isoformat()
        daily[key] = daily.get(key, Decimal("0")) + azn
    return {
        "period": period,
        "currency": "AZN",
        "total": money(sum(categories.values(), Decimal("0"))),
        "categories": [{"name": key, "amount": money(value)} for key, value in sorted(categories.items())],
        "daily": [{"date": key, "amount": money(value)} for key, value in sorted(daily.items())],
    }


@app.get("/api/notifications", response_model=list[NotificationOut])
def notifications(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Notification).where(Notification.user_id == user.id)
                      .order_by(Notification.created_at.desc()).limit(100)).all()

