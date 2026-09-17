from .conftest import register


def test_registration_accepts_at_username_and_normalizes_it(client):
    headers = register(client, "@MixedCase")
    profile = client.get("/api/me", headers=headers)
    assert profile.status_code == 200
    assert profile.json()["username"] == "mixedcase"


def test_web_app_shell_and_assets_are_served_without_cache(client):
    page = client.get("/app")
    assert page.status_code == 200
    assert "Gramin" in page.text
    assert "version-loader.js" in page.text
    assert "Что нового" in page.text
    assert "no-store" in page.headers["cache-control"]
    script = client.get("/app-assets/app.js")
    assert script.status_code == 200
    assert "refreshAll" in script.text
    assert "no-store" in script.headers["cache-control"]
    release = client.get("/app-assets/releases.json")
    assert release.status_code == 200
    assert release.json()["latest"] == "0.6.19"
    assert client.get("/app-assets/releases/0.5.0/app.js").status_code == 200
    assert client.get("/app-assets/releases/0.6.0/app.js").status_code == 200
    assert client.get("/app-assets/releases/0.6.1/app.js").status_code == 200
    assert client.get("/app-assets/releases/0.6.2/app.js").status_code == 200
    latest_script = client.get("/app-assets/releases/0.6.19/app.js")
    assert latest_script.status_code == 200
    assert "card-identity" in latest_script.text
    assert "card-back-fields" in latest_script.text
    assert "card-front-number" in latest_script.text
    assert client.get("/app-assets/gramin-card-surface-v1.png").status_code == 200
    assert client.get("/app-assets/gramin-card-surface-v2.png").status_code == 200
    assert "setCardFaceVisible" in latest_script.text


def test_register_starts_with_four_empty_wallets(client):
    headers = register(client, "dreyze")
    wallets = client.get("/api/wallets", headers=headers).json()
    assert {item["currency"] for item in wallets} == {"AZN", "USD", "EUR", "RUB"}
    assert all(float(item["balance"]) == 0 for item in wallets)


def test_top_up_transfer_and_analytics(client):
    sender = register(client, "sender")
    recipient = register(client, "receiver")
    assert client.post("/api/wallets/top-up", headers=sender, json={"amount": 6000, "currency": "AZN"}).status_code == 200
    preview = client.post("/api/transfers", headers=sender, json={
        "recipient": "@receiver", "currency": "AZN", "amount": 5000, "confirm_large": False
    })
    assert preview.status_code == 409
    sent = client.post("/api/transfers", headers=sender, json={
        "recipient": "@receiver", "currency": "AZN", "amount": 5000, "confirm_large": True
    })
    assert sent.status_code == 200
    assert float(sent.json()["fee"]) == 100
    receiver_wallets = client.get("/api/wallets", headers=recipient).json()
    assert next(float(x["balance"]) for x in receiver_wallets if x["currency"] == "AZN") == 5000
    analytics = client.get("/api/analytics?period=month", headers=sender)
    assert analytics.status_code == 200
    assert float(analytics.json()["total"]) >= 5000


def test_cards_and_payment(client):
    headers = register(client, "carduser")
    client.post("/api/wallets/top-up", headers=headers, json={"amount": 100, "currency": "USD"})
    card = client.post("/api/cards", headers=headers, json={"currency": "USD", "design": "snow", "pin": "1234"})
    assert card.status_code == 201
    listed = client.get("/api/cards", headers=headers)
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [card.json()["id"]]
    duplicate = client.post("/api/cards", headers=headers, json={
        "currency": "AZN", "design": "obsidian", "pin": "4321"
    })
    assert duplicate.status_code == 409
    assert duplicate.json()["detail"] == "Account already has an active card"
    frozen = client.post(f"/api/cards/{card.json()['id']}/freeze", headers=headers)
    assert frozen.json()["frozen"] is True
    payment = client.post("/api/payments", headers=headers, json={
        "provider": "Mobile", "account": "+994501234567", "category": "mobile",
        "currency": "USD", "amount": 10
    })
    assert payment.status_code == 200


def test_card_creation_validates_input(client):
    headers = register(client, "cardvalidation")
    bad_pin = client.post("/api/cards", headers=headers, json={
        "currency": "AZN", "design": "obsidian", "pin": "12ab"
    })
    assert bad_pin.status_code == 422
    bad_design = client.post("/api/cards", headers=headers, json={
        "currency": "AZN", "design": "rainbow", "pin": "1234"
    })
    assert bad_design.status_code == 422
    assert client.get("/api/cards", headers=headers).json() == []
