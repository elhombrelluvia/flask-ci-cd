import pytest
from main import app

@pytest.fixture
def client():
    app.config["TESTING"] = True

    with app.test_client() as client:
        yield client

def test_home_endpoint(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()

    assert data == {
        "status": "ok",
        "code": 200,
        "message": "Hola MUNDO!"
    }