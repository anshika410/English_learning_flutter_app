from __future__ import annotations

from datetime import datetime, timezone
from app.core.curriculum_data import UNITS, CAT, FLOOR, SIGHTINGS_TO_OWN
from app.core.curriculum_helpers import (
    progress_key_for, public_skill_id, is_valid_skill_for_level,
    bucket_of, own_bar, get_skill_text, _normalise_level,
)


def unit_complete(progress: dict, u: dict, level: str = None) -> bool:
    """Unit is complete if ALL skills are owned OR early-unlock condition is met.
    Early unlock: all-but-1 skills owned AND remaining skill has ≥1 sighting.
    When early unlock triggers, the remaining skill is added to carryover queue.
    """
    lvl = level or progress.get("level", "A1")
    unowned = []
    for s in u["skills"]:
        if bucket_of(progress, s["id"], lvl) != "owned":
            unowned.append(s)
    
    # All owned → complete
    if len(unowned) == 0:
        return True
    
    # Early unlock: exactly 1 unowned skill with ≥1 sighting
    if len(unowned) == 1:
        remaining = unowned[0]
        storage_key = progress_key_for(remaining["id"], lvl)
        sightings = progress.get("sightings", {}).get(storage_key, 0)
        if sightings >= 1:
            # Add to carryover queue (if not already there)
            if "carryover" not in progress:
                progress["carryover"] = []
            already = any(c["id"] == remaining["id"] for c in progress["carryover"])
            if not already:
                progress["carryover"].append({
                    "id": remaining["id"],
                    "from_unit": u["step"],
                    "sightings_at_carry": sightings
                })
            return True
    
    return False

def active_step(progress: dict, level: str = None) -> dict | None:
    if level is None:
        level = progress.get("level", "A1")
    units_list = UNITS.get(level.upper(), UNITS.get("A1", []))
    for u in units_list:
        if not unit_complete(progress, u, level):
            return u
    return None

def prioritize_skills(progress: dict, skill_ids: list[str], level: str) -> list[str]:
    """
    Score and sort a list of skill IDs based on dynamic target priority selection:
    TargetScore(s) = 0.35 * Need + 0.20 * Uncertainty + 0.20 * ReviewDue + 0.15 * CurriculumNeed + 0.10 * Variety - 0.25 * Fatigue
    """
    import math
    from datetime import datetime
    
    scores_dict = {}
    recent_primaries = progress.get("recent_primary_history", [])
    
    for idx, sid in enumerate(skill_ids):
        storage_key = progress_key_for(sid, level)
        if not storage_key:
            scores_dict[sid] = -999.0
            continue
            
        # 1. Need (Weight 0.35): 1.0 - mastery
        mastery = progress.get("mastery", {}).get(storage_key, 0.0)
        need = 1.0 - mastery
        
        # 2. Uncertainty (Weight 0.20): 1.0 / sqrt(evidence_count + 1)
        ev_count = progress.get("evidence_count", {}).get(storage_key, 0)
        uncertainty = 1.0 / math.sqrt(ev_count + 1)
        
        # 3. ReviewDue (Weight 0.20): 1.0 - exp(-days_since / 7.0)
        last_seen_str = progress.get("last_seen", {}).get(storage_key)
        if last_seen_str:
            try:
                last_seen_date = datetime.strptime(last_seen_str, "%Y-%m-%d")
                days_since = (datetime.now() - last_seen_date).days
            except Exception:
                days_since = 99.0
        else:
            days_since = 99.0
        review_due = 1.0 - math.exp(-days_since / 7.0)
        
        # 4. CurriculumNeed (Weight 0.15): lower index in original list gets slight priority
        curriculum_need = 1.0 - (idx / max(len(skill_ids), 1))
        
        # 5. Variety (Weight 0.10): prefers less practiced overall
        variety = 1.0 / (ev_count + 1.0)
        
        # 6. Fatigue (Penalty 0.25): based on count in recent primary history
        recent_count = recent_primaries.count(storage_key)
        fatigue = recent_count / 4.0 if recent_primaries else 0.0
        
        score = (
            0.35 * need +
            0.20 * uncertainty +
            0.20 * review_due +
            0.15 * curriculum_need +
            0.10 * variety -
            0.25 * fatigue
        )
        scores_dict[sid] = score

    return sorted(skill_ids, key=lambda s_id: scores_dict[s_id], reverse=True)

