import re
import openpyxl
import os
import sys

def extract_vocab_seeds(topic_name, description):
    text = (topic_name + " " + description).lower()
    text = re.sub(r'[^\w\s-]', '', text)
    words = text.split()
    stopwords = {
        'and', 'or', 'but', 'the', 'a', 'an', 'in', 'on', 'at', 'to', 'for', 'with', 
        'of', 'about', 'from', 'by', 'is', 'are', 'was', 'were', 'am', 'be', 'been',
        'my', 'your', 'his', 'her', 'their', 'our', 'its', 'you', 'me', 'him', 'them',
        'us', 'i', 'he', 'she', 'they', 'we', 'it', 'this', 'that', 'these', 'those',
        'have', 'has', 'had', 'do', 'does', 'did', 'can', 'could', 'will', 'would',
        'should', 'must', 'may', 'might', 'introducing', 'talking', 'describing', 'saying',
        'naming', 'expressing', 'using', 'how', 'what', 'where', 'when', 'who', 'why',
        'yourself', 'family', 'members', 'people'
    }
    seeds = []
    for w in words:
        if len(w) > 3 and w not in stopwords and w not in seeds:
            seeds.append(w)
    defaults = ["conversation", "practice", "vocabulary", "english", "learning", "speaking"]
    for d in defaults:
        if len(seeds) < 8 and d not in seeds:
            seeds.append(d)
    return seeds[:8]

def get_structure_targets(level):
    lvl = level.upper()
    if lvl == "A1":
        return ["present simple", "basic adjectives", "simple sentences"]
    elif lvl == "A2":
        return ["past simple narration", "comparative adjectives", "going to future plans"]
    elif lvl == "B1":
        return ["present perfect", "first conditional", "expressing opinions with reasons"]
    elif lvl == "B2":
        return ["complex conditionals", "reported speech", "flexible active/passive voice"]
    elif lvl == "C1":
        return ["modal speculation/deduction", "participle clauses", "extended coherent narratives"]
    elif lvl == "C2":
        return ["figurative expressions", "idiomatic phrasing", "flexible registers"]
    return ["general conversation"]

def get_theme_assets(theme_name):
    t = (theme_name or "").lower()
    
    # 1. Icons
    icon = "💬"
    if "tech" in t: icon = "💻"
    elif "work" in t or "ambition" in t or "career" in t: icon = "💼"
    elif "science" in t or "knowledge" in t or "truth" in t: icon = "🔬"
    elif "self" in t or "identity" in t or "psychology" in t or "relationship" in t: icon = "👤"
    elif "daily" in t or "health" in t or "experiences" in t: icon = "⏰"
    elif "world" in t or "environment" in t or "global" in t: icon = "🌍"
    elif "sport" in t: icon = "🏏"
    elif "art" in t or "festival" in t or "culture" in t or "media" in t: icon = "🎬"
    elif "philosophy" in t or "ethic" in t or "value" in t or "society" in t or "power" in t or "politics" in t or "legacy" in t: icon = "⚖️"

    # 2. Colors matching design specs
    color = "#F0E6FF"
    highlight = "rgba(128,0,255,0.06)"
    bg = "linear-gradient(135deg,#F0E6FF,#E0D0FF)"

    if "self" in t or "identity" in t or "psychology" in t or "relationship" in t:
        # Blue
        color = "#E0EDFF"
        highlight = "rgba(45,127,249,0.08)"
        bg = "linear-gradient(135deg,#E0EDFF,#CCE0FF)"
    elif "world" in t or "environment" in t or "global" in t or "science" in t:
        # Green
        color = "#E6F9E6"
        highlight = "rgba(59,212,42,0.12)"
        bg = "linear-gradient(135deg,#E6F9E6,#D0F0D0)"
    elif "daily" in t or "health" in t or "experiences" in t or "sport" in t:
        # Yellow
        color = "#FFFDE0"
        highlight = "rgba(255,210,63,0.12)"
        bg = "linear-gradient(135deg,#FFFDE0,#FFF5B0)"
    elif "festival" in t or "art" in t or "culture" in t or "media" in t or "language" in t:
        # Orange
        color = "#FFF0E0"
        highlight = "rgba(255,107,44,0.1)"
        bg = "linear-gradient(135deg,#FFF0E0,#FFE4CC)"

    return icon, color, highlight, bg

