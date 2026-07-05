from fastapi import APIRouter, Depends
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
        "grade": None
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
    if not fresh:
        fresh = list(valid_topics)
    import random
    random.shuffle(fresh)

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
    }
    ICON_BASE_URL = "https://ella.navgurukul.org/assets/topic-icons"

    def _topic_item(t):
        starters = t.get("starters", [])
        topic_id = t.get("id", "")
        icon_file = TOPIC_ICON_MAP.get(topic_id)
        return {
            "name": t["name"],
            "label": _make_label(t["name"]),
            "icon": icon_file,
            "starter": starters[0] if starters else None,
        }

    from ..schemas.user import NextTopics, NextTopicItem
    next_topics_obj = None
    if fresh and user.first_session_done:
        rec = _topic_item(fresh[0])
        alts = [_topic_item(t) for t in fresh[1:4]]
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
    
    # Fallback: if no conversation recap exists but placement was done, use placement highlight
    if user and user.placements:
        latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
        if latest_placement.highlight:
            return latest_placement.highlight
    
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


@router.get("/me/garden", response_model=GardenResponse)
async def get_user_garden(user: User = Depends(get_current_user)):
    level = user.level or "A0"
    progress = user.skills_progress or {}
    
    units_list = UNITS.get(level.upper(), [])
    
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



