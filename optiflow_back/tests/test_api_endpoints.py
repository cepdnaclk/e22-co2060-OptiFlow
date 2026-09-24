import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200

def test_get_resources():
    response = client.get("/api/resources")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    human_workers = [r for r in data if r.get("type") == "HUMAN"]
    assert len(human_workers) >= 3

def test_tasks_marcus_http():
    # Marcus: 33333333-3333-3333-3333-333333333332 -> HP Indigo: 22222222-2222-2222-2222-222222222222
    response = client.get("/api/tasks?resource_id=33333333-3333-3333-3333-333333333332")
    assert response.status_code == 200
    tasks = response.json()
    assert isinstance(tasks, list)
    for task in tasks:
        assert task["assigned_resource_id"] == "22222222-2222-2222-2222-222222222222"

def test_tasks_elena_http():
    # Elena: 33333333-3333-3333-3333-333333333333 -> Horizon BQ-470: 22222222-2222-2222-2222-222222222224
    response = client.get("/api/tasks?resource_id=33333333-3333-3333-3333-333333333333")
    assert response.status_code == 200
    tasks = response.json()
    assert isinstance(tasks, list)
    for task in tasks:
        assert task["assigned_resource_id"] == "22222222-2222-2222-2222-222222222224"

def test_tasks_david_http():
    # David: 33333333-3333-3333-3333-333333333334 -> Epson SureColor: 22222222-2222-2222-2222-222222222225
    response = client.get("/api/tasks?resource_id=33333333-3333-3333-3333-333333333334")
    assert response.status_code == 200
    tasks = response.json()
    assert isinstance(tasks, list)
    for task in tasks:
        assert task["assigned_resource_id"] == "22222222-2222-2222-2222-222222222225"

def test_worker_machine_assignments_http():
    response = client.get("/api/worker-machine-assignments")
    assert response.status_code == 200
    mappings = response.json()
    assert isinstance(mappings, list)
