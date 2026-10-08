from fastapi.testclient import TestClient

from app.main import app


def test_health_and_quiz_flow():
    with TestClient(app) as client:
        assert client.get("/api/healthz").status_code == 200
        questions = client.get("/api/questions").json()
        assert len(questions) == 20
        assert "correct_index" not in questions[0]
        answers = [{"question_id": q["id"], "selected_index": 0} for q in questions]
        response = client.post("/api/quiz/submit", json={"answers": answers})
        assert response.status_code == 200
        body = response.json()
        assert body["total"] == 20
        assert len(body["results"]) == 20


def test_admin_crud_is_public():
    payload = {
        "prompt": "What is 2 + 2?",
        "options": ["2", "3", "4", "5"],
        "correct_index": 2,
        "explanation": "Two plus two equals four.",
        "category": "science",
        "difficulty": "easy",
    }
    with TestClient(app) as client:
        assert client.get("/api/admin/questions").status_code == 200
        created = client.post("/api/admin/questions", json=payload)
        assert created.status_code == 201
        qid = created.json()["id"]
        payload["prompt"] = "What is 1 + 3?"
        assert client.put(f"/api/admin/questions/{qid}", json=payload).status_code == 200
        assert client.delete(f"/api/admin/questions/{qid}").status_code == 204
