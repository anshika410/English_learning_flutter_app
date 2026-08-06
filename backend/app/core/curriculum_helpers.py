from __future__ import annotations

from app.core.curriculum_data import SKILLS, UNIT_SKILLS, UNIT_SKILLS_BY_LEVEL, OWN_BAR, FLOOR, CAT, UNITS


def _normalise_level(level) -> str:
    return str(level or "").upper()

def _split_unit_progress_key(skill_id: str) -> tuple[str | None, str]:
    raw = str(skill_id or "")
    scoped_level, separator, public_id = raw.partition(":")
    scoped_level = scoped_level.upper()
    if separator and (scoped_level, public_id) in UNIT_SKILLS_BY_LEVEL:
        return scoped_level, public_id
    return None, raw

def unit_progress_key(level: str, skill_id: str) -> str | None:
    '''Return the level-scoped storage key for a public unit skill ID.'''
    lvl = _normalise_level(level)
    scoped_level, public_id = _split_unit_progress_key(skill_id)
    if scoped_level and scoped_level != lvl:
        return None
    if (lvl, public_id) not in UNIT_SKILLS_BY_LEVEL:
        return None
    return f"{lvl}:{public_id}"

def progress_key_for(skill_id: str, level: str = None) -> str | None:
    '''Resolve a public skill ID to its internal progress key.'''
    if skill_id in SKILLS:
        return skill_id
    scoped_level, public_id = _split_unit_progress_key(skill_id)
    if scoped_level:
        if level and scoped_level != _normalise_level(level):
            return None
        return f"{scoped_level}:{public_id}"
    if level:
        return unit_progress_key(level, public_id)
    # Bare unit IDs are legacy and ambiguous across levels. Never infer one.
    return None

def public_skill_id(skill_id: str) -> str:
    '''Strip an internal unit scope while leaving flat skill IDs unchanged.'''
    _, public_id = _split_unit_progress_key(skill_id)
    return public_id

def is_valid_skill_for_level(skill_id: str, level: str) -> bool:
    lvl = _normalise_level(level)
    if skill_id in SKILLS:
        return SKILLS[skill_id]["level"] == lvl
    scoped_level, public_id = _split_unit_progress_key(skill_id)
    if scoped_level and scoped_level != lvl:
        return False
    return (lvl, public_id) in UNIT_SKILLS_BY_LEVEL

def make_due_next(skill_ids: list[str], level: str) -> dict:
    '''Build persisted due state with a required level and public target IDs.'''
    lvl = _normalise_level(level)
    valid_ids = []
    for skill_id in skill_ids:
        public_id = public_skill_id(skill_id)
        if is_valid_skill_for_level(public_id, lvl) and public_id not in valid_ids:
            valid_ids.append(public_id)
    return {
        "level": lvl,
        "primary": valid_ids[0] if valid_ids else None,
        "watching": valid_ids[1:] if len(valid_ids) > 1 else [],
    }

def validate_due_next(due_next: dict | None, level: str) -> dict:
    '''Reject legacy or stale due state unless its level matches exactly.'''
    lvl = _normalise_level(level)
    if not isinstance(due_next, dict) or _normalise_level(due_next.get("level")) != lvl:
        return {}
    primary = due_next.get("primary")
    if not primary or not is_valid_skill_for_level(primary, lvl):
        return {}
    watching = due_next.get("watching", [])
    if not isinstance(watching, list):
        watching = []
    return make_due_next([primary, *watching], lvl)

def progress_value(progress: dict, field: str, skill_id: str, level: str = None, default=None):
    key = progress_key_for(skill_id, level)
    values = progress.get(field, {})
    if key is None or not isinstance(values, dict):
        return default
    return values.get(key, default)

def public_progress_for_level(progress: dict, level: str) -> dict:
    '''Expose the historical API shape without leaking scoped storage keys.'''
    import copy
    lvl = _normalise_level(level)
    result = copy.deepcopy(progress if isinstance(progress, dict) else {})

    for field in ("owned", "emerging"):
        public_ids = []
        values = result.get(field, [])
        if not isinstance(values, list):
            values = []
        for key in values:
            if key in SKILLS:
                public_ids.append(key)
                continue
            scoped_level, public_id = _split_unit_progress_key(key)
            if scoped_level == lvl and public_id not in public_ids:
                public_ids.append(public_id)
        result[field] = public_ids

    for field in ("sightings", "strength", "last_seen", "evidence"):
        public_values = {}
        values = result.get(field, {})
        if not isinstance(values, dict):
            values = {}
        for key, value in values.items():
            if key in SKILLS:
                public_values[key] = value
                continue
            scoped_level, public_id = _split_unit_progress_key(key)
            if scoped_level == lvl:
                public_values[public_id] = value
        result[field] = public_values

    # Clean up recent_primary_history format
    raw_history = result.get("recent_primary_history", [])
    if not isinstance(raw_history, list):
        raw_history = []
    public_history = []
    for key in raw_history:
        if key in SKILLS:
            public_history.append(key)
            continue
        scoped_level, public_id = _split_unit_progress_key(key)
        if scoped_level == lvl:
            public_history.append(public_id)
    result["recent_primary_history"] = public_history

    return result

def get_skill_text(skill_id: str, level = None) -> str:
    if skill_id in SKILLS:
        return SKILLS[skill_id]["text"]
    scoped_level, public_id = _split_unit_progress_key(skill_id)
    if scoped_level:
        metadata = UNIT_SKILLS_BY_LEVEL.get((scoped_level, public_id))
        if metadata:
            return metadata["text"]
    if level:
        metadata = UNIT_SKILLS_BY_LEVEL.get((_normalise_level(level), public_id))
        if metadata:
            return metadata["text"]
    return skill_id

def get_skill_strand(skill_id: str, level: str = None) -> str:
    if skill_id in SKILLS:
        return SKILLS[skill_id]["strand"]
    scoped_level, public_id = _split_unit_progress_key(skill_id)
    if scoped_level:
        return UNIT_SKILLS_BY_LEVEL[(scoped_level, public_id)]["strand"]
    if level and (_normalise_level(level), public_id) in UNIT_SKILLS_BY_LEVEL:
        return UNIT_SKILLS_BY_LEVEL[(_normalise_level(level), public_id)]["strand"]
    if public_id in UNIT_SKILLS:
        return UNIT_SKILLS[public_id]["strand"]
    return "VOC"

def own_bar(level: str) -> float:
    return OWN_BAR.get(level.upper(), 0.70)

def bucket_of(progress: dict, skill_id: str, level: str = None) -> str:
    key = progress_key_for(skill_id, level)
    if key is None:
        return "locked"
    owned = progress.get("owned", [])
    emerging = progress.get("emerging", [])
    if key in owned:
        return "owned"
    if key in emerging:
        return "emerging"
    return "locked"
