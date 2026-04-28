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


# ── Conversation Turn ─────────────────────────────────────────────────────────

async def send_conversation_turn(
    messages: list[dict],
    topic: str = "Free conversation",
    level: str = "A2",
    level_label: str = "Finding My Voice",
    current_turn: int = 1,
    grammar_focus: str = "Catch All",
    vocab_focus: str = "Occasional",
    fluency_focus: str = "After Chat",
) -> dict:
    prompt_template = (PROMPTS_DIR / "conversation-prompt.md").read_text()
    level_instructions = _LEVEL_INSTRUCTIONS.get(level.upper(), _LEVEL_INSTRUCTIONS["A2"])
    system_prompt = (
        prompt_template
        .replace("{{TOPIC}}", topic)
        .replace("{{LEVEL}}", level)
        .replace("{{LEVEL_LABEL}}", level_label)
        .replace("{{CURRENT_TURN}}", str(current_turn))
        .replace("{{LEVEL_INSTRUCTIONS}}", level_instructions)
        .replace("{{GRAMMAR_SETTING}}", grammar_focus)
        .replace("{{VOCABULARY_SETTING}}", vocab_focus)
        .replace("{{FLUENCY_SETTING}}", fluency_focus)
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

    # Parse REPLY: / CORRECTION:
    reply = reply_text
    correction = None
    reply_match = re.search(r"REPLY:\s*(.*?)(?:\nCORRECTION:|$)", reply_text, re.IGNORECASE | re.DOTALL)
    correction_match = re.search(r"CORRECTION:\s*(.*)", reply_text, re.IGNORECASE | re.DOTALL)
    if reply_match:
        reply = reply_match.group(1).strip()
    if correction_match:
        parsed = correction_match.group(1).strip()
        correction = parsed if parsed else None
    if not reply:
        reply = reply_text

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
    text = await _chat_completion(api_messages, max_tokens=300, temperature=0.7)

    # Check for REPLY: prefix — still in conversation
    reply_match = re.search(r"REPLY:\s*(.*)", text, re.IGNORECASE | re.DOTALL)
    if reply_match:
        reply = reply_match.group(1).strip()
        return {"reply": reply or text, "is_complete": False}

    # Try parsing as final JSON assessment (new adaptive prompt shape)
    try:
        json_str = _extract_json(text)
        data = json.loads(json_str)
        if "level_code" in data:
            return {
                "reply": None,
                "is_complete": True,
                "name": data.get("name"),
                "age": data.get("age"),
                "age_group": data.get("age_group"),
                "level_code": data.get("level_code"),
                "level_name": data.get("level_name"),
                "level_description": data.get("level_description"),
                "confidence": data.get("confidence"),
                "possible_higher": data.get("possible_higher"),
                "evidence_summary": data.get("evidence_summary"),
                "probe_targets_covered": data.get("probe_targets_covered"),
                "turns_taken": data.get("turns_taken"),
                "code_switch_observed": data.get("code_switch_observed"),
                "notes_for_first_session": data.get("notes_for_first_session"),
            }
    except Exception:
        pass

    # Fallback: treat as plain reply
    return {"reply": text, "is_complete": False}


# ── Session Analysis ──────────────────────────────────────────────────────────

async def analyze_session(
    messages: list[dict],
    topic: str = "Free Talk",
    level: str = "A2",
    level_label: str = "Finding My Voice",
) -> dict | None:
    template = (PROMPTS_DIR / "end-result-prompt.md").read_text()
    transcript = "\n".join(
        f"{'STUDENT' if m['role'] == 'user' else 'ZOE'}: {m['content']}"
        for m in messages
    )
    system_prompt = (
        template
        .replace("{{LEVEL}}", level)
        .replace("{{LEVEL_LABEL}}", level_label)
        .replace("{{TOPIC}}", topic)
        .replace("{{FULL_TRANSCRIPT}}", transcript)
    )
    try:
        raw = await _chat_completion(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": "Analyze the transcript and return the JSON report."},
            ],
            max_tokens=1200,
            temperature=0.4,
        )
        json_str = _extract_json(raw)
        return json.loads(json_str)
    except Exception:
        return None


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
