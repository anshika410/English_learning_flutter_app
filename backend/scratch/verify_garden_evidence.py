import httpx
import json

BASE_URL = "https://ella.navgurukul.org/api"

def test_garden_evidence():
    # 1. Auth test user
    device_id = "prod-test-device-999"
    r = httpx.post(f"{BASE_URL}/auth/anonymous", json={"device_id": device_id})
    r.raise_for_status()
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # Reset progression of the user to make sure we start fresh
    httpx.put(f"{BASE_URL}/users/me/memory", headers=headers, json={
        "persona_memory": {},
        "skills_progress": {
            "owned": [],
            "emerging": [],
            "sightings": {},
            "strength": {},
            "evidence": {}
        }
    })
    
    # 2. Create session
    r = httpx.post(f"{BASE_URL}/session", headers=headers, json={"topic": "My Yesterday"})
    r.raise_for_status()
    session_id = r.json()["session_id"]
    print(f"Created session: {session_id}")
    
    user_msg = "Yesterday, I played cricket. Then last week, I went to Delhi. A long time ago, I lived in Mumbai."
    
    # 3. Send message matching past simple & vocabulary targets
    r = httpx.post(
        f"{BASE_URL}/session/{session_id}/turn",
        headers=headers,
        json={"content": user_msg}
    )
    r.raise_for_status()
    print("Sent message to Zoe.")
    
    # 4. Trigger judge
    r = httpx.post(
        f"{BASE_URL}/llm/judge",
        headers=headers,
        json={
            "session_id": session_id,
            "messages": [
                {"role": "user", "content": user_msg}
            ],
            "topic": "My Yesterday",
            "progression_model": "unit",
            "level": "A1",
            "unit_label": "First Words"
        },
        timeout=60.0
    )
    r.raise_for_status()
    print("Judge completed.")
    
    # 5. Fetch Garden status
    r = httpx.get(f"{BASE_URL}/users/me/garden", headers=headers)
    r.raise_for_status()
    garden = r.json()
    
    # Find skills in steps that have evidence
    found_skills = []
    for step in garden["steps"]:
        for skill in step["skills"]:
            if len(skill.get("evidence", [])) > 0:
                found_skills.append(skill)
                
    print("\nSkills with evidence in production /users/me/garden response:")
    print(json.dumps(found_skills, indent=2))

if __name__ == "__main__":
    test_garden_evidence()
