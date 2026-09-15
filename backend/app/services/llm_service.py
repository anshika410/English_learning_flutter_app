"""LLM proxy service — keeps API keys server-side."""
import json
import re
from pathlib import Path
import httpx
from ..core.config import get_settings

import os

# In Docker: prompts are at /app/assets/prompts (copied by Dockerfile from backend/app/prompts)
# Locally: fall back to backend/app/prompts relative to repo root
_DOCKER_PROMPTS = Path("/app/assets/prompts")
_LOCAL_PROMPTS = Path(__file__).resolve().parent.parent / "prompts"
PROMPTS_DIR = _DOCKER_PROMPTS if _DOCKER_PROMPTS.exists() else _LOCAL_PROMPTS

def resolve_prompt(
    filename: str,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
) -> str:
    """
    Resolves prompt content based on priority:
    1. custom_prompts dict passed in the request (simulator one-off runs)
    2. personal developer sandbox files on disk
    3. production prompts on disk
    """
    if custom_prompts:
        key_mappings = {
            "placement-check-prompt.md": "placement",
            "base-prompt.md": "base",
            "conv-unit-framing.md": "conv-unit-framing",
            "end-result-prompt.md": "judge",
            "correction-extraction-prompt.md": "correction-extraction",
        }
        if filename.startswith("profile-"):
            profile_lvl = filename.replace(".md", "")
            if profile_lvl in custom_prompts:
                return custom_prompts[profile_lvl]
        
        # Fallback maps
        if filename == "correction-extraction-prompt.md" and "correction_extraction" in custom_prompts:
            return custom_prompts["correction_extraction"]
        if filename == "conv-unit-framing.md" and "conv_unit_framing" in custom_prompts:
            return custom_prompts["conv_unit_framing"]

        key = key_mappings.get(filename)
        if key and key in custom_prompts:
            return custom_prompts[key]

    if user_id:
        uuid_part = user_id
        email_part = None
        if ":" in user_id:
            parts = user_id.split(":", 1)
            uuid_part = parts[0]
            email_part = parts[1]

        # 1. Try UUID sandbox
        sandbox_path = PROMPTS_DIR / "sandboxes" / uuid_part / filename
        if sandbox_path.exists():
            return sandbox_path.read_text().strip()

        # 2. Try Email sandbox
        if email_part:
            sandbox_path = PROMPTS_DIR / "sandboxes" / email_part / filename
            if sandbox_path.exists():
                return sandbox_path.read_text().strip()

    return (PROMPTS_DIR / filename).read_text().strip()


def _all_level_skills_text(level_upper: str) -> str:
    """Every "I Can" statement for a CEFR level, across all its curriculum units, in sequence."""
    from ..core.curriculum_data import UNITS

    lines = [
        f"- [{skill['id']}] {skill['text']}"
        for unit in UNITS.get(level_upper, [])
        for skill in unit.get("skills", [])
    ]
    return "\n".join(lines) if lines else "None"

# ── Shared HTTP helper ────────────────────────────────────────────────────────

