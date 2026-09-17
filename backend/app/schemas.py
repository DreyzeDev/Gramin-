from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field, field_validator


SUPPORTED_CURRENCIES = {"AZN", "USD", "EUR", "RUB"}
SUPPORTED_CARD_DESIGNS = {"obsidian", "snow", "graphite", "bronze", "gold"}


class RegisterIn(BaseModel):
    first_name: str = Field(min_length=2, max_length=80)
    last_name: str = Field(min_length=2, max_length=80)
    username: str = Field(min_length=4, max_length=32, pattern=r"^[A-Za-z0-9_]+$")
    password: str = Field(min_length=8, max_length=128)
    birth_date: date
    avatar_url: str | None = None

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value: object) -> object:
        return value.removeprefix("@").lower() if isinstance(value, str) else value


class LoginIn(BaseModel):
    username: str
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    first_name: str
    last_name: str
    username: str
    birth_date: date
    avatar_url: str | None


class WalletOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    currency: str
    balance: Decimal


class MoneyIn(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    currency: str

    @field_validator("currency")
    @classmethod
    def valid_currency(cls, value: str) -> str:
        code = value.upper()
        if code not in SUPPORTED_CURRENCIES:
            raise ValueError("Unsupported currency")
        return code


class ExchangeIn(BaseModel):
    from_currency: str
    to_currency: str
    amount: Decimal = Field(gt=0)


class CardCreateIn(BaseModel):
    currency: str
    design: str = "obsidian"
    pin: str = Field(pattern=r"^\d{4}$")

    @field_validator("currency")
    @classmethod
    def valid_currency(cls, value: str) -> str:
        code = value.upper()
        if code not in SUPPORTED_CURRENCIES:
            raise ValueError("Unsupported currency")
        return code

    @field_validator("design")
    @classmethod
    def valid_design(cls, value: str) -> str:
        if value not in SUPPORTED_CARD_DESIGNS:
            raise ValueError("Unsupported card design")
        return value


class CardOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    number: str
    currency: str
    design: str
    expiry: str
    cvv: str
    frozen: bool
    closed: bool
    daily_limit: Decimal


class CardPinIn(BaseModel):
    pin: str = Field(pattern=r"^\d{4}$")


class CardLimitIn(BaseModel):
    amount: Decimal = Field(gt=0)


class TransferIn(BaseModel):
    recipient: str = Field(min_length=4, max_length=40)
    currency: str
    amount: Decimal = Field(gt=0)
    confirm_large: bool = False


class PaymentIn(BaseModel):
    provider: str = Field(min_length=2, max_length=80)
    account: str = Field(min_length=2, max_length=80)
    category: str
    currency: str
    amount: Decimal = Field(gt=0)


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    kind: str
    amount: Decimal
    currency: str
    category: str
    title: str
    counterparty: str | None
    created_at: datetime


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    title: str
    body: str
    kind: str
    read: bool
    created_at: datetime

