import sys
import os
import json
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

# Ensure app is importable from path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.main import app
from app.core.database import get_db

def run_tests():
    # Reset test user at start
    import sqlite3
    db_path = os.path.join(os.path.dirname(__file__), "zoe.db")
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users WHERE device_id = 'test-device-uuid-987654'")
        conn.commit()
        conn.close()
        print("Reset test user database records.")

    client = TestClient(app)
    
    # 1. Signup / Authentication
    print("Testing anonymous auth...")
    auth_resp = client.post("/auth/anonymous", json={"device_id": "test-device-uuid-987654"})
    assert auth_resp.status_code == 200, f"Auth failed: {auth_resp.text}"
    token_data = auth_resp.json()
    token = token_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✓ Auth successful")

    # Verify initial memory structure includes skills_progress
    print("Testing initial GET /users/me/memory...")
    mem_resp = client.get("/users/me/memory", headers=headers)
    assert mem_resp.status_code == 200
    mem_data = mem_resp.json()
    assert "persona_memory" in mem_data
    assert "skills_progress" in mem_data
    print("✓ Initial memory schema contains both persona_memory and skills_progress")

    # Create a test conversation
    print("Creating a test conversation...")
    conv_resp = client.post("/conversations", headers=headers, json={"topic": "Cricket"})
    assert conv_resp.status_code == 200, f"Create conversation failed: {conv_resp.text}"
    conv_data = conv_resp.json()
    conversation_id = conv_data["id"]
    print(f"✓ Conversation created: {conversation_id}")

    # Mock responses for qualitative analysis and quantitative grading
    mock_analysis_json = json.dumps({
        "overall": "excellent",
        "best_moment": {
            "quote": "I see... me in space! No pizza. Only stars.",
            "note": "Shared creative description of space."
        },
        "courage_or_motivation": {
            "type": "moment_of_courage",
            "content": "Tried their best to describe space."
        },
        "try_next_time": {
            "skill": "use present continuous",
            "example": "I am looking at stars."
        },
        "extracted_memory_facts": [
            "Likes watching space shows",
            "Wants to study stars"
        ],
        "transcript_notes": []
    })

    # We expect aimed target U1-VOC-01 to be graded with 0.8, U1-GRA-01 with 0.4
    mock_grading_json = json.dumps({
        "scores": [
            {
                "id": "U1-VOC-01",
                "confidence": 0.8,
                "prompted": False,
                "evidence": "I see... me in space! No pizza. Only stars."
            },
            {
                "id": "U1-GRA-01",
                "confidence": 0.4,
                "prompted": False,
                "evidence": "I see... me in space."
            },
            {
                "id": "U1-FLU-01",
                "confidence": 0.1,
                "prompted": False,
                "evidence": ""
            }
        ]
    })

    print("Testing POST /llm/session-analysis in unit mode...")
    with patch("app.services.llm_service._chat_completion", new_callable=AsyncMock) as mock_completion:
        # Side effect: first call is qualitative analysis, second call is quantitative grading
        mock_completion.side_effect = [mock_analysis_json, mock_grading_json]
        
        analysis_resp = client.post(
            "/llm/session-analysis",
            headers=headers,
            json={
                "conversation_id": conversation_id,
                "messages": [
                    {"role": "user", "content": "I see... me in space! No pizza. Only stars."}
                ],
                "topic": "Cricket",
                "progression_model": "unit",
                "level": "A1",
                "level_label": "First Words"
            }
        )
        assert analysis_resp.status_code == 200, f"Analysis failed: {analysis_resp.text}"
        data = analysis_resp.json()
        
        print("Analysis response keys:", list(data.keys()))
        assert data["overall"] == "excellent"
        
        # Verify grading details are returned in payload
        assert "aimed_at" in data
        assert "hit_targets" in data
        assert "skills_evidenced" in data
        assert "state_changes" in data
        
        assert "U1-VOC-01" in data["aimed_at"]
        assert "U1-VOC-01" in data["hit_targets"] # because confidence 0.8 >= 0.3
        
        # Verify that U1-VOC-01 moved from locked to emerging/owned
        changes = data["state_changes"]
        print("State changes:", changes)
        assert len(changes) >= 1
        assert any(c["id"] == "U1-VOC-01" and c["to"] == "emerging" for c in changes)

    print("✓ POST /llm/session-analysis successfully updated student grading & progression")

    # Verify that the user's progress and next targets are now saved in DB
    print("Verifying user progress and targets in database...")
    mem_resp2 = client.get("/users/me/memory", headers=headers)
    assert mem_resp2.status_code == 200
    mem_data2 = mem_resp2.json()
    
    progress = mem_data2["skills_progress"]
    print("Skills progress emerging:", progress.get("emerging"))
    print("Skills progress owned:", progress.get("owned"))
    
    assert "U1-VOC-01" in progress.get("emerging")
    assert "U1-GRA-01" in progress.get("emerging")
    
    # Check that due_next was calculated on backend and is returned in user profile
    print("Verifying user profile contains updated due_next...")
    profile_resp = client.get("/users/me", headers=headers)
    assert profile_resp.status_code == 200
    profile_data = profile_resp.json()
    print("Profile due_next:", profile_data.get("due_next"))
    assert profile_data.get("due_next") is not None
    assert "primary" in profile_data["due_next"]
    
    print("✓ User progress and targets saved successfully")

    # Verify retrieve session analysis includes the new JSON fields
    print("Testing GET /conversations/{id}/analysis...")
    ret_resp = client.get(f"/conversations/{conversation_id}/analysis", headers=headers)
    assert ret_resp.status_code == 200, f"Retrieving analysis failed: {ret_resp.text}"
    ret_data = ret_resp.json()
    
    assert "aimed_at" in ret_data
    assert "hit_targets" in ret_data
    assert "skills_evidenced" in ret_data
    assert "state_changes" in ret_data
    
    assert ret_data["overall"] == "excellent"
    assert ret_data["aimed_at"] == data["aimed_at"]
    assert ret_data["hit_targets"] == data["hit_targets"]
    assert len(ret_data["skills_evidenced"]) == 3
    print("✓ GET /conversations/{id}/analysis returned grading checklist fields successfully")

    print("\n==========================================")
    print("ALL GRADING & PROGRESSION TESTS PASSED!")
    print("==========================================")

if __name__ == "__main__":
    run_tests()