async def _chat_completion(
    messages: list[dict],
    max_tokens: int = 280,
    temperature: float = 0.75,
) -> str:
    settings = get_settings()
    from ..core.config import preferred_model_var
    preferred = preferred_model_var.get()
    
    # Route Luna (OpenAI GPT) requests directly to OpenAI's official API
    preferred_lower = preferred.lower() if preferred else ""
    if "luna" in preferred_lower:
        model = "gpt-4o-mini"
        base_url = "https://api.openai.com/v1"
        api_key = settings.openai_api_key or settings.deepseek_api_key  # Use direct OpenAI key with fallback to OpenRouter key if present
    # Route DeepSeek requests to Hugging Face if configured, otherwise fallback to OpenRouter
    elif "deepseek" in preferred_lower:
        if settings.huggingface_api_key:
            model = "deepseek-ai/DeepSeek-V3"
            base_url = settings.huggingface_base_url
            api_key = settings.huggingface_api_key
        else:
            model = "deepseek/deepseek-v4-flash"
            base_url = settings.deepseek_base_url
            api_key = settings.deepseek_api_key
    # Default fallback for any other requests (like Gemini or others)
    else:
        # Since Gemini/others are removed, default to gpt-4o-mini if OpenAI API key is present
        if settings.openai_api_key:
            model = "gpt-4o-mini"
            base_url = "https://api.openai.com/v1"
            api_key = settings.openai_api_key
        else:
            model = settings.deepseek_model
            base_url = settings.deepseek_base_url
            api_key = settings.deepseek_api_key

    url = f"{base_url.rstrip('/')}/chat/completions"

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            url,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
            json={
                "model": model,
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

async def extract_correction_highlight(
    messages: list[dict],
    level: str | None = None,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
) -> dict | None:
    """
    Separate LLM call that finds the single best grammar/vocab error in the
    student's speech and returns a before/after correction pair.
    """
    transcript = "\n".join(
        f"{'STUDENT' if m['role'] == 'user' else 'ZOE'}: {m['content']}"
        for m in messages
    )
    student_utterances = [
        str(m.get("content", ""))
        for m in messages
        if m.get("role") in ("user", "learner")
    ]

    template = resolve_prompt("correction-extraction-prompt.md", custom_prompts, user_id)
    prompt = (
        template
        .replace("{{LEVEL}}", (level or "unknown").upper())
        .replace("{{TRANSCRIPT}}", transcript)
    )

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
            exact_said = str(data["student_said"])
            if not any(exact_said in utterance for utterance in student_utterances):
                return None
            said = exact_said.lower()
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
    topic: str | None = None,
    starters: list[str] | None = None,
    level: str = "A1",
    due_next: dict | None = None,
    skills_progress: dict | None = None,
    persona_memory: dict | None = None,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
    last_conversation_transcript: str | None = None,
) -> dict:
    from ..core.curriculum_data import (
        UNITS, active_step, targets_list_for, validate_due_next,
    )
    from ..core.elicitation import resolve_skill_text

    level_upper = str(level or "A1").upper()
    if level_upper not in _LEVEL_BLOCKS:
        level_upper = "A1"

    # Format learner context — only name and age (no persona_memory facts)
    memory_str = "None"
    if persona_memory:
        profile = persona_memory.get("profile") if isinstance(persona_memory, dict) else None
        context_parts = []
        if isinstance(profile, dict):
            if profile.get("name"):
                first_name = str(profile["name"]).split()[0].strip()
                context_parts.append(f"Name: {first_name}")
            if profile.get("age"):
                context_parts.append(f"Age: {profile['age']}")
        # Fallback: check top-level name if profile not available
        if not context_parts and isinstance(persona_memory, dict):
            facts = persona_memory.get("facts", [])
            if isinstance(facts, list):
                for fact in facts:
                    fact_lower = str(fact).lower()
                    if "name is" in fact_lower or fact_lower.startswith("name:"):
                        name_val = str(fact).split("is")[-1].split(":")[-1].strip().rstrip(".")
                        first_name = name_val.split()[0].strip() if name_val else ""
                        if first_name:
                            context_parts.append(f"Name: {first_name}")
                            break
        if context_parts:
            memory_str = "\n".join(f"- {part}" for part in context_parts)

    # Get aimed IDs
    valid_due_next = validate_due_next(due_next, level_upper)
    primary_id = valid_due_next.get("primary")
    watching_ids = valid_due_next.get("watching", [])
    
    candidate_ids = []
    if primary_id:
        candidate_ids.append(primary_id)
    if watching_ids:
        for wid in watching_ids:
            if wid not in candidate_ids:
                candidate_ids.append(wid)
                
    if not candidate_ids:
        # Fallback to computing targets on the fly
        candidate_ids = targets_list_for(skills_progress or {}, "unit", level_upper)

    target_ids = [
        sid for sid in candidate_ids
        if resolve_skill_text(sid, level_upper) is not None
    ]
    if not target_ids:
        fallback_ids = targets_list_for(
            skills_progress or {}, "unit", level_upper
        )
        target_ids = [
            sid for sid in fallback_ids
            if resolve_skill_text(sid, level_upper) is not None
        ]

    # Get active unit name & focus
    active_unit = None
    if target_ids:
        primary_target = target_ids[0]
        active_unit = next(
            (
                unit
                for unit in UNITS.get(level_upper, [])
                if primary_target in {
                    skill.get("id") for skill in unit.get("skills", [])
                }
            ),
            None,
        )
    if active_unit is None:
        active_unit = active_step(skills_progress or {}, level_upper)
    if active_unit:
        unit_name = active_unit.get("name", topic) or topic
        unit_focus = active_unit.get("focus", "General conversation practice")
    else:
        unit_name = topic
        unit_focus = "General conversation practice"

    # Build targets list text showing IDs and descriptions
    if target_ids:
        targets_str = "\n".join(
            f"- [{sid}] {resolve_skill_text(sid, level_upper)}"
            for sid in target_ids
        )
    else:
        targets_str = "- General conversation practice"

    # Build elicitation plan (using plan_text(target_ids)) - Deprecated
    # elicitation_str = plan_text(target_ids, level_upper)

    primary_id = target_ids[0] if target_ids else None
    primary_strand = "VOC"
    if primary_id:
        from ..core.curriculum_data import get_skill_strand, SKILL_CONCEPTS
        primary_strand = get_skill_strand(primary_id)
    else:
        from ..core.curriculum_data import SKILL_CONCEPTS
    primary_skill_text = resolve_skill_text(primary_id, level_upper) if primary_id else "General conversation practice"
    primary_concept = SKILL_CONCEPTS.get(primary_id, primary_skill_text.split("I can ")[-1].split(".")[0].strip() if primary_id else "general conversation")

    watching_ids = target_ids[1:] if len(target_ids) > 1 else []
    watch_list_str = "\n".join(
        f"- [{wid}] {resolve_skill_text(wid, level_upper)}"
        for wid in watching_ids
        if resolve_skill_text(wid, level_upper)
    ) if watching_ids else "None"

    # Conversation now uses a single monolithic prompt (candidate-ella-prompt.md)
    # instead of concatenating base-prompt.md + profile-{level}.md + conv-unit-framing.md.
    # Those three files are intentionally left untouched on disk and unused here —
    # they still back other flows (placement, etc.) and nothing is deleted.
    prompt_template = resolve_prompt("candidate-ella-prompt.md", custom_prompts, user_id)
    prompt_block = (
        prompt_template
        .replace("{{UNITNAME}}", str(unit_name))
        .replace("{{UNITFOCUS}}", str(unit_focus))
        .replace("{{TARGETS}}", targets_str)
        # .replace("{{ELICITATION}}", elicitation_str) # Deprecated
        .replace("{{STUDENT_MEMORY}}", memory_str)
        .replace("{{CURRENT_TURN}}", "1")
        # Support new pk_1.1 placeholders
        .replace("{{UNIT}}", str(unit_name))
        .replace("{{CONVERSATION_TOPIC}}", topic or "Free conversation")
        .replace("{{PRIMARY_STRAND}}", primary_strand)
        .replace("{{PRIMARY_SKILL}}", primary_skill_text)
        .replace("{{PRIMARY_CONCEPT}}", primary_concept)
        .replace("{{LEARNER_CONTEXT}}", memory_str)
        .replace("{{WATCH_LIST}}", watch_list_str)
        .replace("{{LEVEL}}", level_upper)
        .replace("{{ALL_LEVEL_SKILLS}}", _all_level_skills_text(level_upper))
        .replace("{{SKILL_SHAPE}}", "Infer from today's I Can statement (Range or Extension)")
        .replace("{{LAST_CONVERSATION}}", last_conversation_transcript or "None — this is the learner's first conversation.")
        .strip()
    )

    system_prompt = (
        f"{prompt_block}\n\n"
        f"---\n\n"
        f"The user message supplies the topic and may include sample starters.\n\n"
        f"After generating Zoe's first spoken turn, output on a new line:\n"
        f"TITLE: <a natural 2–4 word conversation title, no punctuation>"
    )
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
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": topic_line},
        ],
        max_tokens=160,
        temperature=0.8,
    )
    title_match = re.search(r"TITLE:\s*(.+)", text, re.IGNORECASE)
    header_title = title_match.group(1).strip() if title_match else (topic or "Free Talk")
    starter = re.sub(r"TITLE:.*", "", text, flags=re.IGNORECASE).strip()
    return {"starter": starter or text.strip(), "header_title": header_title}


