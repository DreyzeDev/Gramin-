import os
os.environ["DATABASE_URL"] = "sqlite:///./test_gramin.sqlite3"
os.environ["JWT_SECRET"] = "test-secret"

import pytest
from fastapi.testclient import TestClient
from app.database import Base, engine
from app.main import app


@pytest.fixture(autouse=True)
def fresh_database():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture
def client():
    with TestClient(app) as value:
        yield value


def register(client, username: str):
    response = client.post("/api/auth/register", json={
        "first_name": "Test", "last_name": "User", "username": username,
        "password": "strong-password", "birth_date": "2000-01-01"
    })
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}

