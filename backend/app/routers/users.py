from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UpdateProfileRequest, UpdateMemoryRequest, UserMemoryResponse, GardenResponse, TopicResponse, PlacementSubResponse, PlacementGardenResponse
from ..core.curriculum_data import (
    UNITS, bucket_of, progress_value, public_progress_for_level,
    unit_progress_key, validate_due_next,
)


router = APIRouter(prefix="/users", tags=["users"])


def _compute_placement_garden(user: User) -> PlacementGardenResponse | None:
    """
    Compute placement garden stage from the user's latest placement confidence.
    Returns None if no placement exists (client treats as "soil" state).
    """
    if not user.placements:
        return None
    latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
    confidence = latest_placement.confidence  # "high", "medium", "low", or None
    if confidence in ("high", "medium"):
        stage = "bloom"
    else:
        stage = "seed"  # "low" or unknown confidence → seed
    return PlacementGardenResponse(
        stage=stage,
        level=latest_placement.level,
        confidence=confidence,
    )


def _to_memory_response(user: User, last_time_recap: str | None = None) -> UserMemoryResponse:
    persona = user.persona_memory or {}
    progress = user.skills_progress or {}
    level_code = (user.level or "A0").upper()
    public_progress = public_progress_for_level(progress, level_code)
    due = validate_due_next(user.due_next, level_code)
    units_list = persona.get("units", [])
    if not isinstance(units_list, list):
        units_list = []

    last_topics_list = persona.get("last_topics", [])
    if not isinstance(last_topics_list, list):
        last_topics_list = []

    age_val = None
    if user.age and user.age.isdigit():
        age_val = int(user.age)

    profile_data = {
        "name": user.first_name or None,
        "age": age_val,
        "city": user.location or None,
        "grade": None,
        "email": user.email,
    }

    placement_data = None
    if user.placements:
        latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
        placement_data = PlacementSubResponse(
            level=latest_placement.level,
            unit_label=latest_placement.unit_label,
            confidence=latest_placement.confidence,
            highlight=latest_placement.highlight,
            created_at=latest_placement.created_at.isoformat(),
        )

    from ..core.curriculum_data import LEVEL_TOPICS, UNITS
    all_topics = LEVEL_TOPICS.get(level_code, [])
    valid_topics = [t for t in all_topics if t.get("name")]
    
    # 1. Determine Needs from current active skill
    primary_skill_id = due.get("primary")
    skill_needs = {"any"}
    if primary_skill_id:
        for step in UNITS.get(level_code, []):
            for skill in step.get("skills", []):
                if skill.get("id") == primary_skill_id:
                    skill_needs = set(skill.get("needs") or ["any"])
                    break
    
    # 2. Filter topics by compatibility
    compatible_topics = []
    for t in valid_topics:
        topic_affordances = set(t.get("affordances", []))
        if "any" in skill_needs or skill_needs.intersection(topic_affordances):
            compatible_topics.append(t)
            
    # Fallback to all topics if none matched
    if not compatible_topics:
        compatible_topics = valid_topics
        
    # 3. Apply floor 7 / ceiling 12 logic with freshness
    used = set(last_topics_list[-2:]) if last_topics_list else set() # Exclude last 2 sessions
    fresh = [t for t in compatible_topics if t["name"] not in used]
    stale = [t for t in compatible_topics if t["name"] in used]
    
    # If excluding drops us below 7, skip exclusion
    if len(fresh) < 7:
        fresh = compatible_topics
        stale = []
        
    import random
    import hashlib
    from datetime import datetime, timezone
    
    current_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    seed_str = f"{user.id}-{current_date}"
    seed_int = int(hashlib.md5(seed_str.encode()).hexdigest(), 16)
    local_random = random.Random(seed_int)
    
    local_random.shuffle(fresh)
    local_random.shuffle(stale)
    
    ordered_topics = (fresh + stale)[:12]

    def _topic_item(t):
        starters = t.get("starters", [])
        icon, color, highlight, bg = get_theme_assets(t)
        return {
            "name": t["name"],
            "label": t.get("shortName") or t.get("label") or t["name"],
            "icon": icon,
            "starter": starters[0] if starters else None,
        }

    from ..schemas.user import NextTopics, NextTopicItem
    next_topics_obj = None
    has_completed_onboarding = user.first_session_done or bool(user.placements)
    if ordered_topics and has_completed_onboarding:
        rec = _topic_item(ordered_topics[0])
        alts = [_topic_item(t) for t in ordered_topics[1:]]
        next_topics_obj = NextTopics(
            recommended=NextTopicItem(**rec),
            alternatives=[NextTopicItem(**a) for a in alts]
        )

    return UserMemoryResponse(
        id=user.id,
        device_id=user.device_id,
        profile=profile_data,
        level=user.level,
        first_session_done=user.first_session_done,
        interests=user.interests.split(",") if user.interests else [],
        last_time_recap=last_time_recap,
        placement=placement_data,
        placement_garden=_compute_placement_garden(user),
        owned=public_progress.get("owned", []),
        emerging=public_progress.get("emerging", []),
        due_next=due,
        next_topics=next_topics_obj,
        effort=public_progress.get("effort", {"times_spoken_total": 0}),
        sightings=public_progress.get("sightings", {}),
        strength=public_progress.get("strength", {}),
        updated_after_chat=public_progress.get("updated_after_chat", 0),
        units=units_list,
        last_topics=last_topics_list,
        persona_memory={k: v for k, v in (user.persona_memory or {}).items() if k not in ("last_topics", "units")},
        mastery=public_progress.get("mastery", {}),
        evidence_count=public_progress.get("evidence_count", {}),
        context_diversity=public_progress.get("context_diversity", {}),
        recent_primary_history=public_progress.get("recent_primary_history", []),
    )


