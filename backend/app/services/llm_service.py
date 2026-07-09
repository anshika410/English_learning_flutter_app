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
    "A0": (
        "Accept any attempt as a valid turn. Never require full sentences. "
        "Celebrate every response.\nAsk only personal, familiar questions "
        "(family, food, daily routine, things they like).\n"
        "Speak at 40–60 wpm pace equivalent. Use only present simple and common vocabulary."
    ),
    "A1": (
        "Use salient recasts — model the correct form naturally in your reply.\n"
        "Ask about past events and simple opinions. Introduce 'Have you ever…?' questions.\n"
        "Show filler words awareness only in post-session (not during conversation)."
    ),
    "A2": (
        "Use metalinguistic nudges — name the error category and wait before correcting.\n"
        'Example: "Almost — which tense would we use for something finished in the past?"\n'
        "Push for 60-second responses by asking follow-up 'tell me more' questions.\n"
        "Offer vocabulary alternatives mid-conversation (maximum 2 per session)."
    ),
    "B1": (
        "Apply explicit correction when grammar_setting permits. State error, correct form, brief reason.\n"
        "Push for 4-part argument: claim → reason → evidence → concession.\n"
        "Flag register mismatches. Offer 2–3 precision vocabulary alternatives."
    ),
    "B2": (
        "Operate in peer mode. Suggestions, not corrections.\n"
        'Introduce stylistic options: "You could also say \'pivotal\' here — it implies a turning point."\n'
        "Expect idiomatic expression and fluent reformulation."
    ),
    "C1": (
        "Operate in advanced peer mode. Encourage stylistic variation, complex idioms, "
        "and sophisticated debate registers. Address registry slips and prompt for higher refinement."
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
    async with httpx.AsyncClient(timeout=60.0) as client:
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


# ── Correction Highlight Extraction (separate focused call) ───────────────────

async def extract_correction_highlight(messages: list[dict]) -> dict | None:
    """
    Separate LLM call that finds the single best grammar/vocab error in the
    student's speech and returns a before/after correction pair.
    """
    transcript = "\n".join(
        f"{'STUDENT' if m['role'] == 'user' else 'ZOE'}: {m['content']}"
        for m in messages
    )

    prompt = f"""Look at this conversation transcript between a student and their English tutor Zoe.

TRANSCRIPT:
{transcript}

Find ONE grammar or vocabulary error the student made. Return ONLY valid JSON:

{{
  "student_said": "<COPY the student's exact words that contain the error — must be from the transcript above>",
  "corrected": "<the corrected version>",
  "highlight_word": "<the 1-2 key words that changed>"
}}

RULES:
- student_said MUST be copied exactly from the STUDENT lines above. Example: "my mother make daal chawal"
- student_said must NOT be a description or tip. WRONG: "using past tense". RIGHT: "I no play good"
- corrected is the fixed version. Example: "my mother makes daal chawal"
- highlight_word is what changed. Example: "makes"
- If the student made no errors at all, return: null

Return ONLY the JSON object or null. No explanation."""

    try:
        raw = await _chat_completion(
            messages=[{"role": "user", "content": prompt}],
            max_tokens=200,
            temperature=0.2,
        )
        json_str = _extract_json(raw)
        if not json_str or json_str.strip().lower() == "null":
            return None
        data = json.loads(json_str)
        # Validate it's a real quote, not a tip
        if data and data.get("student_said"):
            said = data["student_said"].lower()
            # Reject if it looks like a tip instead of a quote
            tip_words = ["using", "adding", "try to", "practice", "remember to"]
            if any(said.startswith(w) for w in tip_words):
                return None
            return data
        return None
    except Exception:
        return None


# ── Conversation Starter ──────────────────────────────────────────────────────

async def generate_conversation_starter(
    topic: str | None = None, starters: list[str] | None = None
) -> dict:
    topic_line = (
        "Topic: free conversation."
        if not topic or not topic.strip()
        else f"Topic: {topic}. Start specifically with this topic."
    )
    if starters:
        starters_str = ", ".join([f'"{s}"' for s in starters])
        topic_line += f"\nHere are some sample questions you can use to start the conversation: {starters_str}. Try to ask one of them naturally."

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
    "A0": (
        'LEVEL: A0 (Before First Words). Your role: ECHO-BUILDER — you speak, they copy, and copying counts as speaking.\n'
        '- Length: 3–6 words per sentence. One sentence, then one tiny ask.\n'
        '- The learner may know fewer than 50 English words. Assume zero grammar.\n'
        '- Repetition IS the activity. "Say it with me: I am Priya" is a full success.\n'
        '- Use their name constantly. Only yes/no and this-or-that questions.\n'
        '- Accept Hindi answers fully. Reply with the English word: "Kutta! In English we say DOG. Can you say dog?"\n'
        '- Celebrate every English word they produce. One spoken word = a win worth naming.\n'
        '- Never ask open questions. Never ask "why". Never two ideas in one turn.\n'
        '- If their reply is empty or off-track: playfully answer your own question, then ask again, even smaller.'
    ),
    "A1": (
        'LEVEL: A1 (First Words). Your role: CARRIER — you carry the conversation.\n'
        '- Length: 8–18 words per turn.\n'
        '- Very simple present-simple sentences and high-frequency words. One idea per turn.\n'
        '- Accept fragments. A one-word answer is a success if meaning is clear.\n'
        '- After success, scaffold one small extension: one more word, one detail, or one sentence frame.\n'
        "- If a question doesn't land, shrink it into a this-or-that choice: \"Is it big or small?\"\n"
        '- CORRECTION: none. Recast errors naturally; never name grammar rules.\n'
        '- ESCALATE: once the learner answers, MOVE ON to a related detail. NEVER re-ask what they already answered.'
    ),
    "A2": (
        'LEVEL: A2 (Getting Going). Your role: BRIDGE-BUILDER — you turn their fragments into real conversation.\n'
        '- Length: 10–22 words per turn.\n'
        '- Simple open questions are now allowed: "What did you do?" / "Why do you like it?"\n'
        '- Invite "because", "but", "and then" by using them yourself first.\n'
        '- CORRECTION: recast, and occasionally echo the fixed version once: "Ah, you WENT to the market! Nice."\n'
        '- Expect 2–3 sentence answers. If they give one word, ask for one more.\n'
        '- ESCALATE: follow their story forward in time or sideways into feelings. Never loop back.'
    ),
    "B1": (
        'LEVEL: B1 (Speaking Freely). Your role: SPACE-CREATOR — you talk less, they talk more.\n'
        '- Length: 12–35 words per turn.\n'
        '- Natural language slightly above their level, but keep the task clear.\n'
        '- Open questions that invite reasons, examples, sequence, or opinion.\n'
        '- Ask, then stop. Do not over-explain before the learner speaks.\n'
        '- CORRECTION: nudge gently only if an error blocks meaning; otherwise recast.\n'
        '- Encourage longer turns: "Tell me two reasons" or "Give me one example."\n'
        '- ESCALATE: build on what they say — why / what happened next / what if. Never re-ask.'
    ),
    "B2": (
        'LEVEL: B2 (Holding My Own). Your role: SPARRING PARTNER — you give them something to push against.\n'
        '- Length: 15–40 words per turn.\n'
        '- Take positions. Disagree playfully. Ask them to defend, compare, counter-argue.\n'
        '- Introduce precise vocabulary naturally and reuse their best words back at them.\n'
        '- CORRECTION: recast in flow; if the same error repeats, name the pattern once, lightly, then drop it.\n'
        '- Invite register shifts: "How would you say that to a teacher? And to your best friend?"\n'
        '- ESCALATE: complicate the question — add a trade-off, an exception, a "but what about..."'
    ),
    "C1": (
        'LEVEL: C1/C2 (Mastery). Your role: PEER — a genuinely interesting person to talk to.\n'
        '- Keep your turns to 2–3 sentences. Ask, then stop. Resist adding your own essay.\n'
        '- End most turns with an open question or a challenge, not a summary.\n'
        '- Abstract, philosophical, and meta-linguistic topics welcome. Humour, idiom, nuance expected.\n'
        '- CORRECTION: precision feedback is welcome — offer the sharper word or structure when it genuinely improves what they said.\n'
        '- Challenge their reasoning, not just their language. Notice HOW they said things, not just what.\n'
        '- ESCALATE: connect their ideas across the conversation; introduce tension and edge cases.'
    ),
}


