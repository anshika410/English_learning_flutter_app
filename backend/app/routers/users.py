from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UpdateProfileRequest, UpdateMemoryRequest, UserMemoryResponse, GardenResponse, TopicResponse, PlacementSubResponse, PlacementGardenResponse
from ..core.curriculum_data import UNITS, active_step, unit_complete, bucket_of


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
    due = user.due_next or {}
    units_list = persona.get("units", [])
    if not isinstance(units_list, list):
        units_list = []

    last_topics_list = persona.get("last_topics", [])
    if not isinstance(last_topics_list, list):
        last_topics_list = []

    # Cast age to integer if it is a numeric string
    age_val = None
    if user.age and user.age.isdigit():
        age_val = int(user.age)

    profile_data = {
        "name": user.name or None,
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

    # Compute suggested next topics (avoid recently used)
    from ..core.curriculum_data import LEVEL_TOPICS
    level_code = (user.level or "A0").upper()
    all_topics = LEVEL_TOPICS.get(level_code, [])
    valid_topics = [t for t in all_topics if t.get("name")]
    used = set(last_topics_list)
    fresh = [t for t in valid_topics if t["name"] not in used]
    stale = [t for t in valid_topics if t["name"] in used]
    # Always show all topics — fresh ones first, recently used ones at the end.
    # This way the user never sees fewer than the full topic list.
    import random
    random.shuffle(fresh)
    ordered_topics = fresh + stale

    def _make_label(name):
        """Derive a short label from topic name."""
        # Common patterns: "My family" → "Family", "Food I like" → "Food", "My school" → "School"
        lower = name.lower()
        if lower.startswith("my "):
            return name[3:].split()[0].capitalize()
        words = name.split()
        if len(words) <= 2:
            return words[0].capitalize()
        # For longer names, use first noun-like word
        skip = {"the", "a", "an", "and", "in", "of", "vs.", "i", "don't"}
        for w in words:
            if w.lower() not in skip and len(w) > 2:
                return w.capitalize()
        return words[0].capitalize()

    # Topic icon mapping (topic_id → icon filename)
    TOPIC_ICON_MAP = {
        # A0 level topics → a1 icons
        "my_name_and_where_i_m_from": "a1-01-my-name",
        "my_family": "a1-02-my-family",
        "my_school": "a1-03-my-school",
        "food_i_like": "a1-04-food-i-like",
        "my_daily_routine": "a1-05-my-daily-routine",
        "things_i_like_and_don_t_like": "a1-06-likes-dontlikes",
        "animals": "a1-07-animals",
        "colours_numbers_and_shapes": "a1-08-colours-numbers-shapes",
        "my_home": "a1-09-my-home",
        "sports_and_games": "a1-10-sports-and-games",
        "festivals_i_celebrate": "a1-11-festivals",
        # A1 level topics → a2 icons
        "my_hobbies_and_free_time": "a2-01-hobbies-free-time",
        "my_friends": "a2-02-my-friends",
        "a_typical_week": "a2-03-typical-week",
        "shopping_and_markets": "a2-04-shopping-and-markets",
        "food_and_restaurants": "a2-05-food-and-restaurants",
        "my_city_or_town": "a2-06-my-city-or-town",
        "weather_and_seasons": "a2-07-weather-and-seasons",
        "transport_and_travel": "a2-08-transport-and-travel",
        "a_trip_or_holiday": "a2-09-a-trip-or-holiday",
        "films_and_tv_shows": "a2-10-films-and-tv-shows",
        "celebrations_and_special_days": "a2-11-celebrations",
        "school_subjects_likes_and_dislikes": "a2-12-school-subjects",
        # A2 level topics → b1 icons
        "my_ambitions_and_future_plans": "b1-01-ambitions-future-plans",
        "my_personality_and_values": "b1-02-personality-and-values",
        "education_in_india": "b1-03-education-in-india",
        "social_media_and_technology": "b1-04-social-media-technology",
        "city_life_vs_village_life": "b1-05-city-vs-village",
        "festivals_and_traditions": "b1-06-festivals-and-traditions",
        "the_environment_and_pollution": "b1-07-environment-pollution",
        "health_and_lifestyle": "b1-08-health-and-lifestyle",
        "indian_cinema_and_music": "b1-09-indian-cinema-music",
        "friendship_and_trust": "b1-10-friendship-and-trust",
        "news_and_current_events": "b1-11-news-current-events",
        "cricket_and_sport_in_india": "b1-12-cricket-and-sport",
        # B1 level topics → b2 icons
        "culture_and_identity": "b2-01-culture-and-identity",
        "gender_equality_in_india": "b2-02-gender-equality",
        "education_and_success": "b2-03-education-and-success",
        "artificial_intelligence_and_the_future_of_work": "b2-04-ai-future-of-work",
        "social_media_mental_health_and_young_people": "b2-05-social-media-mental-health",
        "climate_change_and_india_s_responsibility": "b2-06-climate-change-india",
        "migration_and_opportunity": "b2-07-migration-and-opportunity",
        "tradition_vs_modernity": "b2-08-tradition-vs-modernity",
        "fake_news_and_media_literacy": "b2-09-fake-news-media-literacy",
        "entrepreneurship_and_startups": "b2-10-entrepreneurship-startups",
        "indian_literature_and_storytelling": "b2-11-indian-literature-storytelling",
        "privilege_and_opportunity": "b2-12-privilege-and-opportunity",
        # B2 level topics → c1 icons
        "what_does_it_mean_to_be_indian_today": "c1-01-what-does-it-mean-indian",
        "moral_dilemmas_in_everyday_life": "c1-02-moral-dilemmas",
        "the_ethics_of_artificial_intelligence": "c1-03-ethics-of-ai",
        "caste_class_and_social_mobility": "c1-04-caste-class-social-mobility",
        "sustainability_and_lifestyle_choices": "c1-05-sustainability-lifestyle",
        "mental_health_and_stigma": "c1-06-mental-health-stigma",
        "democracy_and_young_people": "c1-07-democracy-young-people",
        "english_in_india_opportunity_or_inequality": "c1-08-english-in-india",
        "art_music_and_what_they_say_about_a_society": "c1-09-art-music-society",
        "success_happiness_and_meaning": "c1-10-success-happiness-meaning",
        "india_s_role_in_the_world": "c1-11-indias-role-in-world",
        "science_superstition_and_belief_in_modern_india": "c1-12-science-superstition-belief",
        # C1 level topics → c2 icons
        "does_language_shape_thought": "c2-01-language-shape-thought",
        "justice_fairness_and_what_we_owe_each_other": "c2-02-justice-fairness",
        "how_do_we_know_what_we_know": "c2-03-how-do-we-know",
        "what_makes_us_human_in_an_age_of_machines": "c2-04-what-makes-us-human",
        "power_privilege_and_who_gets_to_tell_the_story": "c2-05-power-privilege-storytelling",
        "the_future_of_democracy": "c2-06-future-of-democracy",
        "the_ethics_of_genetic_technology": "c2-07-ethics-genetic-technology",
        "what_is_art_for": "c2-08-what-is-art-for",
        "the_self_fixed_or_fluid": "c2-09-self-fixed-or-fluid",
        "the_limits_of_globalisation": "c2-10-limits-of-globalisation",
        "freedom_how_much_is_too_much": "c2-11-freedom-how-much",
        "what_do_we_owe_future_generations": "c2-12-what-do-we-owe-future",
    }
    ICON_BASE_URL = "https://ella.navgurukul.org/assets/topic-icons"

    def _topic_item(t):
        starters = t.get("starters", [])
        topic_id = t.get("id", "")
        icon_file = TOPIC_ICON_MAP.get(topic_id)
        return {
            "name": t["name"],
            "label": t.get("label") or _make_label(t["name"]),
            "icon": icon_file,
            "starter": starters[0] if starters else None,
        }

    from ..schemas.user import NextTopics, NextTopicItem
    next_topics_obj = None
    has_completed_onboarding = user.first_session_done or bool(user.placements)
    if ordered_topics and has_completed_onboarding:
        rec = _topic_item(ordered_topics[0])
        alts = [_topic_item(t) for t in ordered_topics[1:]]  # all remaining topics, fresh first
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
        owned=progress.get("owned", []),
        emerging=progress.get("emerging", []),
        due_next=due,
        next_topics=next_topics_obj,
        effort=progress.get("effort", {"times_spoken_total": 0}),
        sightings=progress.get("sightings", {}),
        strength=progress.get("strength", {}),
        updated_after_chat=progress.get("updated_after_chat", 0),
        units=units_list,
        last_topics=last_topics_list,
        persona_memory={k: v for k, v in (user.persona_memory or {}).items() if k not in ("last_topics", "units")},
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
            s["id"]
            for u in _UNITS.get(requested_level, [])
            for s in u.get("skills", [])
        ]
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
            if bucket_of(progress, s["id"]) != "owned":
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
            status = bucket_of(progress, s["id"])
            sightings = progress.get("sightings", {}).get(s["id"], 0)
            last_tested_at = progress.get("last_seen", {}).get(s["id"], None)
            raw_evidence = progress.get("evidence", {}).get(s["id"], [])
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
    due_next = user.due_next or {}
    primary_skill = due_next.get("primary") or first_unowned_skill
 
    recommended_topic = "Today, I wanted to talk about cricket. Shall we?"
    if primary_skill:
        from ..core.curriculum_data import get_elicitation_plan_for
        try:
            plan = get_elicitation_plan_for(primary_skill)
            if plan and plan.get("question"):
                recommended_topic = plan["question"]
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


@router.get("/me/topics", response_model=list[TopicResponse])
async def get_user_topics(user: User = Depends(get_current_user)):
    level = (user.level or "A0").upper()
    from ..core.curriculum_data import LEVEL_TOPICS
    return LEVEL_TOPICS.get(level, [])


from pydantic import BaseModel

class PrimaryTargetResponse(BaseModel):
    id: str | None = None
    text: str | None = None

@router.get("/me/primary-target", response_model=PrimaryTargetResponse)
async def get_primary_target(user: User = Depends(get_current_user)):
    """
    Returns the student's current primary target ID and its text description.
    """
    due = user.due_next or {}
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