def due_unit(progress: dict, level: str = None) -> dict:
    u = active_step(progress, level)
    lvl = level or progress.get("level", "A1")
    
    # Post-last-unit cleanup: if no active unit but carryover remains, rotate only carryover
    if not u:
        carryover = progress.get("carryover", [])
        if carryover:
            # Return oldest carryover skill as the pick
            picks = [{"id": c["id"], "why": "carryover cleanup (all units done)"} for c in carryover]
            return {"picks": picks, "u": None}
        return {"picks": [], "u": None}
    
    # v1 Simple A→B→C→D rotation with carryover injection
    all_skills = u["skills"]  # curriculum order
    
    # Find un-owned skills in this unit
    unowned = []
    for s in all_skills:
        if bucket_of(progress, s["id"], lvl) != "owned":
            unowned.append(s)
    
    if not unowned:
        return {"picks": [], "u": u}
    
    # Check if this is a carryover slot (every 3rd conversation)
    recent = progress.get("recent_primary_history", [])
    carryover = progress.get("carryover", [])
    
    # Every 3rd conversation = carryover slot (positions 2, 5, 8, 11...)
    is_carryover_slot = len(recent) > 0 and (len(recent) % 3 == 2) and len(carryover) > 0
    
    if is_carryover_slot:
        # Pick oldest carryover skill that's not yet owned
        for c in carryover:
            if bucket_of(progress, c["id"], lvl) != "owned":
                picks = [{"id": c["id"], "why": f"carryover from Unit {c['from_unit']}"}]
                # Also include current unit skills as fallback
                for s in unowned:
                    picks.append({"id": s["id"], "why": f"active unit: Step {u['step']} - {u['name']}"})
                return {"picks": picks, "u": u}
    
    # Normal rotation: pick next skill in curriculum order
    if recent:
        last_key = recent[-1]
        # Find position of last practiced skill in curriculum order
        last_idx = None
        for i, s in enumerate(all_skills):
            if progress_key_for(s["id"], lvl) == last_key:
                last_idx = i
                break
        
        if last_idx is not None:
            # Start from next position, wrap around, find first un-owned
            ordered_picks = []
            n = len(all_skills)
            for offset in range(1, n + 1):
                candidate = all_skills[(last_idx + offset) % n]
                if bucket_of(progress, candidate["id"], lvl) != "owned":
                    ordered_picks.append({"id": candidate["id"], "why": f"active unit: Step {u['step']} - {u['name']}"})
            picks = ordered_picks
        else:
            # Last practiced skill not in this unit (maybe was carryover), start from first un-owned
            picks = [{"id": s["id"], "why": f"active unit: Step {u['step']} - {u['name']}"} for s in unowned]
    else:
        # No history yet — start from first skill in curriculum order
        picks = [{"id": s["id"], "why": f"active unit: Step {u['step']} - {u['name']}"} for s in unowned]

    return {"picks": picks, "u": u}

def due_skill(progress: dict, level: str) -> list[dict]:
    # Filter flat skills for this level
    lvl_skills = [s for s in CAT if s[1] == level.upper()]
    
    unowned_ids = []
    for s in lvl_skills:
        sid = s[0]
        if bucket_of(progress, sid) != "owned":
            unowned_ids.append(sid)
            
    sorted_ids = prioritize_skills(progress, unowned_ids, level)
    picks_to_return = sorted_ids[:3]
    return [{"id": sid, "why": "adaptive flat skill priority"} for sid in picks_to_return]

def targets_list_for(progress: dict, model: str, level: str) -> list[str]:
    # v1: Simply return skills in curriculum order (rotation handled by due_unit)
    if model == "unit":
        picks = due_unit(progress, level)["picks"]
    else:
        picks = due_skill(progress, level)
    return [p["id"] for p in picks]

