import os
import sys
import json
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.main import app

def test_placement_v2_endpoints_live():
    client = TestClient(app)

    # 1. Anonymous Auth
    print("1. Authenticating test client...")
    auth_resp = client.post("/auth/anonymous", json={"device_id": "test-device-placement-v2"})
    assert auth_resp.status_code == 200, f"Auth failed: {auth_resp.text}"
    token = auth_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("   ✓ Authenticated successfully")

    # 2. Test Turn 0 (0 user messages)
    print("2. Testing Turn 0 on /api/v2/llm/placement-turn...")
    t0_resp = client.post(
        "/v2/llm/placement-turn",
        headers=headers,
        json={
            "name": "Narendra",
            "age": 12,
            "self_reported_level": "I can have short conversations",
            "messages": []
        }
    )
    assert t0_resp.status_code == 200, f"Turn 0 failed: {t0_resp.text}"
    t0_data = t0_resp.json()
    assert t0_data["is_complete"] is False
    assert "improve" in t0_data["reply"].lower()
    print("   ✓ Turn 0 returned first prompt:", t0_data["reply"])

    # 3. Test Turn 1 (1 user message)
    print("3. Testing Turn 1 on /api/llm/v2/placement-turn...")
    t1_resp = client.post(
        "/llm/v2/placement-turn",
        headers=headers,
        json={
            "name": "Narendra",
            "age": 12,
            "self_reported_level": "I can have short conversations",
            "messages": [
                {"role": "assistant", "content": "What do you want to improve in your English?"},
                {"role": "user", "content": "I want to improve my speaking confidence and vocabulary."}
            ]
        }
    )
    assert t1_resp.status_code == 200, f"Turn 1 failed: {t1_resp.text}"
    t1_data = t1_resp.json()
    assert t1_data["is_complete"] is False
    assert "yourself" in t1_data["reply"].lower()
    print("   ✓ Turn 1 returned second prompt:", t1_data["reply"])

    # 4. Test Turn 2 (2 user messages -> Evaluation)
    print("4. Testing Turn 2 (Evaluation) on /api/v2/llm/placement-turn...")
    t2_resp = client.post(
        "/v2/llm/placement-turn",
        headers=headers,
        json={
            "name": "Narendra",
            "age": 12,
            "self_reported_level": "I can have short conversations",
            "messages": [
                {"role": "assistant", "content": "What do you want to improve in your English?"},
                {"role": "user", "content": "I want to improve my speaking confidence and vocabulary."},
                {"role": "assistant", "content": "Tell me something about yourself?"},
                {"role": "user", "content": "I am Narendra. I am twelve years old and I love playing cricket and reading story books with my friends."}
            ]
        }
    )
    assert t2_resp.status_code == 200, f"Turn 2 evaluation failed: {t2_resp.text}"
    t2_data = t2_resp.json()
    assert t2_data["is_complete"] is True
    assert t2_data["level"] is not None
    assert t2_data["unit_name"] is not None
    assert t2_data["level_number"] is not None
    print(f"   ✓ Evaluation Complete:")
    print(f"     - Level: {t2_data['level']} (Level {t2_data['level_number']})")
    print(f"     - Unit: {t2_data['unit_name']}")
    print(f"     - Description: {t2_data['level_description']}")
    print(f"     - Recap: {t2_data['zoe_recap']}")
    print(f"     - Interests: {t2_data['interests']}")

    # 5. Check User Profile and Placement in DB
    print("5. Checking database records...")
    me_resp = client.get("/users/me", headers=headers)
    assert me_resp.status_code == 200, f"Get /users/me failed: {me_resp.text}"
    me_data = me_resp.json()
    assert me_data["level"] == t2_data["level"]
    print(f"   ✓ User profile level updated to: {me_data['level']}")

    latest_p_resp = client.get("/placements/latest", headers=headers)
    assert latest_p_resp.status_code == 200, f"Get /placements/latest failed: {latest_p_resp.text}"
    latest_p = latest_p_resp.json()
    assert latest_p["level"] == t2_data["level"]
    print(f"   ✓ Placements history record verified: {latest_p['id']} ({latest_p['level']})")

    print("\n🎉 ALL LIVE ENDPOINT VERIFICATION CHECKS PASSED!")

if __name__ == "__main__":
    test_placement_v2_endpoints_live()