# ── Level blocks — loaded from profile-*.md files ────────────────────────────
# Single source of truth: edit the .md files to change Zoe's per-level behavior.
# The simulator reads these same files, so QA in the simulator = QA in production.

def _load_level_blocks() -> dict[str, str]:
    mapping = {
        "A0": "profile-A0.md",
        "A1": "profile-A1.md",
        "A2": "profile-A2.md",
        "B1": "profile-B1.md",
        "B2": "profile-B2.md",
        "C1": "profile-C1.md",
    }
    blocks = {}
    for level, filename in mapping.items():
        path = PROMPTS_DIR / filename
        if path.exists():
            blocks[level] = path.read_text().strip()
        else:
            # Fallback: log warning and use empty string — better than silently
            # using wrong behavior
            import logging
            logging.warning(f"Profile prompt not found: {path}")
            blocks[level] = ""
    return blocks

_LEVEL_BLOCKS = _load_level_blocks()


# ── Conversation Turn ─────────────────────────────────────────────────────────

def _closing_without_question(reply: str) -> str:
    """Remove any new question from a deterministically final conversation turn."""
    if "?" not in reply:
        return reply.strip() or "Thanks for talking with me today."

    statements = [
        part.strip()
        for part in re.split(r"(?<=[.!?])\s+", reply)
        if part.strip() and "?" not in part
    ]
    return " ".join(statements) or "Thanks for talking with me today."


