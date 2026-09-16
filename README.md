<div align="center">

# Gramin

### A minimal demo bank for iPhone

![iOS](https://img.shields.io/badge/iOS-17%2B-000?style=for-the-badge&logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.9-000?style=for-the-badge&logo=swift&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-Python-000?style=for-the-badge&logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-000?style=for-the-badge&logo=postgresql&logoColor=white)

</div>

Gramin is a full-stack educational banking simulator. It uses **virtual money only** and is not connected to real banks, cards or payment systems.

## Included in the MVP

- Registration with name, birthday, avatar-ready profile, unique `@username` and password
- Four wallets: AZN, USD, EUR and RUB with fixed demo exchange rates
- Multiple virtual cards with three minimalist designs
- Card details, freeze/unfreeze, PIN change, daily limit and closing
- Transfers by `@username` or 16-digit virtual card number
- 2% fee for transfers equivalent to 5,000 AZN or more, with explicit confirmation
- Simulated top-ups, service payments and owner fund grants
- Transaction history and in-app notification inbox
- Spending analytics for week, month and year: category pie chart and daily line chart
- Face ID, local four-digit app PIN and Keychain token storage
- Russian and English interface resources
- Local iOS notifications and a scheduled weekly report

## Repository structure

```text
.
├── backend/              FastAPI + SQLAlchemy API
├── ios/                  Native SwiftUI application
├── .github/workflows/    API tests and unsigned IPA build
├── docker-compose.yml    Local API + PostgreSQL
└── render.yaml           Cloud deployment blueprint
```

## Run the API locally

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

API documentation opens at `http://127.0.0.1:8000/docs`.

Or start the API and PostgreSQL together:

```bash
docker compose up --build
```

### Give a user virtual money

There is intentionally no admin panel. The repository owner can use the protected server shell:

```bash
cd backend
python scripts/grant_funds.py dreyze 10000 AZN
```

Users can also perform an instant simulated top-up inside the app.

## Run the iOS client

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the generated `.xcodeproj` does not pollute Git history.

```bash
brew install xcodegen
cd ios
xcodegen generate
open Gramin.xcodeproj
```

Open **Profile → Server** and enter the public HTTPS address of the deployed API.

The default API address in the iOS client is `https://gramin.moonfacet.com`. It can also be changed on the sign-in screen or later in **Profile → Server**.

### App updates

Each iOS build publishes `Gramin-unsigned.ipa` in GitHub Releases. The app checks the latest release when it opens and offers a download when a newer version is available. Because iOS does not allow an unsigned native app to replace its own executable, the downloaded IPA must still be signed with AltStore or Sideloadly and installed over the existing app. Installing over the same bundle identifier preserves local app data.

## Build an unsigned IPA

Open **Actions → Build unsigned IPA → Run workflow**. Download `Gramin-unsigned-IPA` from the completed run.

The artifact is intentionally unsigned because no Apple Developer account is configured. It cannot be installed directly like an App Store application; sign it with your own Apple ID using a sideloading tool such as Sideloadly or AltStore. Free Apple ID signatures normally expire and need renewal.

## Notifications without Apple Developer

Gramin implements:

- an in-app inbox synchronized with the API;
- local system notifications for operations performed on the device;
- a scheduled weekly spending reminder;
- refresh of server events whenever the app opens.

True remote push notifications require APNs entitlements and Apple signing. The notification layer is isolated so APNs can be added later without changing banking logic.

## Security scope

This is a demo and must never process real money or real card credentials. Passwords and PINs are Argon2 hashes, auth uses expiring JWTs, and the iOS token is stored in Keychain. Production banking would additionally require audited ledgers, encryption key management, compliance, fraud controls, rate limits and independent security review.

## Test

```bash
cd backend
pytest -q
```

---

<div align="center">Designed and developed by <a href="https://github.com/DreyzeDev">Dreyze</a></div>