def apply_merge(progress: dict, scores: list[dict], level: str, topic: str = None, created_at: str = None, primary_target: str = None) -> tuple[dict, list[dict]]:
    # Clone progression dict to avoid side-effects
    import copy
    p = copy.deepcopy(progress)
    
    # Ensure default containers exist
    if "owned" not in p: p["owned"] = []
    if "emerging" not in p: p["emerging"] = []
    if "sightings" not in p: p["sightings"] = {}
    if "strength" not in p: p["strength"] = {}
    if "last_seen" not in p: p["last_seen"] = {}
    if "evidence" not in p: p["evidence"] = {}
    if "effort" not in p: p["effort"] = {"times_spoken_total": 0}
    if "recent_primary_history" not in p: p["recent_primary_history"] = []
    
    # Append current session's primary target to history
    if primary_target:
        p_key = progress_key_for(primary_target, level)
        if p_key:
            p["recent_primary_history"].append(p_key)
            if len(p["recent_primary_history"]) > 4:
                p["recent_primary_history"] = p["recent_primary_history"][-4:]

    # Track consecutive zeros for the primary target (for stuck-skill detection)
    if "consecutive_zeros" not in p:
        p["consecutive_zeros"] = {}

    changes = []
    bar = own_bar(level)
    
    for sc in scores:
        skill_id = public_skill_id(sc["id"])
        if not is_valid_skill_for_level(skill_id, level):
            continue
        storage_key = progress_key_for(skill_id, level)
        if storage_key is None:
            continue
        confidence = sc.get("confidence", 0.0)
        prompted = sc.get("prompted", False)
        
        prior = bucket_of(p, storage_key)
        next_state = prior
        
        qualifies = confidence >= bar
        
        # Legacy tracking for backwards compatibility
        if confidence >= FLOOR:
            p["last_seen"][storage_key] = datetime.now().isoformat()[:10]
            if qualifies:
                p["sightings"][storage_key] = p["sightings"].get(storage_key, 0) + 1
            if not prompted:
                p["strength"][storage_key] = p["strength"].get(storage_key, 0) + 1
                
            evidence_text = sc.get("evidence")
            if evidence_text and evidence_text.strip():
                if storage_key not in p["evidence"]:
                    p["evidence"][storage_key] = []
                existing = p["evidence"][storage_key]
                existing_quotes = [e.get("evidence") if isinstance(e, dict) else e for e in existing]
                if evidence_text.strip() not in existing_quotes:
                    p["evidence"][storage_key].append({
                        "evidence": evidence_text.strip(),
                        "confidence": confidence,
                        "prompted": prompted,
                        "topic": topic or "General Conversation",
                        "created_at": created_at or datetime.now(timezone.utc).isoformat()
                    })
                    if len(p["evidence"][storage_key]) > 3:
                        p["evidence"][storage_key] = p["evidence"][storage_key][-3:]
                        
        # v1 Ownership: 3 sightings (confidence >= FLOOR) = owned
        # No mastery formula or context diversity requirement
        sightings = p["sightings"].get(storage_key, 0)
        
        if sightings >= 3:
            next_state = "owned"
        elif sightings >= 1:
            next_state = "emerging"
        else:
            next_state = prior
            
        if next_state != prior:
            changes.append({"id": skill_id, "from": prior, "to": next_state, "name": get_skill_text(skill_id, level)})
            # Safely promote/demote by removing first
            if storage_key in p["emerging"]:
                p["emerging"].remove(storage_key)
            if storage_key in p["owned"]:
                p["owned"].remove(storage_key)
                
            # Add to correct list
            if next_state == "emerging":
                p["emerging"].append(storage_key)
            elif next_state == "owned":
                p["owned"].append(storage_key)
                
        # Track failed attempts to support stuck rotation logic (legacy fallback)
        if "failed_attempts" not in p:
            p["failed_attempts"] = {}
        if storage_key not in p["owned"]:
            if qualifies:
                p["failed_attempts"][storage_key] = 0
            else:
                p["failed_attempts"][storage_key] = p["failed_attempts"].get(storage_key, 0) + 1
        elif storage_key in p["failed_attempts"]:
            del p["failed_attempts"][storage_key]

    # Update consecutive zeros for the primary target.
    # If the primary target scored 0 hits (no score >= FLOOR), increment.
    # If it got any hit, reset to 0.
    if primary_target:
        p_key = progress_key_for(primary_target, level)
        if p_key:
            primary_hit = any(
                sc.get("confidence", 0.0) >= FLOOR
                for sc in scores
                if progress_key_for(public_skill_id(sc.get("id", "")), level) == p_key
            )
            if primary_hit:
                p["consecutive_zeros"][p_key] = 0
            else:
                p["consecutive_zeros"][p_key] = p["consecutive_zeros"].get(p_key, 0) + 1

    # Clean up carryover: remove any skill that has reached 3 sightings (owned)
    if "carryover" in p:
        p["carryover"] = [
            c for c in p["carryover"]
            if bucket_of(p, c["id"], level) != "owned"
        ]

    return p, changes
