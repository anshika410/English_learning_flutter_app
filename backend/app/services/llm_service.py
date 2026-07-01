"""LLM proxy service — keeps API keys server-side."""
import json
import re
from pathlib import Path
import httpx
from ..core.config import get_settings

import os

# In Docker: prompts are at /app/assets/prompts (copied by Dockerfile)
# Locally: fall back to frontend/assets/prompts relative to repo root
_DOCKER_PROMPTS = Path("/app/assets/prompts")
_LOCAL_PROMPTS = Path(__file__).resolve().parent.parent.parent.parent / "frontend" / "assets" / "prompts"
PROMPTS_DIR = _DOCKER_PROMPTS if _DOCKER_PROMPTS.exists() else _LOCAL_PROMPTS

# ── Level instructions (mirrors Flutter client) ──────────────────────────────

_LEVEL_INSTRUCTIONS = {
    "A1": (
        "Accept any attempt as a valid turn. Never require full sentences. "
        "Celebrate every response.\nAsk only personal, familiar questions "
        "(family, food, daily routine, things they like).\n"
        "Speak at 40–60 wpm pace equivalent. Use only present simple and common vocabulary."
    ),
    "A2": (
        "Use salient recasts — model the correct form naturally in your reply.\n"
        "Ask about past events and simple opinions. Introduce 'Have you ever…?' questions.\n"
        "Show filler words awareness only in post-session (not during conversation)."
    ),
    "B1": (
        "Use metalinguistic nudges — name the error category and wait before correcting.\n"
        'Example: "Almost — which tense would we use for something finished in the past?"\n'
        "Push for 60-second responses by asking follow-up 'tell me more' questions.\n"
        "Offer vocabulary alternatives mid-conversation (maximum 2 per session)."
    ),
    "B2": (
        "Apply explicit correction when grammar_setting permits. State error, correct form, brief reason.\n"
        "Push for 4-part argument: claim → reason → evidence → concession.\n"
        "Flag register mismatches. Offer 2–3 precision vocabulary alternatives."
    ),
    "C1": (
        "Operate in peer mode. Suggestions, not corrections.\n"
        'Introduce stylistic options: "You could also say \'pivotal\' here — it implies a turning point."\n'
        "Expect idiomatic expression and fluent reformulation."
    ),
}


_STARTER_PROMPT = """\
You are Zoe. Write a short first message (1-2 sentences) that starts a friendly
English conversation. Keep it natural, encouraging, and age-appropriate.

After the starter, on a new line output:
TITLE: <3-4 word header for this conversation, no punctuation>
"""


# ── Shared HTTP helper ────────────────────────────────────────────────────────

async def _chat_completion(
    messages: list[dict],
    max_tokens: int = 280,
    temperature: float = 0.75,
) -> str:
    settings = get_settings()
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            f"{settings.deepseek_base_url}/chat/completions",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {settings.deepseek_api_key}",
            },
            json={
                "model": settings.deepseek_model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
        )
        resp.raise_for_status()
        data = resp.json()
        choices = data.get("choices", [])
        if not choices:
            raise ValueError("LLM returned empty choices")
        text = choices[0]["message"]["content"]
        if not text or not text.strip():
            raise ValueError("LLM returned empty content")
        return text.strip()


# ── Conversation Starter ──────────────────────────────────────────────────────

async def generate_conversation_starter(topic: str | None = None) -> dict:
    topic_line = (
        "Topic: free conversation."
        if not topic or not topic.strip()
        else f"Topic: {topic}. Start specifically with this topic."
    )
    text = await _chat_completion(
        messages=[
            {"role": "system", "content": _STARTER_PROMPT},
            {"role": "user", "content": topic_line},
        ],
        max_tokens=160,
        temperature=0.8,
    )
    title_match = re.search(r"TITLE:\s*(.+)", text, re.IGNORECASE)
    header_title = title_match.group(1).strip() if title_match else (topic or "Free Talk")
    starter = re.sub(r"TITLE:.*", "", text, flags=re.IGNORECASE).strip()
    return {"starter": starter or text.strip(), "header_title": header_title}


