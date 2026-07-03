"""FastAPI Router for outcomes-led ELLA Metrics Framework."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from ..core.database import get_db
from ..core.config import get_settings
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.session_analysis import SessionAnalysis
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_key(key: str = Query(..., alias="key")):
    settings = get_settings()
    if key != settings.admin_secret_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")


# ── Response Models ───────────────────────────────────────────────────────────

class MetricTrendPoint(BaseModel):
    date: str
    conversations: int
    turns_per_user: float


class TurnsToOwnOut(BaseModel):
    grammar: float
    fluency: float
    vocabulary: float


class RetentionOut(BaseModel):
    d1: float
    d7: float
    d30: float
    d1_eligible: int
    d7_eligible: int
    d30_eligible: int


class AdminMetricsResponse(BaseModel):
    total_users: int
    active_users_7d: int
    skills_gained_per_student_per_week: float
    turns_to_own: TurnsToOwnOut
    avg_turns_per_conversation: float
    activation_rate: float
    breadth_rate: float
    retention: RetentionOut
    daily_trends: list[MetricTrendPoint]


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.get("/metrics", response_model=AdminMetricsResponse)
async def admin_metrics(
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    cutoff_30d = now - timedelta(days=30)
    cutoff_7d = now - timedelta(days=7)

    # 1. Total Registered Users
    users_result = await db.execute(select(User))
    users = users_result.scalars().all()
    user_map = {u.id: u for u in users}
    total_users = len(users)

    # 2. Activation (At least 1 standard conversation done)
    activated_users = len([u for u in users if u.first_session_done])
    activation_rate = round(activated_users / max(total_users, 1) * 100, 1)

    # 3. Conversations (completed)
    convs_result = await db.execute(
        select(Conversation)
        .where(Conversation.completed == True)
        .order_by(Conversation.created_at.asc())
    )
    completed_convs = convs_result.scalars().all()

    # 4. Message counts (student turns only: user/learner role)
    msg_counts = await db.execute(
        select(
            Message.conversation_id,
            func.count().label("cnt")
        )
        .where(Message.role.in_(["user", "learner"]))
        .group_by(Message.conversation_id)
    )
    turns_map = {row.conversation_id: row.cnt for row in msg_counts}

    # 5. Average turns per conversation
    turns_list = [turns_map.get(c.id, 0) for c in completed_convs]
    avg_turns = round(sum(turns_list) / max(len(completed_convs), 1), 1)

    # 6. Active users in last 7 days
    active_users_7d_set = set()
    for c in completed_convs:
        if c.completed_at and c.completed_at >= cutoff_7d:
            active_users_7d_set.add(c.user_id)
    active_users_7d_count = len(active_users_7d_set)

    # 7. North Star (Skills Gained Per Student Per Week) & Breadth (skills in 2+ categories)
    sa_result = await db.execute(
        select(SessionAnalysis)
        .where(SessionAnalysis.created_at >= cutoff_7d)
    )
    sa_list = sa_result.scalars().all()

    conv_user_map = {c.id: c.user_id for c in completed_convs}
    total_gained_skills = 0
    user_gained_categories = {}  # user_id -> set of strands ("GRA", "VOC", "FLU")

    from ..core.curriculum_data import get_skill_strand

    for sa in sa_list:
        u_id = conv_user_map.get(sa.conversation_id)
        if not u_id:
            continue
        changes = sa.state_changes or []
        if not isinstance(changes, list):
            continue

        for chg in changes:
            if chg.get("to") == "owned":
                total_gained_skills += 1
                skill_id = chg.get("id")
                strand = get_skill_strand(skill_id)
                if u_id not in user_gained_categories:
                    user_gained_categories[u_id] = set()
                user_gained_categories[u_id].add(strand)

    skills_gained_per_student = round(total_gained_skills / max(active_users_7d_count, 1), 2)

    users_with_2plus_categories = len([u for u, strands in user_gained_categories.items() if len(strands) >= 2])
    breadth_rate = round(users_with_2plus_categories / max(active_users_7d_count, 1) * 100, 1)

    # 8. Learning Efficiency (Turns to Own a Skill)
    user_convs = {}
    for c in completed_convs:
        if c.user_id not in user_convs:
            user_convs[c.user_id] = []
        user_convs[c.user_id].append(c)

    all_sa_result = await db.execute(select(SessionAnalysis).order_by(SessionAnalysis.created_at.asc()))
    all_sa = all_sa_result.scalars().all()
    sa_map = {sa.conversation_id: sa for sa in all_sa}

    strand_turns = {"GRA": [], "FLU": [], "VOC": []}

    for u_id, c_list in user_convs.items():
        tracking_skills = {}  # skill_id -> accumulated_turns
        for c in c_list:
            turns_in_session = turns_map.get(c.id, 0)
            sa = sa_map.get(c.id)

            for skill_id in list(tracking_skills.keys()):
                tracking_skills[skill_id] += turns_in_session

            if sa and sa.state_changes:
                for chg in sa.state_changes:
                    skill_id = chg.get("id")
                    to_state = chg.get("to")
                    if to_state == "emerging":
                        tracking_skills[skill_id] = 0
                    elif to_state == "owned":
                        if skill_id in tracking_skills:
                            final_turns = tracking_skills.pop(skill_id) + turns_in_session
                            strand = get_skill_strand(skill_id)
                            if strand in strand_turns:
                                strand_turns[strand].append(final_turns)

    turns_to_own = TurnsToOwnOut(
        grammar=round(sum(strand_turns["GRA"]) / max(len(strand_turns["GRA"]), 1), 1) if strand_turns["GRA"] else 0.0,
        fluency=round(sum(strand_turns["FLU"]) / max(len(strand_turns["FLU"]), 1), 1) if strand_turns["FLU"] else 0.0,
        vocabulary=round(sum(strand_turns["VOC"]) / max(len(strand_turns["VOC"]), 1), 1) if strand_turns["VOC"] else 0.0,
    )

    # 9. Retention (D1 / D7 / D30 Cohorts)
    d1_eligible = 0
    d1_retained = 0
    d7_eligible = 0
    d7_retained = 0
    d30_eligible = 0
    d30_retained = 0

    user_active_days = {}
    for c in completed_convs:
        u = user_map.get(c.user_id)
        if not u or not c.completed_at:
            continue
        diff = (c.completed_at.date() - u.created_at.date()).days
        if c.user_id not in user_active_days:
            user_active_days[c.user_id] = set()
        user_active_days[c.user_id].add(diff)

    for u in users:
        days_since_signup = (now.date() - u.created_at.date()).days
        active_days = user_active_days.get(u.id, set())

        if days_since_signup >= 1:
            d1_eligible += 1
            if 1 in active_days or 2 in active_days:
                d1_retained += 1
        if days_since_signup >= 7:
            d7_eligible += 1
            if any(d in active_days for d in (6, 7, 8)):
                d7_retained += 1
        if days_since_signup >= 30:
            d30_eligible += 1
            if any(d in active_days for d in range(28, 33)):
                d30_retained += 1

    retention = RetentionOut(
        d1=round(d1_retained / max(d1_eligible, 1) * 100, 1) if d1_eligible else 0.0,
        d7=round(d7_retained / max(d7_eligible, 1) * 100, 1) if d7_eligible else 0.0,
        d30=round(d30_retained / max(d30_eligible, 1) * 100, 1) if d30_eligible else 0.0,
        d1_eligible=d1_eligible,
        d7_eligible=d7_eligible,
        d30_eligible=d30_eligible,
    )

    # 10. Daily Trends (last 30 days)
    daily_stats = {}
    for i in range(30):
        date_str = (now - timedelta(days=i)).strftime("%Y-%m-%d")
        daily_stats[date_str] = {"conversations": 0, "turns": 0, "active_users": set()}

    for c in completed_convs:
        if c.completed_at and c.completed_at >= cutoff_30d:
            date_str = c.completed_at.strftime("%Y-%m-%d")
            if date_str in daily_stats:
                daily_stats[date_str]["conversations"] += 1
                daily_stats[date_str]["turns"] += turns_map.get(c.id, 0)
                daily_stats[date_str]["active_users"].add(c.user_id)

    daily_trends = []
    for date_str in sorted(daily_stats.keys()):
        stats = daily_stats[date_str]
        active_count = len(stats["active_users"])
        turns_per_user = round(stats["turns"] / max(active_count, 1), 1)
        daily_trends.append(MetricTrendPoint(
            date=date_str,
            conversations=stats["conversations"],
            turns_per_user=turns_per_user
        ))

    return AdminMetricsResponse(
        total_users=total_users,
        active_users_7d=active_users_7d_count,
        skills_gained_per_student_per_week=skills_gained_per_student,
        turns_to_own=turns_to_own,
        avg_turns_per_conversation=avg_turns,
        activation_rate=activation_rate,
        breadth_rate=breadth_rate,
        retention=retention,
        daily_trends=daily_trends,
    )