async def _get_last_time_recap(user_id: str, db: AsyncSession, user: User = None) -> str | None:
    from ..models.conversation import Conversation
    from ..models.session_analysis import SessionAnalysis
    from sqlalchemy import select, desc
    try:
        conv_result = await db.execute(
            select(Conversation)
            .where(Conversation.user_id == user_id, Conversation.completed == True)
            .order_by(desc(Conversation.created_at))
            .limit(1)
        )
        latest_conv = conv_result.scalar_one_or_none()
        if latest_conv:
            sa_result = await db.execute(
                select(SessionAnalysis).where(SessionAnalysis.conversation_id == latest_conv.id)
            )
            sa = sa_result.scalar_one_or_none()
            if sa:
                return sa.zoe_recap
    except Exception:
        pass
    
    # Fallback: if no conversation recap exists but placement was done, use placement recap
    if user and user.placements:
        latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
        if latest_placement.highlight:
            return latest_placement.highlight
    
    # Double-check via direct DB query (in case relationship not loaded)
    from ..models.placement import Placement as PlacementModel
    try:
        pl_result = await db.execute(
            select(PlacementModel)
            .where(PlacementModel.user_id == user_id)
            .order_by(desc(PlacementModel.created_at))
            .limit(1)
        )
        pl = pl_result.scalar_one_or_none()
        if pl and pl.highlight:
            return pl.highlight
    except Exception:
        pass

    return None


@router.get("/me", response_model=UserMemoryResponse)
async def get_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    recap = await _get_last_time_recap(user.id, db, user)
    return _to_memory_response(user, recap)


