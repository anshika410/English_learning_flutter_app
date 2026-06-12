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
        cursor.execute("DELETE FROM users WHERE device_id = 'test-device-uuid-123456'")
        conn.commit()
        conn.close()
        print("Reset test user database records.")

    client = TestClient(app)
    
    # 1. Signup / Authentication
    print("Testing anonymous auth...")
    auth_resp = client.post("/auth/anonymous", json={"device_id": "test-device-uuid-123456"})
    assert auth_resp.status_code == 200, f"Auth failed: {auth_resp.text}"
    token_data = auth_resp.json()
    token = token_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✓ Auth successful")

    # 2. Get Curriculum Topics
    print("Testing GET /curriculum/topics...")
    topics_resp = client.get("/curriculum/topics", headers=headers)
    assert topics_resp.status_code == 200, f"Curriculum failed: {topics_resp.text}"
    topics = topics_resp.json()
    assert len(topics) == 11, f"Expected 11 topics, got {len(topics)}"
    assert topics[0]["id"] == "my_name_and_where_i_m_from", f"Expected my_name_and_where_i_m_from, got {topics[0]['id']}"
    print("✓ GET /curriculum/topics successful")


    # 3. Get Initial Memory
    print("Testing GET /users/me/memory (initial)...")
    mem_resp = client.get("/users/me/memory", headers=headers)
    assert mem_resp.status_code == 200, f"Get memory failed: {mem_resp.text}"
    mem_data = mem_resp.json()
    # Default is empty in database
    import sqlite3
    db_path = os.path.join(os.path.dirname(__file__), "zoe.db")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT persona_memory FROM users WHERE device_id = 'test-device-uuid-123456'")
    row = cursor.fetchone()
    conn.close()
    assert row is not None
    db_mem = json.loads(row[0]) if row[0] else {}
    assert not db_mem.get("facts"), f"Expected empty facts, got {db_mem}"
    print("✓ GET /users/me/memory (initial) successful")

    # 4. Put Memory (Manual update)
    print("Testing PUT /users/me/memory...")
    put_resp = client.put(
        "/users/me/memory",
        headers=headers,
        json={"persona_memory": {"facts": ["Likes playing cricket", "Has a pet dog named Max"]}}
    )
    assert put_resp.status_code == 200, f"Put memory failed: {put_resp.text}"
    assert put_resp.json()["persona_memory"]["facts"] == ["Likes playing cricket", "Has a pet dog named Max"]
    print("✓ PUT /users/me/memory successful")

    # Verify memory in DB matches PUT
    print("Testing memory facts in database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT persona_memory FROM users WHERE device_id = 'test-device-uuid-123456'")
    row = cursor.fetchone()
    conn.close()
    assert row is not None
    db_mem = json.loads(row[0])
    assert db_mem.get("facts") == ["Likes playing cricket", "Has a pet dog named Max"]
    print("✓ GET /users/me/memory (after PUT) successful")


    # Create a test conversation to associate analysis and turns
    print("Creating a test conversation...")
    conv_resp = client.post("/conversations", headers=headers, json={"topic": "Cricket"})
    assert conv_resp.status_code == 200, f"Create conversation failed: {conv_resp.text}"
    conv_data = conv_resp.json()
    conversation_id = conv_data["id"]
    print(f"✓ Conversation created: {conversation_id}")

    # 5. Conversation Turn with Memory Injection
    print("Testing POST /conversations/{id}/turn with memory injection...")
    mock_turn_response = "That is cool! Zoe loves cricket too."
    
    with patch("app.services.llm_service._chat_completion", new_callable=AsyncMock) as mock_completion:
        mock_completion.return_value = mock_turn_response
        
        turn_resp = client.post(
            f"/conversations/{conversation_id}/turn",
            headers=headers,
            json={
                "content": "I like playing cricket."
            }
        )
        assert turn_resp.status_code == 200, f"Conversation turn failed: {turn_resp.text}"
        
        # Verify the mock completion was called and system prompt contained memory facts
        called_args = mock_completion.call_args[0][0]
        system_prompt = next(msg["content"] for msg in called_args if msg["role"] == "system")
        
        assert "STUDENT MEMORY" in system_prompt, "System prompt missing STUDENT MEMORY header"
        assert "- Likes playing cricket" in system_prompt, "Memory facts not injected correctly"
        assert "- Has a pet dog named Max" in system_prompt, "Memory facts not injected correctly"
        
        turn_data = turn_resp.json()
        assert turn_data["zoe_message"]["content"] == "That is cool! Zoe loves cricket too."
        assert turn_data["zoe_message"]["correction"] is None
        assert turn_data["conversation_complete"] is False
        assert turn_data["user_message"]["content"] == "I like playing cricket."
    print("✓ POST /conversations/{id}/turn memory injection successful")

    # 6. Session Analysis with Memory Extraction and Merging
    print("Testing POST /llm/judge memory extraction...")
    mock_analysis_json = json.dumps({
        "overall": "good",
        "best_moment": {
            "quote": "I like playing cricket.",
            "note": "Expressed interest in sports."
        },
        "courage_or_motivation": {
            "type": "moment_of_courage",
            "content": "Talked confidently about cricket."
        },
        "try_next_time": {
            "skill": "use complex sentences",
            "example": "I like cricket because it is fun."
        },
        "extracted_memory_facts": [
            "Has a pet dog named Max",  # Duplicate fact
            "Likes eating mangoes"      # New fact
        ],
        "transcript_notes": []
    })

    with patch("app.services.llm_service._chat_completion", new_callable=AsyncMock) as mock_completion:
        mock_completion.return_value = mock_analysis_json
        
        analysis_resp = client.post(
            "/llm/judge",
            headers=headers,
            json={
                "conversation_id": conversation_id,
                "messages": [
                    {"role": "user", "content": "I like playing cricket."}
                ],
                "topic": "Cricket"
            }
        )
        assert analysis_resp.status_code == 200, f"Analysis failed: {analysis_resp.text}"
        analysis_data = analysis_resp.json()
        print("Analysis response JSON:", analysis_data)
        assert analysis_data["overall"] == "good"
        assert "extracted_memory_facts" in analysis_data
        
    print("✓ POST /llm/judge successful")

    # Verify that the new fact was merged and the duplicate was not added twice
    print("Verifying memory was merged correctly in database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT persona_memory FROM users WHERE device_id = 'test-device-uuid-123456'")
    row = cursor.fetchone()
    conn.close()
    assert row is not None
    db_mem = json.loads(row[0])
    merged_facts = db_mem.get("facts", [])
    print("Merged facts list:", merged_facts)
    
    assert "Likes playing cricket" in merged_facts
    assert "Has a pet dog named Max" in merged_facts
    assert "Likes eating mangoes" in merged_facts
    assert len(merged_facts) == 3, f"Expected exactly 3 facts, got: {merged_facts}"
    print("✓ Memory merged and saved successfully without duplicates")

    # 7. Get Conversation Analysis (Retrieval Endpoint)
    print("Testing GET /conversations/{id}/analysis...")
    ret_resp = client.get(f"/conversations/{conversation_id}/analysis", headers=headers)
    assert ret_resp.status_code == 200, f"Retrieving analysis failed: {ret_resp.text}"
    ret_data = ret_resp.json()
    assert ret_data["overall"] == "good"
    assert ret_data["best_moment"]["quote"] == "I like playing cricket."
    assert ret_data["try_next_time"]["skill"] == "use complex sentences"
    print("✓ GET /conversations/{id}/analysis successful")

    print("\n=================================")
    print("ALL API INTEGRATION TESTS PASSED!")
    print("=================================")

if __name__ == "__main__":
    run_tests()
