from __future__ import annotations
from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base


def uid() -> str:
    return str(uuid4())


def now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    first_name: Mapped[str] = mapped_column(String(80))
    last_name: Mapped[str] = mapped_column(String(80))
    username: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    birth_date: Mapped[date] = mapped_column(Date)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    app_pin_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    wallets: Mapped[list[Wallet]] = relationship(back_populates="user", cascade="all, delete-orphan")
    cards: Mapped[list[Card]] = relationship(back_populates="user", cascade="all, delete-orphan")


class Wallet(Base):
    __tablename__ = "wallets"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    currency: Mapped[str] = mapped_column(String(3), index=True)
    balance: Mapped[Decimal] = mapped_column(Numeric(18, 2), default=Decimal("0.00"))
    user: Mapped[User] = relationship(back_populates="wallets")


class Card(Base):
    __tablename__ = "cards"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    number: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    currency: Mapped[str] = mapped_column(String(3))
    design: Mapped[str] = mapped_column(String(24), default="obsidian")
    pin_hash: Mapped[str] = mapped_column(String(255))
    expiry: Mapped[str] = mapped_column(String(5))
    cvv: Mapped[str] = mapped_column(String(3))
    frozen: Mapped[bool] = mapped_column(Boolean, default=False)
    closed: Mapped[bool] = mapped_column(Boolean, default=False)
    daily_limit: Mapped[Decimal] = mapped_column(Numeric(18, 2), default=Decimal("2500"))
    user: Mapped[User] = relationship(back_populates="cards")


class Transaction(Base):
    __tablename__ = "transactions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(30), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2))
    currency: Mapped[str] = mapped_column(String(3))
    category: Mapped[str] = mapped_column(String(40), default="other")
    title: Mapped[str] = mapped_column(String(160))
    counterparty: Mapped[str | None] = mapped_column(String(80), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(String(300))
    kind: Mapped[str] = mapped_column(String(30), default="info")
    read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)