# ── Level blocks for the new conversation prompt ──────────────────────────────

_LEVEL_BLOCKS = {
    "A1": (
        'LEVEL: A1 (First Words). Your role: CARRIER — you carry the conversation.\n'
        '- Use very simple present-simple sentences and high-frequency words.\n'
        '- One idea per turn. Avoid stacked questions except the planned first self-introduction opener.\n'
        '- Accept fragments. A one-word answer is a success if meaning is clear.\n'
        '- After success, scaffold one small extension: one more word, one detail, or one sentence frame.\n'
        '- Use choices when stuck: "Is it big or small?" / "football or drawing?"\n'
        '- CORRECTION: none. Recast errors naturally; never name grammar rules.\n'
        '- If the learner is silent or confused, make the task smaller before changing topic.\n'
        '- ESCALATE: once the learner answers, MOVE ON to a related detail. NEVER re-ask what they already answered.'
    ),
    "A2": (
        'LEVEL: A2 (Finding My Voice). Your role: BRIDGE — help them connect ideas.\n'
        '- Use simple past and "going to" naturally in your turns so they hear the model.\n'
        '- Accept short answers but encourage "and then?" or "why?"\n'
        '- CORRECTION: recast only. Model the correct form in your reply without naming the error.\n'
        '- ESCALATE: push for one reason, one past event, or one plan after each answer.'
    ),
    "B1": (
        'LEVEL: B1 (Speaking Freely). Your role: SPACE-CREATOR — you talk less, they talk more.\n'
        '- Use natural language slightly above their level, but keep the task clear.\n'
        '- Ask open questions that invite reasons, examples, sequence, or opinion.\n'
        '- Give wait-space: do not over-explain before the learner speaks.\n'
        '- CORRECTION: nudge gently only if an error blocks meaning; otherwise recast.\n'
        '- ESCALATE: build on what they say, ask why / what happened next / what if; never re-ask; keep moving forward.\n'
        '- Encourage longer turns: "Tell me two reasons" or "Give me one example."'
    ),
    "B2": (
        'LEVEL: B2 (Almost Fluent). Your role: CHALLENGER — push for precision and argument.\n'
        '- Expect connected discourse. Push for claim + reason + evidence.\n'
        '- CORRECTION: explicit when it blocks meaning; otherwise note and move on.\n'
        '- ESCALATE: ask for counterarguments, nuance, register shifts.'
    ),
    "C1": (
        'LEVEL: C1 (Fluent). Your role: PEER — equal conversation partner.\n'
        '- Operate in peer mode. Suggestions, not corrections.\n'
        '- Introduce stylistic options and expect idiomatic expression.\n'
        '- ESCALATE: challenge ideas, introduce complexity, expect sustained discourse.'
    ),
}


# ── Conversation Turn ─────────────────────────────────────────────────────────