def main():
    excel_path = './docs/Ella_Framework_Complete.xlsx'
    if not os.path.exists(excel_path):
        print(f"Error: Excel file not found at {excel_path}")
        sys.exit(1)

    print("Loading workbook...")
    wb = openpyxl.load_workbook(excel_path, data_only=True)

    # 1. Parse flat skills (CAT list)
    print("Parsing flat skills (CAT)...")
    CAT = []
    strand_map = {'Vocabulary': 'VOC', 'Grammar': 'GRA', 'Fluency': 'FLU'}
    
    for level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
        sheet = wb[level]
        current_strand = None
        counts = {'VOC': 0, 'GRA': 0, 'FLU': 0}
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            section, subsection, content = row[0], row[1], row[2]
            if section in strand_map:
                current_strand = strand_map[section]
            
            if subsection == 'I can statement' and content:
                counts[current_strand] += 1
                skill_id = f"{level}-{current_strand}-{counts[current_strand]:02d}"
                CAT.append([skill_id, level, current_strand, content.strip()])
    
    print(f"✓ Parsed {len(CAT)} flat skills in total.")

    # 2. Parse transition units (UNITS dict)
    print("Parsing transition units...")
    UNITS = {}
    transitions = [
        ('A1', 'A1→A2'),
        ('A2', 'A2→B1'),
        ('B1', 'B1→B2'),
        ('B2', 'B2→C1'),
        ('C1', 'C1→C2')
    ]
    
    for level, sheetname in transitions:
        sheet = wb[sheetname]
        units_list = []
        current_unit = None
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            col0, col1, col2, col3 = row[0], row[1], row[2], row[3]
            
            if col0 and str(col0).startswith('Step '):
                step_num = str(col0).replace('Step ', '').strip()
                if step_num in ('1', '2', '3', '4'):
                    current_unit = {
                        'step': step_num,
                        'name': col1.strip() if col1 else '',
                        'focus': '',
                        'skills': []
                    }
                    units_list.append(current_unit)
                else:
                    current_unit = None
                
            if current_unit:
                if col2 == 'Focus' and col3:
                    current_unit['focus'] = col3.strip()
                elif col2 == 'I can statement' and col3:
                    strand_name = col1.strip() if col1 else ''
                    strand_abbr = strand_map.get(strand_name)
                    strand_count = sum(1 for s in current_unit['skills'] if s['strand'] == strand_abbr) + 1
                    skill_id = f"U{current_unit['step']}-{strand_abbr}-{strand_count:02d}"
                    current_unit['skills'].append({
                        'id': skill_id,
                        'strand': strand_abbr,
                        'text': col3.strip()
                    })
        UNITS[level] = units_list
    # Add empty list for C2
    UNITS['C2'] = []
    
    total_steps = sum(len(ulist) for ulist in UNITS.values())
    print(f"✓ Parsed {total_steps} unit steps across levels.")

    # 3. Parse Topics
    print("Parsing topics...")
    LEVEL_TOPICS = {}
    
    for level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
        sheetname = f"Topics — {level}"
        sheet = wb[sheetname]
        topics_list = []
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            col0, col1, col2, col3, col4, col5 = row[0], row[1], row[2], row[3], row[4], row[5]
            
            # Skip header or level banner rows
            if col0 is None or "Topics" in str(col0) or "Headline" in str(col0) or "can talk" in str(col0) or col0 == "#":
                continue
                
            topic_num = str(col0).strip()
            theme = col1.strip() if col1 else "General"
            topic_name = col2.strip() if col2 else ""
            desc = col3.strip() if col3 else ""
            starters_raw = col5.strip() if col5 else ""
            
            # Clean up starters list (split by newline and remove bullets)
            starters = []
            for s in starters_raw.split("\n"):
                s_clean = re.sub(r'^[•\-\*\s]+', '', s).strip()
                if s_clean:
                    starters.append(s_clean)
            
            # Generate assets
            icon, color, highlight, panel_bg = get_theme_assets(theme)
            vocab = extract_vocab_seeds(topic_name, desc)
            structs = get_structure_targets(level)
            
            # Topic ID
            topic_id = re.sub(r'[^a-z0-9]', '_', topic_name.lower())
            topic_id = re.sub(r'_+', '_', topic_id).strip('_')
            
            topics_list.append({
                "id": topic_id,
                "name": topic_name,
                "theme": theme,
                "description": desc,
                "icon": icon,
                "color": color,
                "highlight_color": highlight,
                "panel_bg": panel_bg,
                "vocab_seeds": vocab,
                "structure_targets": structs,
                "starters": starters
            })
            
        LEVEL_TOPICS[level] = topics_list
    
    total_topics = sum(len(tlist) for tlist in LEVEL_TOPICS.values())
    print(f"✓ Parsed {total_topics} topics across levels.")

    # 4. Generate Python Code
    print("Writing curriculum_data.py...")
    
    py_code = f"""# Auto-generated from Ella_Framework_Complete.xlsx
# Do not modify manually. Regenerate using parse_framework.py

from datetime import datetime

# Level headlines
HEADLINES = {{
    "A1": "I can talk about myself and things around me.",
    "A2": "I can have simple conversations on everyday topics.",
    "B1": "I can share my opinions and tell stories in English.",
    "B2": "I can discuss, argue, and express myself fluently on a wide range of topics.",
    "C1": "I can express myself clearly and confidently on complex, abstract, and unfamiliar topics — with very little hesitation.",
    "C2": "I can communicate on any topic, with anyone, in any situation — with accuracy, flexibility, and no hesitation."
}}

# Flat CEFR skills
CAT = {repr(CAT)}

# Transition Step-by-Step Curriculum
UNITS = {repr(UNITS)}

# Level-aligned Conversation Topics
LEVEL_TOPICS = {repr(LEVEL_TOPICS)}

# Maps for quick lookup
SKILLS = {{item[0]: {{"level": item[1], "strand": item[2], "text": item[3]}} for item in CAT}}

UNIT_SKILLS = {{}}
for lvl, u_list in UNITS.items():
    for u in u_list:
        for s in u["skills"]:
            UNIT_SKILLS[s["id"]] = {{
                "id": s["id"],
                "strand": s["strand"],
                "text": s["text"],
                "step": u["step"],
                "step_name": u["name"],
                "level": lvl
            }}

STRANDS = {{
    "VOC": "Vocabulary",
    "GRA": "Grammar",
    "FLU": "Fluency"
}}

OWN_BAR = {{
    "A1": 0.55,
    "A2": 0.60,
    "B1": 0.68,
    "B2": 0.72,
    "C1": 0.75,
    "C2": 0.78
}}

FLOOR = 0.3
SIGHTINGS_TO_OWN = 2

def get_skill_text(skill_id: str) -> str:
    if skill_id in SKILLS:
        return SKILLS[skill_id]["text"]
    if skill_id in UNIT_SKILLS:
        return UNIT_SKILLS[skill_id]["text"]
    return skill_id

def get_skill_strand(skill_id: str) -> str:
    if skill_id in SKILLS:
        return SKILLS[skill_id]["strand"]
    if skill_id in UNIT_SKILLS:
        return UNIT_SKILLS[skill_id]["strand"]
    return "VOC"

def own_bar(level: str) -> float:
    return OWN_BAR.get(level.upper(), 0.70)

def bucket_of(progress: dict, skill_id: str) -> str:
    owned = progress.get("owned", [])
    emerging = progress.get("emerging", [])
    if skill_id in owned:
        return "owned"
    if skill_id in emerging:
        return "emerging"
    return "locked"

def unit_complete(progress: dict, u: dict) -> bool:
    for s in u["skills"]:
        b = bucket_of(progress, s["id"])
        # FLU and VOC must be owned
        if s["strand"] in ("FLU", "VOC") and b != "owned":
            return False
        # GRA must be at least emerging (emerging or owned)
        if s["strand"] == "GRA" and b == "locked":
            return False
    return True

def active_step(progress: dict, level: str = None) -> dict | None:
    if level is None:
        level = progress.get("level", "A1")
    units_list = UNITS.get(level.upper(), UNITS.get("A1", []))
    for u in units_list:
        if not unit_complete(progress, u):
            return u
    return None

def due_unit(progress: dict, level: str = None) -> dict:
    u = active_step(progress, level)
    if not u:
        return {{"picks": [], "u": None}}
    
    # Picks are skills in this unit that are NOT yet owned
    picks = []
    for s in u["skills"]:
        if bucket_of(progress, s["id"]) != "owned":
            picks.append({{"id": s["id"], "why": f"active unit: Step {{u['step']}} - {{u['name']}}"}} )
    
    return {{"picks": picks, "u": u}}

def due_skill(progress: dict, level: str) -> list[dict]:
    # Filter flat skills for this level
    lvl_skills = [s for s in CAT if s[1] == level.upper()]
    picks = []
    why = []
    
    # 1. Finish what is started (emerging flat skills at this level)
    emerging_ids = progress.get("emerging", [])
    em = next((sid for sid in emerging_ids if any(s[0] == sid and s[1] == level.upper() for s in CAT)), None)
    if em:
        picks.append(em)
        why.append("finish what is started (emerging)")
        
    # 2. Balance strands: find the strand with the fewest owned skills at this level, and pick the first locked skill in that strand
    owned_ids = progress.get("owned", [])
    so = {{"VOC": 0, "GRA": 0, "FLU": 0}}
    for sid in owned_ids:
        s_meta = SKILLS.get(sid)
        if s_meta and s_meta["level"] == level.upper():
            so[s_meta["strand"]] += 1
            
    # Sort strands by number of owned skills
    order = sorted(so.keys(), key=lambda k: so[k])
    
    for st in order:
        # Find first locked skill of this strand at this level
        next_locked = next((s[0] for s in lvl_skills if s[2] == st and bucket_of(progress, s[0]) == "locked" and s[0] not in picks), None)
        if next_locked:
            picks.append(next_locked)
            why.append(f"open weakest strand: {{STRANDS[st]}}")
            break
            
    # 3. Familiar favourite (owned flat skill at this level)
    fav = next((sid for sid in owned_ids if any(s[0] == sid and s[1] == level.upper() for s in CAT) and sid not in picks), None)
    if fav:
        picks.append(fav)
        why.append("familiar favourite (owned)")
        
    return [{{"id": picks[i], "why": why[i]}} for i in range(len(picks))]

def targets_list_for(progress: dict, model: str, level: str) -> list[str]:
    # Returns the target skill IDs
    if model == "unit":
        picks = due_unit(progress, level)["picks"]
    else:
        picks = due_skill(progress, level)
    return [p["id"] for p in picks]

def apply_merge(progress: dict, scores: list[dict], level: str) -> tuple[dict, list[dict]]:
    # Clone progression dict to avoid side-effects
    import copy
    p = copy.deepcopy(progress)
    
    # Ensure default containers exist
    if "owned" not in p: p["owned"] = []
    if "emerging" not in p: p["emerging"] = []
    if "sightings" not in p: p["sightings"] = {{}}
    if "strength" not in p: p["strength"] = {{}}
    if "last_seen" not in p: p["last_seen"] = {{}}
    if "effort" not in p: p["effort"] = {{"times_spoken_total": 0}}
    
    changes = []
    bar = own_bar(level)
    
    for sc in scores:
        skill_id = sc["id"]
        confidence = sc.get("confidence", 0.0)
        prompted = sc.get("prompted", False)
        
        prior = bucket_of(p, skill_id)
        next_state = prior
        
        qualifies = confidence >= bar
        
        if confidence >= FLOOR:
            p["last_seen"][skill_id] = datetime.now().isoformat()[:10]
            if qualifies:
                p["sightings"][skill_id] = p["sightings"].get(skill_id, 0) + 1
            if not prompted:
                p["strength"][skill_id] = p["strength"].get(skill_id, 0) + 1
                
        sightings = p["sightings"].get(skill_id, 0)
        unprompted_count = p["strength"].get(skill_id, 0)
        
        # Effort path for A1/A2
        effort_path = (level.upper() in ("A1", "A2")) and (unprompted_count + sightings >= 3) and (confidence >= FLOOR)
        
        if confidence < FLOOR:
            next_state = prior
        elif prior == "locked":
            next_state = "emerging"
        elif prior == "emerging" and (sightings >= SIGHTINGS_TO_OWN or effort_path):
            next_state = "owned"
            
        if next_state != prior:
            changes.append({{"id": skill_id, "from": prior, "to": next_state, "name": get_skill_text(skill_id)}})
            if prior == "locked":
                p["emerging"].append(skill_id)
            if prior == "emerging" and next_state == "owned":
                if skill_id in p["emerging"]:
                    p["emerging"].remove(skill_id)
                if skill_id not in p["owned"]:
                    p["owned"].append(skill_id)
                    
    return p, changes

# Elicitation Mapping & Prompting
ELICITATION_BY_FUNCTION = {{
    "describe": {{
        "move": "Ask the learner to describe a real or imagined place/person/picture. Do not ask only yes/no.",
        "question": "Tell me about your room/park/classroom. What can you see? Who is there? What are they doing?",
        "fallback": "If they give one word, ask: Good. Say one more thing. What colour/size is it? Where is it?",
        "evidence": "3 details, simple adjectives, or 2-4 connected fragments/sentences."
    }},
    "present_continuous": {{
        "move": 'Create a "right now / picture" moment so the learner can use is/are + -ing.',
        "question": "Imagine a picture. What is the boy doing? What are the people doing?",
        "fallback": "If stuck, offer a frame: He is ___. They are ___.",
        "evidence": "Any meaningful present-continuous attempt, even with errors: “boy running”, “she is play”."
    }},

    "past": {{
        "move": "Ask about yesterday/last weekend and invite a tiny sequence.",
        "question": "What did you do yesterday? Tell me two things.",
        "fallback": "If they answer one word, ask: First? Then?",
        "evidence": "Past-time expression or past event, even if tense is imperfect."
    }},
    "opinion": {{
        "move": "Ask preference plus reason; keep it personal and easy.",
        "question": "Which do you like more? Why?",
        "fallback": "Offer a frame: I like ___ because ___.",
        "evidence": "Opinion word/preference plus any reason."
    }},
    "future": {{
        "move": "Ask about tomorrow/weekend plans using going to/will/want to.",
        "question": "What will you do tomorrow or this weekend?",
        "fallback": "Offer a frame: I am going to ___.",
        "evidence": "Future plan/intention, even with errors."
    }},
    "sequence": {{
        "move": "Ask for beginning-middle-end of a small story.",
        "question": "Tell me what happened first, then, and at the end.",
        "fallback": "Ask one step at a time: First? Then?",
        "evidence": "2-3 ordered events or connectors."
    }},
    "self_intro": {{
        "move": "Ask for name, age, and where they are from in a friendly first-meeting flow.",
        "question": "What is your name? How old are you? Where are you from?",
        "fallback": "If they answer only name, continue gently: Nice to meet you. How old are you?",
        "evidence": "Gives name, age, or hometown."
    }},
    "everyday": {{
        "move": "Ask about a familiar routine/object/person and gently extend.",
        "question": "Tell me about it. What do you do? Who is with you?",
        "fallback": "If one word, ask a choice question then one follow-up.",
        "evidence": "Relevant answer that keeps the exchange alive."
    }}
}}

def elicitation_function(skill_id: str) -> str:
    # 1. Check unit skills
    u = UNIT_SKILLS.get(skill_id)
    if u:
        step = str(u.get("step", ""))
        strand = u.get("strand", "")
        if step == '1':
            return 'present_continuous' if strand == 'GRA' else 'describe'
        elif step == '2':
            return 'past'
        elif step == '3':
            return 'opinion'
        elif step == '4':
            return 'future'
        elif step == '5':
            return 'sequence'
            
    # 2. Check flat skills
    text = get_skill_text(skill_id).lower()
    if any(k in text for k in ['age', "where i'm from", "where i am from"]):
        return 'self_intro'
    if any(k in text for k in ['past', 'yesterday', 'story']):
        return 'past'
    if any(k in text for k in ['opinion', 'prefer', 'because', 'reason']):
        return 'opinion'
    if any(k in text for k in ['future', 'plan', 'will']):
        return 'future'
    if any(k in text for k in ['describe', 'adjective', 'look like']):
        return 'describe'
    return 'everyday'

def get_elicitation_plan_for(skill_id: str) -> dict:
    fn = elicitation_function(skill_id)
    plan = ELICITATION_BY_FUNCTION.get(fn, ELICITATION_BY_FUNCTION["everyday"])
    return {{
        "id": skill_id,
        "fn": fn,
        "skill": get_skill_text(skill_id),
        **plan
    }}

def plan_text(ids: list[str]) -> str:
    if not ids:
        return "No specific target. Keep the learner talking and listen for interests."
    lines = []
    for i, skill_id in enumerate(ids):
        p = get_elicitation_plan_for(skill_id)
        role = "PRIMARY" if i == 0 else "WATCH"
        lines.append(
            f"{{role}} {{skill_id}} ({{p['fn']}})\\n"
            f"- Skill: {{p['skill']}}\\n"
            f"- Elicitation move: {{p['move']}}\\n"
            f"- Strong question: {{p['question']}}\\n"
            f"- If short/stuck: {{p['fallback']}}\\n"
            f"- Judgeable evidence: {{p['evidence']}}"
        )
    return "\\n\\n".join(lines)
"""

    out_path = './backend/app/core/curriculum_data.py'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(py_code)
    
    print("Success: Generated curriculum_data.py successfully!")

if __name__ == '__main__':
    main()