# ── Conversation Turn ─────────────────────────────────────────────────────────

async def send_conversation_turn(
    messages: list[dict],
    topic: str = "Free conversation",
    level: str = "A1",
    unit_label: str = "Finding My Voice",
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

    # Count student turns (messages with role "user")
    student_turns = len([m for m in messages if m.get("role") == "user"])

    # ── TURN 12+: FORCE COMPLETE ──────────────────────────────────────────────
    # Hard cap — after 12 student turns, force the LLM to assess NOW
    if student_turns >= 12:
        force_prompt = system_prompt + (
            "\n\n⚠️ MANDATORY: You have heard 12 student turns. "
            "You MUST output the final JSON assessment NOW. "
            "Do NOT ask another question. Do NOT output REPLY:. "
            "Assess based on everything you have heard so far."
        )
        api_messages = [{"role": "system", "content": force_prompt}] + [
            {"role": "user" if m["role"] == "user" else "assistant", "content": m["content"]}
            for m in messages
        ]
        text = await _chat_completion(api_messages, max_tokens=600, temperature=0.4)
        # Parse the forced assessment
        try:
            json_str = _extract_json(text)
            data = json.loads(json_str)
            if "level" in data or "level_code" in data:
                return _build_placement_result(data)
        except Exception:
            pass
        # Absolute fallback if LLM still refuses: assign A0 with low confidence
        return {
            "reply": None, "is_complete": True,
            "name": name, "age": age, "age_group": None,
            "level": "A0", "unit_name": "First Words",
            "level_description": "We'll start at the beginning and find your pace.",
            "confidence": "low", "possible_higher": True,
            "evidence_summary": "Assessment forced after 12 turns — insufficient LLM response.",
            "probe_targets_covered": [], "turns_taken": student_turns,
            "code_switch_observed": False, "interests": [],
            "notes_for_first_session": "Consider retaking placement for a more accurate level.",
        }

    # ── NORMAL TURN ───────────────────────────────────────────────────────────
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

    # Try parsing as final JSON assessment
    try:
        json_str = _extract_json(text)
        data = json.loads(json_str)
        if "level" in data or "level_code" in data:
            confidence = data.get("confidence", "low")

            # ── TURN-BASED CONFIDENCE GATES ───────────────────────────────────
            # Turn 1-4: NEVER complete — too early, anxiety hides real level
            if student_turns < 5:
                # Reject — ask a follow-up instead
                return {"reply": _fallback_reply(student_turns), "is_complete": False}

            # Turn 5-8: Only accept HIGH confidence
            elif student_turns <= 8:
                if confidence == "high":
                    return _build_placement_result(data)
                else:
                    # Reject — need more evidence
                    return {"reply": _fallback_reply(student_turns), "is_complete": False}

            # Turn 9-11: Accept HIGH or MEDIUM confidence
            elif student_turns <= 11:
                if confidence in ("high", "medium"):
                    return _build_placement_result(data)
                else:
                    # Low confidence — push toward turn 12
                    return {"reply": _fallback_reply(student_turns), "is_complete": False}

            # Turn 12+: Accept anything (handled above but as safety)
            else:
                return _build_placement_result(data)

    except Exception:
        pass

    # Fallback: treat as plain reply
    return {"reply": text, "is_complete": False}


def _build_placement_result(data: dict) -> dict:
    """Build the standardized placement result from LLM JSON output."""
    import logging
    logging.info(f"Placement JSON interests: {data.get('interests')}")
    return {
        "reply": data.get("reply"),
        "is_complete": True,
        "name": data.get("name"),
        "age": data.get("age"),
        "age_group": data.get("age_group"),
        "level": data.get("level") or data.get("level_code"),
        "unit_name": data.get("unit_name") or data.get("level_name"),
        "level_description": data.get("level_description"),
        "confidence": data.get("confidence"),
        "possible_higher": data.get("possible_higher"),
        "evidence_summary": data.get("evidence_summary"),
        "zoe_recap": data.get("zoe_recap"),
        "probe_targets_covered": data.get("probe_targets_covered"),
        "turns_taken": data.get("turns_taken"),
        "code_switch_observed": data.get("code_switch_observed"),
        "interests": data.get("interests", []),
        "notes_for_first_session": data.get("notes_for_first_session"),
    }


def _fallback_reply(student_turns: int) -> str:
    """Generate a contextual follow-up when rejecting an early completion attempt."""
    if student_turns < 3:
        return "Tell me a little more — what else do you like to do?"
    elif student_turns < 6:
        return "That's interesting! Can you tell me what happened next?"
    elif student_turns < 9:
        return "I'd love to hear one more thing — what do you think about that?"
    else:
        return "Almost done! Tell me one last thing — why do you think that?"


# ── Session Analysis ──────────────────────────────────────────────────────────

async def analyze_and_grade_session(
    messages: list[dict],
    topic: str = "Free Talk",
    level: str = "A2",
    unit_label: str = "Finding My Voice",
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
        .replace("{{UNIT_LABEL}}", unit_label)
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
            max_tokens=2500,
            temperature=0.4,
        )
        json_str = _extract_json(raw)
        data = json.loads(json_str)
        if "scores" not in data:
            data["scores"] = []
        
        # Safety net: discard any score whose ID the LLM hallucinated.
        # The LLM must only return IDs from target_skill_ids. If it invents
        # or reformats an ID (e.g. returns "A1-VOC-01" instead of "U1-VOC-01"),
        # that score would corrupt state_changes with mismatched IDs.
        if target_skill_ids:
            valid_ids = set(target_skill_ids)
            original_scores = data["scores"]
            data["scores"] = [s for s in original_scores if s.get("id") in valid_ids]
            # If LLM dropped a targeted skill entirely, add a zero-confidence entry
            # so apply_merge always sees every aimed skill (just with no evidence).
            returned_ids = {s.get("id") for s in data["scores"]}
            for sid in target_skill_ids:
                if sid not in returned_ids:
                    data["scores"].append({
                        "id": sid,
                        "confidence": 0.0,
                        "prompted": False,
                        "evidence": "",
                    })
        
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
    unit_label: str = "Finding My Voice",
) -> dict | None:
    # Legacy wrapper
    res = await analyze_and_grade_session(messages, topic, level, unit_label, [])
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