async def send_conversation_turn(
    messages: list[dict],
    topic: str = "Free conversation",
    level: str = "A2",
    level_label: str = "Finding My Voice",
    current_turn: int = 1,
    persona_memory: dict | None = None,
    due_next: dict | None = None,
    skills_progress: dict | None = None,
) -> dict:
    from ..core.curriculum_data import (
        UNITS, UNIT_SKILLS, LEVEL_TOPICS, get_skill_text, plan_text, active_step, targets_list_for
    )

    # Format persona memory
    memory_str = "None"
    if persona_memory:
        facts = persona_memory.get("facts", [])
        if not isinstance(facts, list):
            facts = [facts] if facts else []
        if not facts and isinstance(persona_memory, dict):
            for k, v in persona_memory.items():
                if isinstance(v, list):
                    facts.extend([str(item) for item in v])
                elif isinstance(v, str):
                    facts.append(f"{k}: {v}")
        if facts:
            memory_str = "\n".join(f"- {fact}" for fact in facts)

    level_upper = level.upper() if level else "A1"

    # Get aimed IDs
    primary_id = due_next.get("primary") if due_next else None
    watching_ids = due_next.get("watching", []) if due_next else []
    
    target_ids = []
    if primary_id:
        target_ids.append(primary_id)
    if watching_ids:
        for wid in watching_ids:
            if wid not in target_ids:
                target_ids.append(wid)
                
    if not target_ids:
        # Fallback to computing targets on the fly
        target_ids = targets_list_for(skills_progress or {}, "unit", level_upper)

    # Get active unit name & focus
    active_unit = active_step(skills_progress or {}, level_upper)
    if active_unit:
        unit_name = active_unit.get("name", topic) or topic
        unit_focus = active_unit.get("focus", "General conversation practice")
    else:
        unit_name = topic
        unit_focus = "General conversation practice"

    # Build targets list text showing IDs and descriptions
    if target_ids:
        targets_str = "\n".join(f"- [{sid}] {get_skill_text(sid, level_upper)}" for sid in target_ids)
    else:
        targets_str = "- General conversation practice"

    # Build elicitation plan (using plan_text(target_ids))
    elicitation_str = plan_text(target_ids, level_upper)

    # Get level block
    level_block = _LEVEL_BLOCKS.get(level_upper, _LEVEL_BLOCKS["A2"])

    prompt_template = (PROMPTS_DIR / "conversation-prompt.md").read_text()
    system_prompt = (
        prompt_template
        .replace("{{LEVEL_BLOCK}}", level_block)
        .replace("{{UNITNAME}}", unit_name)
        .replace("{{UNITFOCUS}}", unit_focus)
        .replace("{{TARGETS}}", targets_str)
        .replace("{{ELICITATION}}", elicitation_str)
        .replace("{{STUDENT_MEMORY}}", memory_str)
        .replace("{{CURRENT_TURN}}", str(current_turn))
    )

    api_messages = [{"role": "system", "content": system_prompt}] + [
        {"role": m["role"], "content": m["content"]} for m in messages
    ]
    response = await _chat_completion(api_messages, max_tokens=280, temperature=0.75)

    # Check for conversation_complete signal
    complete = False
    reply_text = response
    json_match = re.search(r'\{[^}]*"conversation_complete"\s*:\s*true[^}]*\}', response)
    if json_match:
        complete = True
        reply_text = response[: json_match.start()].strip()

    # Parse reply (no REPLY: prefix needed with new prompt)
    reply = reply_text.strip()
    correction = None

    return {"reply": reply, "correction": correction, "conversation_complete": complete}


# ── Placement Turn ────────────────────────────────────────────────────────────

async def send_placement_turn(
    messages: list[dict],
    name: str | None = None,
    age: int | None = None,
) -> dict:
    raw_prompt = (PROMPTS_DIR / "placement-check-prompt.md").read_text()
    # Inject student name and age into the prompt
    system_prompt = (
        raw_prompt
        .replace("{{NAME}}", name or "there")
        .replace("{{AGE}}", str(age) if age is not None else "unknown")
    )
    api_messages = [{"role": "system", "content": system_prompt}] + [
        {"role": "user" if m["role"] == "user" else "assistant", "content": m["content"]}
        for m in messages
    ]
    text = await _chat_completion(api_messages, max_tokens=600, temperature=0.7)

    # Check for REPLY: prefix — still in conversation
    reply_match = re.search(r"REPLY:\s*(.*)", text, re.IGNORECASE | re.DOTALL)
    if reply_match:
        reply = reply_match.group(1).strip()
        return {"reply": reply or text, "is_complete": False}

    # Try parsing as final JSON assessment (new adaptive prompt shape)
    try:
        json_str = _extract_json(text)
        data = json.loads(json_str)
        if "level" in data or "level_code" in data:
            import logging
            logging.info(f"Placement JSON interests: {data.get('interests')}")
            return {
                "reply": None,
                "is_complete": True,
                "name": data.get("name"),
                "age": data.get("age"),
                "age_group": data.get("age_group"),
                "level": data.get("level") or data.get("level_code"),
                "level_name": data.get("level_name"),
                "level_description": data.get("level_description"),
                "confidence": data.get("confidence"),
                "possible_higher": data.get("possible_higher"),
                "evidence_summary": data.get("evidence_summary"),
                "probe_targets_covered": data.get("probe_targets_covered"),
                "turns_taken": data.get("turns_taken"),
                "code_switch_observed": data.get("code_switch_observed"),
                "interests": data.get("interests", []),
                "notes_for_first_session": data.get("notes_for_first_session"),
            }
    except Exception:
        pass

    # Fallback: treat as plain reply
    return {"reply": text, "is_complete": False}


