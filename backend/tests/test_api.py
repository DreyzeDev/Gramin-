from .conftest import register


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
    frozen = client.post(f"/api/cards/{card.json()['id']}/freeze", headers=headers)
    assert frozen.json()["frozen"] is True
    payment = client.post("/api/payments", headers=headers, json={
        "provider": "Mobile", "account": "+994501234567", "category": "mobile",
        "currency": "USD", "amount": 10
    })
    assert payment.status_code == 200

