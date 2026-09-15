from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
import secrets
from sqlalchemy import select
from sqlalchemy.orm import Session
from fastapi import HTTPException
from .models import Card, Notification, Transaction, User, Wallet
from .security import hash_secret


RATES_TO_AZN = {
    "AZN": Decimal("1.0000"),
    "USD": Decimal("1.7000"),
    "EUR": Decimal("1.8500"),
    "RUB": Decimal("0.0180"),
}
CURRENCIES = tuple(RATES_TO_AZN)


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def convert(amount: Decimal, source: str, target: str) -> Decimal:
    try:
        return money(amount * RATES_TO_AZN[source] / RATES_TO_AZN[target])
    except KeyError:
        raise HTTPException(400, "Unsupported currency")


def wallet(db: Session, user_id: str, currency: str) -> Wallet:
    result = db.scalar(select(Wallet).where(Wallet.user_id == user_id, Wallet.currency == currency.upper()))
    if not result:
        raise HTTPException(404, "Wallet not found")
    return result


def add_transaction(db: Session, user_id: str, kind: str, amount: Decimal, currency: str,
                    title: str, category: str = "other", counterparty: str | None = None) -> Transaction:
    tx = Transaction(user_id=user_id, kind=kind, amount=money(amount), currency=currency,
                     title=title, category=category, counterparty=counterparty)
    db.add(tx)
    return tx


def notify(db: Session, user_id: str, title: str, body: str, kind: str = "info") -> None:
    db.add(Notification(user_id=user_id, title=title, body=body, kind=kind))


def card_number(db: Session) -> str:
    while True:
        number = "4242" + "".join(str(secrets.randbelow(10)) for _ in range(12))
        if not db.scalar(select(Card).where(Card.number == number)):
            return number


def issue_card(db: Session, user: User, currency: str, design: str, pin: str) -> Card:
    if currency not in CURRENCIES:
        raise HTTPException(400, "Unsupported currency")
    expiry = (datetime.now(timezone.utc) + timedelta(days=365 * 4)).strftime("%m/%y")
    card = Card(user_id=user.id, number=card_number(db), currency=currency, design=design,
                pin_hash=hash_secret(pin), expiry=expiry,
                cvv=f"{secrets.randbelow(1000):03d}")
    db.add(card)
    return card