# ── Session Analysis ──────────────────────────────────────────────────────────

async def analyze_and_grade_session(
    messages: list[dict],
    topic: str = "Free Talk",
    level: str = "A2",
    level_label: str = "Finding My Voice",
    target_skill_ids: list[str] = [],
) -> dict:
    from ..core.curriculum_data import get_skill_text

    template = (PROMPTS_DIR / "end-result-prompt.md").read_text()
    transcript = "\n".join(
        f"{'STUDENT' if m['role'] == 'user' else 'ZOE'}: {m['content']}"
        for m in messages
    )
    
    # Format target skills list
    if target_skill_ids:
        id_list = "\n".join(f"- {sid}: {get_skill_text(sid, level)}" for sid in target_skill_ids)
    else:
        id_list = "None"

    system_prompt = (
        template
        .replace("{{LEVEL}}", level)
        .replace("{{LEVEL_LABEL}}", level_label)
        .replace("{{TOPIC}}", topic)
        .replace("{{TARGET_SKILLS}}", id_list)
        .replace("{{FULL_TRANSCRIPT}}", transcript)
    )
    
    try:
        raw = await _chat_completion(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": "Analyze the transcript, extract facts, grade targeted skills, and return the combined JSON report."},
            ],
            max_tokens=1500,
            temperature=0.4,
        )
        json_str = _extract_json(raw)
        data = json.loads(json_str)
        if "scores" not in data:
            data["scores"] = []
        return data
    except Exception as e:
        import logging
        logging.error(f"Combined analysis/grading LLM call failed: {e}")
        return {
            "overall": "okay",
            "best_moment": {"quote": "", "note": "Failed to analyze conversation"},
            "courage_or_motivation": {"type": "motivation", "content": "Keep trying!"},
            "try_next_time": {"skill": "", "example": ""},
            "extracted_memory_facts": [],
            "transcript_notes": [],
            "scores": [
                {
                    "id": sid,
                    "confidence": 0.0,
                    "prompted": False,
                    "evidence": "",
                }
                for sid in target_skill_ids
            ]
        }


async def analyze_session(
    messages: list[dict],
    topic: str = "Free Talk",
    level: str = "A2",
    level_label: str = "Finding My Voice",
) -> dict | None:
    # Legacy wrapper
    res = await analyze_and_grade_session(messages, topic, level, level_label, [])
    return res


async def grade_skills(
    messages: list[dict],
    level: str,
    target_skill_ids: list[str],
) -> list[dict]:
    # Legacy wrapper
    res = await analyze_and_grade_session(messages, "Free Talk", level, "Finding My Voice", target_skill_ids)
    return res.get("scores", [])


# ── JSON extraction helper ────────────────────────────────────────────────────

def _extract_json(text: str) -> str:
    trimmed = text.strip()
    if trimmed.startswith("{") and trimmed.endswith("}"):
        return trimmed
    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", trimmed)
    if fenced:
        candidate = fenced.group(1).strip()
        if candidate.startswith("{") and candidate.endswith("}"):
            return candidate
    start = trimmed.find("{")
    end = trimmed.rfind("}")
    if start >= 0 and end > start:
        return trimmed[start : end + 1]
    raise ValueError("Could not extract JSON from LLM output")
