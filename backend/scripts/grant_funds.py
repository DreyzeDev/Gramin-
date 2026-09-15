"""Owner-only local helper. Example: python scripts/grant_funds.py dreyze 10000 AZN"""
import sys
from decimal import Decimal
from sqlalchemy import select
from app.database import SessionLocal
from app.models import User, Wallet
from app.services import add_transaction, money, notify


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("Usage: grant_funds.py USERNAME AMOUNT CURRENCY")
    username, raw_amount, currency = sys.argv[1], sys.argv[2], sys.argv[3].upper()
    amount = Decimal(raw_amount)
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.username == username.removeprefix("@").lower()))
        if not user:
            raise SystemExit("User not found")
        wallet = db.scalar(select(Wallet).where(Wallet.user_id == user.id, Wallet.currency == currency))
        if not wallet:
            raise SystemExit("Wallet not found")
        wallet.balance = money(wallet.balance + amount)
        add_transaction(db, user.id, "admin_grant", amount, currency, "Выдача владельцем", "income")
        notify(db, user.id, "Баланс пополнен", f"Владелец выдал {money(amount)} {currency}.", "money")
        db.commit()
        print(f"Granted {money(amount)} {currency} to @{user.username}")


if __name__ == "__main__":
    main()