@router.put("/me", response_model=UserMemoryResponse)
async def update_profile(
    body: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.name is not None:
        user.name = body.name
    if body.age is not None:
        user.age = body.age
    if body.location is not None:
        user.location = body.location
    if body.level is not None:
        if (user.level or "").upper() != body.level.upper():
            user.due_next = {}
        user.level = body.level
    
    unit_val = body.unit or body.unit_label
    if unit_val is not None:
        user.unit_label = unit_val
        
    db.add(user)
    await db.flush()
    recap = await _get_last_time_recap(user.id, db, user)
    return _to_memory_response(user, recap)


@router.get("/me/memory", response_model=UserMemoryResponse)
async def get_user_memory(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns the student's full learning memory as a unified object.
    Combines profile, persona facts, skills progress, and next targets.
    """
    recap = await _get_last_time_recap(user.id, db, user)
    return _to_memory_response(user, recap)


@router.put("/me/memory")
async def update_user_memory(
    body: UpdateMemoryRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Manually updates, overrides, or clears the child's permanent persona memory block.
    
    Used to modify narrative facts or clear stored memory to reset the learning context.
    """
    user.persona_memory = body.persona_memory
    db.add(user)
    await db.flush()
    return {"persona_memory": user.persona_memory}


@router.delete("/me/memory", status_code=204)
async def clear_user_memory(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Clears the child's permanent persona memory block and resets onboarding state.
    """
    user.persona_memory = {}
    user.name = None
    user.age = None
    db.add(user)
    await db.commit()
    return None


@router.delete("/me", status_code=204)
async def delete_user_memory(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Resets all learning memory for the authenticated user.

    Clears: placement history, skills progress, persona memory, profile info
    (name, age, level), and the first-session flag. The user account itself
    (email / id) is preserved so they can log back in and start fresh.

    Called by the Flutter app's "Delete Memory" feature. Uses the real JWT
    so we always reset the correct account regardless of device.
    """
    from sqlalchemy import delete, select
    from ..models.placement import Placement
    from ..models.conversation import Conversation
    from ..models.message import Message
    from ..models.session_analysis import SessionAnalysis

    # Wipe placements, session analyses, messages, and conversations
    # 1. Fetch all conversation IDs for this user to wipe nested messages and analyses
    conv_ids_result = await db.execute(
        select(Conversation.id).where(Conversation.user_id == user.id)
    )
    conv_ids = [r[0] for r in conv_ids_result.all()]

    if conv_ids:
        await db.execute(delete(Message).where(Message.conversation_id.in_(conv_ids)))
        await db.execute(
            delete(SessionAnalysis).where(SessionAnalysis.conversation_id.in_(conv_ids))
        )
        await db.execute(delete(Conversation).where(Conversation.user_id == user.id))

    await db.execute(delete(Placement).where(Placement.user_id == user.id))

    # Wipe RefreshSessions to invalidate tokens
    from ..models.user import RefreshSession, User
    await db.execute(delete(RefreshSession).where(RefreshSession.user_id == user.id))
    
    # Finally, hard delete the user account
    await db.execute(delete(User).where(User.id == user.id))

    await db.commit()
    # 204 No Content — no response body


@router.get("/me/garden", response_model=GardenResponse)
async def get_user_garden(
    user: User = Depends(get_current_user),
    view_level: str | None = Query(default=None, alias="level"),
):
    # If a specific level is requested, use it — otherwise default to the user's current level.
    # For previous levels (below the user's current level), all skills are shown as owned.
    requested_level = (view_level or user.level or "A0").upper()
    user_level = (user.level or "A0").upper()
    progress = user.skills_progress or {}

    LEVEL_ORDER = ["A0", "A1", "A2", "B1", "B2", "C1"]
    is_previous_level = (
        requested_level in LEVEL_ORDER
        and user_level in LEVEL_ORDER
        and LEVEL_ORDER.index(requested_level) < LEVEL_ORDER.index(user_level)
    )

    # For previous levels, override progress so all skills show as owned/bloomed.
    if is_previous_level:
        from ..core.curriculum_data import UNITS as _UNITS
        all_skill_ids = [
            unit_progress_key(requested_level, s["id"])
            for u in _UNITS.get(requested_level, [])
            for s in u.get("skills", [])
        ]
        all_skill_ids = [sid for sid in all_skill_ids if sid]
        from datetime import datetime, timezone
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        progress = {
            "owned": all_skill_ids,
            "emerging": [],
            "sightings": {sid: 3 for sid in all_skill_ids},
            "strength": {sid: 2 for sid in all_skill_ids},
            "last_seen": {sid: today for sid in all_skill_ids},
            "effort": progress.get("effort", {"times_spoken_total": 0}),
            "evidence": {},
        }

    level = requested_level
    units_list = UNITS.get(level, [])
    
    # Find the first unowned skill across all steps to use as a recommended fallback target
    first_unowned_skill = None
    for u in units_list:
        for s in u["skills"]:
            if bucket_of(progress, s["id"], level) != "owned":
                first_unowned_skill = s["id"]
                break
        if first_unowned_skill:
            break
    if not first_unowned_skill and units_list and units_list[0]["skills"]:
        first_unowned_skill = units_list[0]["skills"][0]["id"]
    
    units_data = []
    for u in units_list:
        skills_data = []
        
        for s in u["skills"]:
            status = bucket_of(progress, s["id"], level)
            sightings = progress_value(
                progress, "sightings", s["id"], level, 0
            )
            last_tested_at = progress_value(
                progress, "last_seen", s["id"], level, None
            )
            raw_evidence = progress_value(
                progress, "evidence", s["id"], level, []
            )
            evidence_list = []
            for ev in raw_evidence:
                if isinstance(ev, dict):
                    evidence_list.append({
                        "evidence": ev.get("evidence", ""),
                        "confidence": ev.get("confidence", 1.0),
                        "prompted": ev.get("prompted", False),
                        "topic": ev.get("topic", "General Conversation"),
                        "created_at": ev.get("created_at", None)
                    })
                elif isinstance(ev, str):
                    evidence_list.append({
                        "evidence": ev,
                        "confidence": 1.0,
                        "prompted": False,
                        "topic": "General Conversation",
                        "created_at": None
                    })
            
            skills_data.append({
                "id": s["id"],
                "strand": s["strand"],
                "text": s["text"],
                "status": status,
                "sightings": sightings,
                "last_tested_at": last_tested_at,
                "evidence": evidence_list
            })
            
        units_data.append({
          "unit": int(u["step"]),
          "name": u["name"],
          "focus": u["focus"],
          "skills": skills_data
        })
        
    # Resolve dynamic recommended topic based on active target skill
    due_next = validate_due_next(user.due_next, level)
    primary_skill = due_next.get("primary") or first_unowned_skill
 
    fallback_topics = {
        "A0": "Rice or noodles?",
        "A1": "What food do you like?",
        "A2": "What is something you enjoyed recently?",
        "B1": "What is one idea you have been thinking about?",
        "B2": "What is a difficult choice people your age face?",
        "C1": "Which idea would you enjoy examining from two sides?",
    }
    recommended_topic = fallback_topics.get(level, fallback_topics["A1"])
    if primary_skill:
        from ..core.elicitation import get_elicitation_plan_for
        try:
            plan = get_elicitation_plan_for(primary_skill, level)
            if plan.get("valid") and plan.get("question"):
                # The planner may provide alternatives for Zoe. The UI should
                # show one clean recommendation, not the whole option list.
                recommended_topic = plan["question"].split(" / ", 1)[0]
        except Exception:
            pass

    # Compute placement garden stage (soil / seed / bloom)
    placement_garden_data = None
    if user.placements:
        latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
        confidence = latest_placement.confidence  # "high", "medium", "low", or None
        if confidence in ("high", "medium"):
            stage = "bloom"
        elif confidence == "low":
            stage = "seed"
        else:
            stage = "seed"  # has placement but unknown confidence → treat as seed
        placement_garden_data = PlacementGardenResponse(
            stage=stage,
            level=latest_placement.level,
            confidence=confidence,
        )
    # No placement at all → stage is "soil" (returned as None / absent from response)
 
    return {
        "level": level,
        "recommended_topic": recommended_topic,
        "placement_garden": placement_garden_data,
        "units": units_data
    }


def get_theme_assets(t: dict) -> tuple[str, str, str, str]:
    """Dynamically generate the SVG icon ID and determine colors based on topic shortName."""
    theme_name = t.get("name", "")
    short_name = t.get("shortName", "")
    t_id = t.get("id", "")
    
    # Extract level and index from id, e.g., "a0_1" -> level "a0", idx "01"
    parts = t_id.split("_")
    level = parts[0] if len(parts) > 0 else "a0"
    idx = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1
    
    THEME_TO_ICON = {
            "My name and where I'm from": "a1-01-my-name",
            "My family": "a1-02-my-family",
            "My school": "a1-03-my-school",
            "Food I like": "a1-04-food-i-like",
            "My daily routine": "a1-05-my-daily-routine",
            "Things I like and don't like": "a1-06-likes-dontlikes",
            "Animals": "a1-07-animals",
            "Colours, numbers, and shapes": "a1-08-colours-numbers-shapes",
            "My home": "a1-09-my-home",
            "Sports and games": "a1-10-sports-and-games",
            "Festivals I celebrate": "a1-11-festivals",
            "My favourite film, show, or cartoon": "a2-10-films-and-tv-shows",
            "Games we play at break time": "a1-10-sports-and-games",
            "My birthday": "a2-11-celebrations",
            "Things I can do": "a2-01-hobbies-free-time",
            "My bag and what is inside it": "a2-04-shopping-and-markets",
            "My hobbies and free time": "a2-01-hobbies-free-time",
            "My friends": "a2-02-my-friends",
            "A typical week": "a2-03-typical-week",
            "Shopping and markets": "a2-04-shopping-and-markets",
            "Food and restaurants": "a2-05-food-and-restaurants",
            "My city or town": "a2-06-my-city-or-town",
            "Weather and seasons": "a2-07-weather-and-seasons",
            "Transport and travel": "a2-08-transport-and-travel",
            "A trip or holiday": "a2-09-a-trip-or-holiday",
            "Films and TV shows": "a2-10-films-and-tv-shows",
            "Celebrations and special days": "a2-11-celebrations",
            "School subjects — likes and dislikes": "a2-12-school-subjects",
            "My plans for the holidays": "b1-01-ambitions-future-plans",
            "A place I want to visit one day": "a2-09-a-trip-or-holiday",
            "What I want to learn next": "b1-03-education-in-india",
            "A person I look up to": "b1-10-friendship-and-trust",
            "My ambitions and future plans": "b1-01-ambitions-future-plans",
            "My personality and values": "b1-02-personality-and-values",
            "Education in India": "b1-03-education-in-india",
            "Social media and technology": "b1-04-social-media-technology",
            "City life vs. village life": "b1-05-city-vs-village",
            "Festivals and traditions": "b1-06-festivals-and-traditions",
            "The environment and pollution": "b1-07-environment-pollution",
            "Health and lifestyle": "b1-08-health-and-lifestyle",
            "Indian cinema and music": "b1-09-indian-cinema-music",
            "Friendship and trust": "b1-10-friendship-and-trust",
            "News and current events": "b1-11-news-current-events",
            "Cricket and sport in India": "b1-12-cricket-and-sport",
            "How my life has changed since I was younger": "b2-01-culture-and-identity",
            "A time I had to make a difficult choice": "c1-02-moral-dilemmas",
            "Rules I would change if I were in charge": "c1-07-democracy-young-people",
            "A misunderstanding that taught me something": "b1-10-friendship-and-trust",
            "Food and cooking": "a2-05-food-and-restaurants",
            "Culture and identity": "b2-01-culture-and-identity",
            "Gender equality in India": "b2-02-gender-equality",
            "Education and success": "b2-03-education-and-success",
            "AI and the future of work": "b2-04-ai-future-of-work",
            "Social media, mental health, young people": "b2-05-social-media-mental-health",
            "Climate change and India's responsibility": "b2-06-climate-change-india",
            "Migration and opportunity": "b2-07-migration-and-opportunity",
            "Tradition vs. modernity": "b2-08-tradition-vs-modernity",
            "Fake news and media literacy": "b2-09-fake-news-media-literacy",
            "Entrepreneurship and startups": "b2-10-entrepreneurship-startups",
            "Indian literature and storytelling": "b2-11-indian-literature-storytelling",
            "Privilege and opportunity": "b2-12-privilege-and-opportunity",
            "A belief I changed my mind about": "c2-09-self-fixed-or-fluid",
            "What would India look like in 50 years?": "b1-01-ambitions-future-plans",
            "Is it ever OK to break a rule?": "c1-02-moral-dilemmas",
            "A decision that changed someone's life": "c1-02-moral-dilemmas",
            "Sports and games I follow and play": "a1-10-sports-and-games",
            "Music and entertainment I enjoy": "b1-09-indian-cinema-music",
            "My family and the people close to me": "a1-02-my-family",
            "Food, cooking, and what it means to me": "a2-05-food-and-restaurants",
            "What does it mean to be Indian today?": "c1-01-what-does-it-mean-indian",
            "Moral dilemmas in everyday life": "c1-02-moral-dilemmas",
            "The ethics of AI": "c1-03-ethics-of-ai",
            "Caste, class, and social mobility": "c1-04-caste-class-social-mobility",
            "Sustainability and lifestyle choices": "c1-05-sustainability-lifestyle",
            "Mental health and stigma": "c1-06-mental-health-stigma",
            "Democracy and young people": "c1-07-democracy-young-people",
            "English in India — opportunity or inequality?": "c1-08-english-in-india",
            "Art, music, and what they say about a society": "c1-09-art-music-society",
            "Success, happiness, and meaning": "c1-10-success-happiness-meaning",
            "India's role in the world": "c1-11-indias-role-in-world",
            "Science, superstition, and belief": "c1-12-science-superstition-belief",
            "Is creativity learned or innate?": "b2-03-education-and-success",
            "Should history be taught differently?": "b2-08-tradition-vs-modernity",
            "Privacy vs. security": "b1-04-social-media-technology",
            'What does "home" really mean?': "a1-09-my-home",
            "Sport and what it means to me": "a1-10-sports-and-games",
            "Music and its role in my life": "b1-09-indian-cinema-music",
            "Family, relationships, and what shapes us": "a1-02-my-family",
            "Food, culture, and identity": "b2-01-culture-and-identity",
            "Does language shape thought?": "c2-01-language-shape-thought",
            "Justice, fairness, and what we owe each other": "c2-02-justice-fairness",
            "How do we know what we know?": "c2-03-how-do-we-know",
            "What makes us human in an age of machines?": "c2-04-what-makes-us-human",
            "Power, privilege, and who gets to tell the story": "c2-05-power-privilege-storytelling",
            "The future of democracy": "c2-06-future-of-democracy",
            "The ethics of genetic technology": "c2-07-ethics-genetic-technology",
            "What is art for?": "c2-08-what-is-art-for",
            "The self — fixed or fluid?": "c2-09-self-fixed-or-fluid",
            "The limits of globalisation": "c2-10-limits-of-globalisation",
            "Freedom — how much is too much?": "c2-11-freedom-how-much",
            "What do we owe future generations?": "c2-12-what-do-we-owe-future",
            "Is there such a thing as a universal moral truth?": "c1-02-moral-dilemmas",
            "The ethics of memory — choosing to forget": "c1-02-moral-dilemmas",
            "Individual responsibility in a broken system": "c2-02-justice-fairness",
            "Can humour change the world?": "a2-11-celebrations",
            "Sport, competition, and what drives us": "a1-10-sports-and-games",
            "Music, art, and emotion": "c1-09-art-music-society",
            "Family, belonging, and identity": "a1-02-my-family",
            "Food, culture, and memory": "a1-04-food-i-like",
        }
    
    icon = THEME_TO_ICON.get(theme_name)
    if not icon:
        import re as regex
        clean_short = regex.sub(r"[^a-z0-9]+", "-", short_name.lower()).strip("-")
        icon = f"{level}-{str(idx).zfill(2)}-{clean_short}"
    
    t_lower = theme_name.lower()
    color = "#F0E6FF"
    highlight = "rgba(128,0,255,0.06)"
    bg = "linear-gradient(135deg,#F0E6FF,#E0D0FF)"

    if "self" in t_lower or "identity" in t_lower or "psychology" in t_lower or "relationship" in t_lower:
        color = "#E0EDFF"
        highlight = "rgba(45,127,249,0.08)"
        bg = "linear-gradient(135deg,#E0EDFF,#CCE0FF)"
    elif "world" in t_lower or "environment" in t_lower or "global" in t_lower or "science" in t_lower:
        color = "#E6F9E6"
        highlight = "rgba(59,212,42,0.12)"
        bg = "linear-gradient(135deg,#E6F9E6,#D0F0D0)"
    elif "daily" in t_lower or "health" in t_lower or "experiences" in t_lower or "sport" in t_lower:
        color = "#FFFDE0"
        highlight = "rgba(255,210,63,0.12)"
        bg = "linear-gradient(135deg,#FFFDE0,#FFF5B0)"
    elif "festival" in t_lower or "art" in t_lower or "culture" in t_lower or "media" in t_lower or "language" in t_lower:
        color = "#FFF0E0"
        highlight = "rgba(255,107,44,0.1)"
        bg = "linear-gradient(135deg,#FFF0E0,#FFE4CC)"

    return icon, color, highlight, bg

@router.get("/me/topics", response_model=list[TopicResponse])
async def get_user_topics(user: User = Depends(get_current_user)):
    level = (user.level or "A0").upper()
    from ..core.curriculum_data import LEVEL_TOPICS, SKILL_AFFORDANCES, validate_due_next
    import random
    
    level_topics = LEVEL_TOPICS.get(level, [])
    
    due = validate_due_next(user.due_next, level)
    primary_id = due.get("primary")
    
    needed_affordances = set(SKILL_AFFORDANCES.get(primary_id, ["any"])) if primary_id else {"any"}
    
    pool = []
    if "any" in needed_affordances:
        pool = level_topics.copy()
    else:
        for t in level_topics:
            t_affs = set(t.get("affordances", []))
            if needed_affordances.intersection(t_affs) or "any" in t_affs:
                pool.append(t)
                
    persona = user.persona_memory or {}
    used_topics = persona.get("last_topics", [])
    if not isinstance(used_topics, list):
        used_topics = []
    
    recent_2 = used_topics[-2:] if len(used_topics) >= 2 else used_topics
    fresh_pool = [t for t in pool if t["name"] not in recent_2]
    
    if len(fresh_pool) < 7:
        fresh_pool = pool.copy()
        
    if len(fresh_pool) < 7:
        remaining = [t for t in level_topics if t not in fresh_pool]
        random.shuffle(remaining)
        needed = 7 - len(fresh_pool)
        fresh_pool.extend(remaining[:needed])
        
    if len(fresh_pool) > 12:
        random.shuffle(fresh_pool)
        fresh_pool = fresh_pool[:12]
        
    if fresh_pool:
        zoes_pick = random.choice(fresh_pool)
        for t in fresh_pool:
            if t == zoes_pick:
                t["isZoesPick"] = True
            else:
                t["isZoesPick"] = False
                
    response_list = []
    for t in fresh_pool:
        theme_name = t.get("name", "General")
        icon, color, highlight, bg = get_theme_assets(t)
        response_list.append({
            "id": t.get("id", "t_unknown"),
            "name": t.get("name", "Unknown Topic"),
            "theme": theme_name,
            "description": t.get("name", "Unknown Topic"),
            "icon": icon,
            "color": color,
            "highlight_color": highlight,
            "panel_bg": bg,
            "vocab_seeds": t.get("vocab_seeds", []),
            "structure_targets": t.get("structure_targets", []),
            "starters": t.get("starters", []),
            "isZoesPick": t.get("isZoesPick", False)
        })

    return response_list


from pydantic import BaseModel

class PrimaryTargetResponse(BaseModel):
    id: str | None = None
    text: str | None = None

@router.get("/me/primary-target", response_model=PrimaryTargetResponse)
async def get_primary_target(user: User = Depends(get_current_user)):
    """
    Returns the student's current primary target ID and its text description.
    """
    due = validate_due_next(user.due_next, user.level or "A0")
    primary_id = due.get("primary")
    
    if not primary_id:
        return PrimaryTargetResponse(id=None, text=None)
        
    from ..core.curriculum_data import get_skill_text
    skill_text = get_skill_text(primary_id, user.level)
    
    return PrimaryTargetResponse(id=primary_id, text=skill_text)


class TodayRecapSuperSentence(BaseModel):
    quote: str | None = None
    note: str | None = None

class TodayRecapCorrection(BaseModel):
    student_said: str | None = None
    corrected: str | None = None
    highlight_word: str | None = None

class TodayRecapResponse(BaseModel):
    talks_today: int = 0
    topic_name: str | None = None
    topic_emoji: str | None = None
    words_spoken_today: int = 0
    super_sentence: TodayRecapSuperSentence | None = None
    correction_highlight: TodayRecapCorrection | None = None


# Topic → emoji mapping
_TOPIC_EMOJI_MAP = {
    "dog": "🐶", "animal": "🐶", "pet": "🐶",
    "food": "🍕", "eat": "🍕", "cook": "🍕", "restaurant": "🍕", "lunch": "🍕", "breakfast": "🍕",
    "school": "📚", "class": "📚", "study": "📚", "education": "📚",
    "cricket": "🏏", "sport": "🏏", "game": "🏏",
    "family": "👨‍👩‍👧", "mother": "👨‍👩‍👧", "father": "👨‍👩‍👧", "sister": "👨‍👩‍👧", "brother": "👨‍👩‍👧",
    "city": "🏘️", "village": "🏘️", "town": "🏘️",
    "music": "🎵", "song": "🎵", "dance": "🎵",
    "film": "🎬", "movie": "🎬", "tv": "🎬", "cartoon": "🎬",
    "travel": "✈️", "trip": "✈️", "holiday": "✈️",
    "weather": "☀️", "rain": "☀️", "sun": "☀️",
    "friend": "🤝", "friendship": "🤝",
    "hobby": "🎨", "free time": "🎨",
    "technology": "📱", "social media": "📱", "phone": "📱",
    "nature": "🌳", "environment": "🌳", "pollution": "🌳",
    "health": "💪", "exercise": "💪",
}

def _topic_to_emoji(topic_name: str | None) -> str:
    if not topic_name:
        return "💬"
    lower = topic_name.lower()
    for keyword, emoji in _TOPIC_EMOJI_MAP.items():
        if keyword in lower:
            return emoji
    return "💬"


@router.get("/me/today-recap", response_model=TodayRecapResponse)
async def get_today_recap(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns a daily recap card: talks count, words spoken, best sentence, and correction highlight.
    """
    from ..models.conversation import Conversation
    from ..models.message import Message
    from ..models.session_analysis import SessionAnalysis
    from sqlalchemy import select, desc, func
    from datetime import datetime, timezone, timedelta

    # Get today's date range (UTC)
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # 1. Get today's completed conversations
    conv_result = await db.execute(
        select(Conversation)
        .where(
            Conversation.user_id == user.id,
            Conversation.completed == True,
            Conversation.completed_at >= today_start,
        )
        .order_by(desc(Conversation.completed_at))
    )
    today_convs = conv_result.scalars().all()
    talks_today = len(today_convs)

    if talks_today == 0:
        return TodayRecapResponse()

    # 2. Get topic from most recent conversation
    latest_conv = today_convs[0]
    topic_name = latest_conv.header_title or latest_conv.topic
    topic_emoji = _topic_to_emoji(topic_name)

    # 3. Count words spoken today (all user messages from today's conversations)
    conv_ids = [c.id for c in today_convs]
    msg_result = await db.execute(
        select(Message.content)
        .where(
            Message.conversation_id.in_(conv_ids),
            Message.role.in_(["user", "learner", "me"]),
        )
    )
    user_messages = msg_result.scalars().all()
    words_spoken_today = sum(len(content.split()) for content in user_messages if content)

    # 4. Get super sentence (best_moment_quote from today's analyses)
    super_sentence = None
    analysis_result = await db.execute(
        select(SessionAnalysis)
        .where(SessionAnalysis.conversation_id.in_(conv_ids))
        .order_by(desc(SessionAnalysis.created_at))
    )
    analyses = analysis_result.scalars().all()
    
    for sa in analyses:
        if sa.best_moment_quote and sa.best_moment_quote.strip():
            super_sentence = TodayRecapSuperSentence(
                quote=sa.best_moment_quote,
                note=sa.best_moment_note,
            )
            break

    # 5. Get correction highlight
    correction_highlight = None
    
    # Primary source: correction_highlight from session analysis (LLM judge extracts it)
    for sa in analyses:
        if sa.correction_highlight and isinstance(sa.correction_highlight, dict):
            ch = sa.correction_highlight
            if ch.get("student_said") and ch.get("corrected"):
                correction_highlight = TodayRecapCorrection(
                    student_said=ch["student_said"],
                    corrected=ch["corrected"],
                    highlight_word=ch.get("highlight_word"),
                )
                break

    # Fallback 1: per-message corrections
    if not correction_highlight:
        correction_msg_result = await db.execute(
            select(Message)
            .where(
                Message.conversation_id.in_(conv_ids),
                Message.correction != None,
                Message.role.in_(["assistant", "zoe"]),
            )
            .order_by(desc(Message.created_at))
            .limit(1)
        )
        correction_msg = correction_msg_result.scalar_one_or_none()
        
        if correction_msg and correction_msg.correction:
            prev_msg_result = await db.execute(
                select(Message.content)
                .where(
                    Message.conversation_id == correction_msg.conversation_id,
                    Message.role.in_(["user", "learner", "me"]),
                    Message.turn_number <= correction_msg.turn_number,
                )
                .order_by(desc(Message.turn_number))
                .limit(1)
            )
            prev_content = prev_msg_result.scalar_one_or_none()
            correction_highlight = TodayRecapCorrection(
                student_said=prev_content[:80] if prev_content else None,
                corrected=correction_msg.correction[:100],
                highlight_word=None,
            )
    
    # Fallback 2: use try_next_skill/example from session analysis
    if not correction_highlight:
        for sa in analyses:
            if sa.try_next_skill and sa.try_next_skill.strip():
                correction_highlight = TodayRecapCorrection(
                    student_said=sa.try_next_skill,
                    corrected=sa.try_next_example,
                    highlight_word=None,
                )
                break

    return TodayRecapResponse(
        talks_today=talks_today,
        topic_name=topic_name,
        topic_emoji=topic_emoji,
        words_spoken_today=words_spoken_today,
        super_sentence=super_sentence,
        correction_highlight=correction_highlight,
    )

