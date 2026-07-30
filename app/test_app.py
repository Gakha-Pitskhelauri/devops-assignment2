import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert "message" in data


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"


def test_error_endpoint(client):
    response = client.get("/error")
    assert response.status_code == 500
    data = response.get_json()
    assert data["status"] == "error"


def test_metrics_endpoint(client):
    response = client.get("/metrics")
    assert response.status_code == 200
    body = response.get_data(as_text=True)
    assert "app_requests_total" in body
    assert "app_errors_total" in body


def test_metrics_increments(client):
    client.get("/")
    client.get("/")
    response = client.get("/metrics")
    body = response.get_data(as_text=True)
    assert 'app_requests_total{endpoint="/",method="GET"}' in body


def test_error_increments_error_counter(client):
    client.get("/error")
    response = client.get("/metrics")
    body = response.get_data(as_text=True)
    assert "app_errors_total" in body