async def send_conversation_turn(
    messages: list[dict],
    topic: str = "Free conversation",
    level: str = "A1",
    unit_label: str = "Finding My Voice",
    current_turn: int = 1,
    persona_memory: dict | None = None,
    due_next: dict | None = None,
    skills_progress: dict | None = None,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
    last_conversation_transcript: str | None = None,
) -> dict:
    from ..core.curriculum_data import (
        UNITS, active_step, targets_list_for, validate_due_next,
    )
    from ..core.elicitation import resolve_skill_text

    # Format learner context — only name and age (no persona_memory facts)
    memory_str = "None"
    if persona_memory:
        profile = persona_memory.get("profile") if isinstance(persona_memory, dict) else None
        context_parts = []
        if isinstance(profile, dict):
            if profile.get("name"):
                first_name = str(profile["name"]).split()[0].strip()
                context_parts.append(f"Name: {first_name}")
            if profile.get("age"):
                context_parts.append(f"Age: {profile['age']}")
        if context_parts:
            memory_str = "\n".join(f"- {part}" for part in context_parts)

    level_upper = level.upper() if level else "A1"
    if level_upper not in _LEVEL_BLOCKS:
        level_upper = "A1"

    # Get aimed IDs
    valid_due_next = validate_due_next(due_next, level_upper)
    primary_id = valid_due_next.get("primary")
    watching_ids = valid_due_next.get("watching", [])
    
    candidate_ids = []
    if primary_id:
        candidate_ids.append(primary_id)
    if watching_ids:
        for wid in watching_ids:
            if wid not in candidate_ids:
                candidate_ids.append(wid)
                
    if not candidate_ids:
        # Fallback to computing targets on the fly
        candidate_ids = targets_list_for(skills_progress or {}, "unit", level_upper)

    # Unit IDs repeat across levels. Discard stale or mismatched targets rather
    # than leaking a raw ID or another level's skill into Zoe's prompt.
    target_ids = [
        sid for sid in candidate_ids
        if resolve_skill_text(sid, level_upper) is not None
    ]
    if not target_ids:
        fallback_ids = targets_list_for(
            skills_progress or {}, "unit", level_upper
        )
        target_ids = [
            sid for sid in fallback_ids
            if resolve_skill_text(sid, level_upper) is not None
        ]

    # Get active unit name & focus
    active_unit = None
    if target_ids:
        primary_target = target_ids[0]
        active_unit = next(
            (
                unit
                for unit in UNITS.get(level_upper, [])
                if primary_target in {
                    skill.get("id") for skill in unit.get("skills", [])
                }
            ),
            None,
        )
    if active_unit is None:
        active_unit = active_step(skills_progress or {}, level_upper)
    if active_unit:
        unit_name = active_unit.get("name", topic) or topic
        unit_focus = active_unit.get("focus", "General conversation practice")
    else:
        unit_name = topic
        unit_focus = "General conversation practice"

    # Build targets list text showing IDs and descriptions
    if target_ids:
        targets_str = "\n".join(
            f"- [{sid}] {resolve_skill_text(sid, level_upper)}"
            for sid in target_ids
        )
    else:
        targets_str = "- General conversation practice"

    # Build elicitation plan (using plan_text(target_ids)) - Deprecated
    # elicitation_str = plan_text(target_ids, level_upper)

    # Support new style variables for pk_1.1
    primary_id = target_ids[0] if target_ids else None
    primary_strand = "VOC"
    if primary_id:
        from ..core.curriculum_data import get_skill_strand, SKILL_CONCEPTS
        primary_strand = get_skill_strand(primary_id)
    else:
        from ..core.curriculum_data import SKILL_CONCEPTS
    primary_skill_text = resolve_skill_text(primary_id, level_upper) if primary_id else "General conversation practice"
    primary_concept = SKILL_CONCEPTS.get(primary_id, primary_skill_text.split("I can ")[-1].split(".")[0].strip() if primary_id else "general conversation")
    
    watching_ids = target_ids[1:] if len(target_ids) > 1 else []
    watch_list_str = "\n".join(
        f"- [{wid}] {resolve_skill_text(wid, level_upper)}"
        for wid in watching_ids
        if resolve_skill_text(wid, level_upper)
    ) if watching_ids else "None"

    # Conversation now uses a single monolithic prompt (candidate-ella-prompt.md)
    # instead of concatenating base-prompt.md + profile-{level}.md + conv-unit-framing.md.
    # Those three files are intentionally left untouched on disk and unused here —
    # they still back other flows (placement, etc.) and nothing is deleted.
    prompt_template = resolve_prompt("candidate-ella-prompt.md", custom_prompts, user_id)

    system_prompt = (
        prompt_template
        .replace("{{UNITNAME}}", unit_name)
        .replace("{{UNITFOCUS}}", unit_focus)
        .replace("{{TARGETS}}", targets_str)
        # .replace("{{ELICITATION}}", elicitation_str) # Deprecated
        .replace("{{STUDENT_MEMORY}}", memory_str)
        .replace("{{CURRENT_TURN}}", str(current_turn))
        # Support new pk_1.1 placeholders
        .replace("{{UNIT}}", unit_name)
        .replace("{{CONVERSATION_TOPIC}}", topic)
        .replace("{{PRIMARY_STRAND}}", primary_strand)
        .replace("{{PRIMARY_SKILL}}", primary_skill_text)
        .replace("{{PRIMARY_CONCEPT}}", primary_concept)
        .replace("{{LEARNER_CONTEXT}}", memory_str)
        .replace("{{WATCH_LIST}}", watch_list_str)
        .replace("{{LEVEL}}", level_upper)
        .replace("{{ALL_LEVEL_SKILLS}}", _all_level_skills_text(level_upper))
        .replace("{{SKILL_SHAPE}}", "Infer from today's I Can statement (Range or Extension)")
        .replace("{{LAST_CONVERSATION}}", last_conversation_transcript or "None — this is the learner's first conversation.")
        .strip()
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
    if complete:
        reply = _closing_without_question(reply)
    correction = None

    return {
        "reply": reply,
        "correction": correction,
        "conversation_complete": complete,
        "prompt_debug": {
            "system_prompt": system_prompt,
            "level": level_upper,
            "unit_name": unit_name,
            "unit_focus": unit_focus,
            "target_ids": target_ids,
            "targets_str": targets_str,
            "elicitation_str": None, # Deprecated
            "student_memory": memory_str,
            "current_turn": current_turn,
        },
    }


# ── Placement Turn ────────────────────────────────────────────────────────────

async def send_placement_turn(
    messages: list[dict],
    name: str | None = None,
    age: int | None = None,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
) -> dict:
    raw_prompt = resolve_prompt("placement-check-prompt.md", custom_prompts, user_id)
    base_block = resolve_prompt("base-prompt.md", custom_prompts, user_id)
    
    # Extract first name to use in prompts so Zoe doesn't use the full name
    first_name = name.split()[0].strip() if name else "there"
    # Inject student name and age into the prompt
    system_prompt = (
        raw_prompt
        .replace("{{BASE_BLOCK}}", base_block)
        .replace("{{NAME}}", first_name)
        .replace("{{AGE}}", str(age) if age is not None else '"unknown"')
    )

    # Count student turns (messages with role "user")
    student_turns = len([m for m in messages if m.get("role") == "user"])

    # ── TURN 9+: FORCE COMPLETE ───────────────────────────────────────────────
    # Hard cap — after 9 student turns, force the LLM to assess now.
    if student_turns >= 9:
        api_messages = [{"role": "system", "content": system_prompt}] + [
            {"role": "user" if m["role"] == "user" else "assistant", "content": m["content"]}
            for m in messages
        ]
        # Append the final force instructions directly to the last user message to prevent the LLM
        # from ignoring the system instructions in a long conversation context.
        if api_messages and api_messages[-1]["role"] == "user":
            api_messages[-1]["content"] += (
                "\n\n[SYSTEM: The conversation is finished. You must output the final JSON assessment block now. "
                "Do not reply to the learner's last turn with conversation. Output ONLY the JSON block.]"
            )
        else:
            api_messages.append({
                "role": "system",
                "content": "MANDATORY: Output the final JSON assessment block now. Output ONLY valid JSON."
            })

        text = await _chat_completion(api_messages, max_tokens=600, temperature=0.4)
        # Parse the forced assessment
        try:
            json_str = _extract_json(text)
            data = json.loads(json_str)
            if "level" in data or "level_code" in data:
                return _build_placement_result(data)
        except Exception as e:
            # Fallback to loose parser
            loose_data = _parse_loose_placement_output(text)
            if loose_data:
                return _build_placement_result(loose_data)
            import logging
            logging.warning(f"Failed parsing forced placement assessment: {e}. Raw text: {text}")
        # Absolute fallback if the LLM still refuses: start conservatively
        # and explicitly mark that the learner may be higher.
        return {
            "reply": None, "is_complete": True,
            "name": name, "age": age, "age_group": None,
            "level": "A0", "unit_name": "First Words",
            "level_description": "We'll start at the beginning and find your pace.",
            "confidence": "low", "possible_higher": True,
            "evidence_summary": "Assessment forced after 9 turns — insufficient LLM response.",
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
    data = None
    try:
        json_str = _extract_json(text)
        data = json.loads(json_str)
    except Exception:
        # Fallback to loose parser
        data = _parse_loose_placement_output(text)

    if data and ("level" in data or "level_code" in data):
        try:
            confidence = data.get("confidence", "low")

            # ── TURN-BASED CONFIDENCE GATES ───────────────────────────────────
            # Turn 1-4: NEVER complete — too early, anxiety hides real level
            if student_turns < 5:
                # Reject — ask a follow-up instead
                return await _continue_placement(
                    system_prompt, messages, student_turns, data.get("level")
                )

            # Turn 5-7: accept only high confidence.
            elif student_turns <= 7:
                if confidence == "high":
                    return _build_placement_result(data)
                else:
                    return await _continue_placement(
                        system_prompt, messages, student_turns, data.get("level")
                    )

            # Turn 8: accept high or medium confidence.
            elif student_turns == 8:
                if confidence in ("high", "medium"):
                    return _build_placement_result(data)
                else:
                    return await _continue_placement(
                        system_prompt, messages, student_turns, data.get("level")
                    )

            # Turn 9+: handled by the forced-completion branch above.
            else:
                return _build_placement_result(data)
        except Exception:
            pass

    # Fallback: treat as plain reply
    # If the reply contains technical keys, extract zoe_recap or show a friendly fallback
    marker_words = ["evidence_summary", "possible_higher", "zoe_recap", "level_description"]
    if any(word in text.lower() for word in marker_words):
        recap_match = re.search(r"[\"']?(?:zoe_recap|level_description)[\"']?\s*[:=]\s*[\"']?([^,\n}\"']+)", text, re.IGNORECASE)
        if recap_match:
            friendly_text = recap_match.group(1).strip()
            if friendly_text:
                return {"reply": friendly_text, "is_complete": False}
        return {"reply": "Awesome job! We've completed our conversation. Let's find your level!", "is_complete": False}

    return {"reply": text, "is_complete": False}


def _build_placement_result(data: dict) -> dict:
    """Build the standardized placement result from LLM JSON output."""
    import logging
    logging.info(f"Placement JSON interests: {data.get('interests')}")
    level_names = {
        "A0": "First Words",
        "A1": "Finding My Voice",
        "A2": "Building Confidence",
        "B1": "Expressing Myself",
        "B2": "Speaking Fluently",
        "C1": "Mastering the Language",
    }
    raw_level = str(data.get("level") or data.get("level_code") or "A0").upper()
    level = raw_level if raw_level in level_names else "A0"
    return {
        "reply": data.get("reply"),
        "is_complete": True,
        "name": data.get("name"),
        "age": data.get("age"),
        "age_group": data.get("age_group"),
        "level": level,
        "unit_name": level_names[level],
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


def _parse_loose_placement_output(text: str) -> dict | None:
    """Fallback parser for malformed, unquoted, or prefixed placement outputs from LLM."""
    marker_words = ["level", "confidence", "evidence_summary", "zoe_recap"]
    matches_markers = any(word in text.lower() for word in marker_words)
    if not matches_markers:
        return None

    data = {}
    
    # Extract level (A0-C1)
    level_match = re.search(r"[\"']?(?:level|level_code)[\"']?\s*[:=]\s*[\"']?([A-C][0-2])[\"']?", text, re.IGNORECASE)
    if level_match:
        data["level"] = level_match.group(1).upper()
        
    # Extract confidence
    conf_match = re.search(r"[\"']?confidence[\"']?\s*[:=]\s*[\"']?(\w+)[\"']?", text, re.IGNORECASE)
    if conf_match:
        data["confidence"] = conf_match.group(1).lower()

    # Extract zoe_recap / level_description
    recap_match = re.search(r"[\"']?zoe_recap[\"']?\s*[:=]\s*[\"']?([^,\n}\"']+)", text, re.IGNORECASE)
    if recap_match:
        data["zoe_recap"] = recap_match.group(1).strip()
        
    desc_match = re.search(r"[\"']?level_description[\"']?\s*[:=]\s*[\"']?([^,\n}\"']+)", text, re.IGNORECASE)
    if desc_match:
        data["level_description"] = desc_match.group(1).strip()

    # Extract evidence_summary
    ev_match = re.search(r"[\"']?evidence_summary[\"']?\s*[:=]\s*[\"']?([^,\n}\"']+)", text, re.IGNORECASE)
    if ev_match:
        data["evidence_summary"] = ev_match.group(1).strip()

    # If we found at least a level, we can reconstruct the assessment!
    if "level" in data:
        data["confidence"] = data.get("confidence") or "medium"
        data["zoe_recap"] = data.get("zoe_recap") or data.get("level_description") or "You enjoy talking and practicing your English!"
        data["level_description"] = data.get("level_description") or data.get("zoe_recap") or "We'll find your perfect pace."
        data["evidence_summary"] = data.get("evidence_summary") or "Assessment completed using fallback loose parsing."
        return data

    return None


async def _continue_placement(
    system_prompt: str,
    messages: list[dict],
    student_turns: int,
    candidate_level: str | None,
) -> dict:
    """Ask the model for one contextual discriminating probe instead of a generic fallback."""
    continuation_prompt = system_prompt + (
        "\n\nCONTINUE, DO NOT ASSESS YET. "
        f"The tentative level is {candidate_level or 'uncertain'}, but more evidence is required. "
        "Based on the learner's latest meaning and the existing topic, ask exactly one natural "
        "question that helps distinguish this level from an adjacent level. "
        "Use the least support needed. Output only REPLY: followed by the question."
    )
    api_messages = [{"role": "system", "content": continuation_prompt}] + [
        {
            "role": "user" if m.get("role") == "user" else "assistant",
            "content": m.get("content", ""),
        }
        for m in messages
    ]
    try:
        text = await _chat_completion(api_messages, max_tokens=140, temperature=0.6)
        reply_match = re.search(r"REPLY:\s*(.*)", text, re.IGNORECASE | re.DOTALL)
        reply = (reply_match.group(1) if reply_match else text).strip()
        if reply:
            return {"reply": reply, "is_complete": False}
    except Exception:
        pass
    return {
        "reply": _fallback_reply(student_turns, candidate_level),
        "is_complete": False,
    }


def _fallback_reply(student_turns: int, candidate_level: str | None = None) -> str:
    """Last-resort level-aware placement probe."""
    level = (candidate_level or "").upper()
    if level == "A0":
        return "Rice or noodles?"
    if level == "A1":
        return "What food do you like?"
    if level == "A2":
        return "What did you do yesterday?"
    if level == "B1":
        return "What is one reason?"
    if level in ("B2", "C1"):
        return "What is the strongest counterpoint?"
    if student_turns < 3:
        return "What food do you like?"
    return "What is one more detail?"


# ── Session Analysis ──────────────────────────────────────────────────────────

async def analyze_and_grade_session(
    messages: list[dict],
    topic: str = "Free Talk",
    level: str = "A2",
    unit_label: str = "Finding My Voice",
    target_skill_ids: list[str] | None = None,
    custom_prompts: dict | None = None,
    user_id: str | None = None,
) -> dict:
    from ..core.curriculum_data import get_skill_text
    target_skill_ids = target_skill_ids or []

    template = resolve_prompt("end-result-prompt.md", custom_prompts, user_id)
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
            max_tokens=3500,
            temperature=0.4,
        )
        json_str = _extract_json(raw)
        data = json.loads(json_str)
        if "scores" not in data:
            data["scores"] = []

        student_utterances = [
            str(m.get("content", ""))
            for m in messages
            if m.get("role") in ("user", "learner")
        ]

        # Exact-quote safety: never store a fabricated best-moment quote.
        best_moment = data.get("best_moment")
        if isinstance(best_moment, dict):
            quote = str(best_moment.get("quote") or "")
            if quote and not any(quote in utterance for utterance in student_utterances):
                best_moment["quote"] = ""
                best_moment["note"] = ""

        # Preserve the exact learner transcript and only attach notes whose
        # utterance matches. This also guarantees one note per learner turn.
        returned_notes = data.get("transcript_notes", [])
        if not isinstance(returned_notes, list):
            returned_notes = []
        unused_notes = [n for n in returned_notes if isinstance(n, dict)]
        normalized_notes = []
        for utterance in student_utterances:
            match_index = next(
                (
                    index
                    for index, note in enumerate(unused_notes)
                    if note.get("text") == utterance
                ),
                None,
            )
            note_text = None
            if match_index is not None:
                note_text = unused_notes.pop(match_index).get("note")
            normalized_notes.append(
                {"speaker": "student", "text": utterance, "note": note_text}
            )
        data["transcript_notes"] = normalized_notes
        
        # Safety net: discard any score whose ID the LLM hallucinated.
        # The LLM must only return IDs from target_skill_ids. If it invents
        # or reformats an ID (e.g. returns "A1-VOC-01" instead of "U1-VOC-01"),
        # that score would corrupt state_changes with mismatched IDs.
        if target_skill_ids:
            valid_ids = set(target_skill_ids)
            original_scores = data["scores"]
            data["scores"] = [s for s in original_scores if s.get("id") in valid_ids]
            valid_support = {
                "spontaneous",
                "open_question",
                "choice",
                "frame",
                "model",
            }
            for score in data["scores"]:
                support = score.get("support_level")
                if support not in valid_support:
                    support = "open_question" if score.get("prompted") else "spontaneous"
                score["support_level"] = support
                score["prompted"] = support != "spontaneous"
                evidence = str(score.get("evidence") or "")
                if evidence and not any(
                    evidence in utterance for utterance in student_utterances
                ):
                    # Fabricated quote — discard the credit, not just the quote,
                    # so a hallucinated demonstration never earns a sighting.
                    score["evidence"] = ""
                    score["confidence"] = 0.0
            # If LLM dropped a targeted skill entirely, add a zero-confidence entry
            # so apply_merge always sees every aimed skill (just with no evidence).
            returned_ids = {s.get("id") for s in data["scores"]}
            for sid in target_skill_ids:
                if sid not in returned_ids:
                    data["scores"].append({
                        "id": sid,
                        "confidence": 0.0,
                        "prompted": False,
                        "support_level": "spontaneous",
                        "evidence": "",
                    })
        else:
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
                    "support_level": "spontaneous",
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
