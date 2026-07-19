"""Level-aware elicitation plans for curriculum skill targets.

This module is intentionally separate from auto-generated curriculum_data.py.
It derives a communicative elicitation function from the actual skill text,
not from the unit step number. Step numbers mean different things at
different levels.
"""

from __future__ import annotations
import logging

from .curriculum_data import SKILLS, UNITS


PLANS = {
    "naming": {
        "move": "Invite the learner to identify or name one concrete item they can see, know, or choose.",
        "question": "What is it? / What colour is it? / Which animal or object?",
        "fallback": "Narrow to two choices, then offer the first word of a phrase.",
        "evidence": "The learner independently names or selects the relevant word or phrase.",
    },
    "articles": {
        "move": "Create a natural naming moment where a short noun phrase fits.",
        "question": "What is this? / Which bag do you mean?",
        "fallback": "Offer the noun and leave the article open: '___ cat.'",
        "evidence": "A meaningful noun phrase using a/the, even if article choice is not fully stable.",
    },
    "self_intro": {
        "move": "Use a friendly first-meeting exchange and ask for one personal fact at a time.",
        "question": "What should I call you? / How old are you? / Who is in your family?",
        "fallback": "Offer a sentence beginning such as 'My name is...' or 'I am...'.",
        "evidence": "The learner gives a truthful name, age, family role, or short introduction.",
    },
    "identity_state": {
        "move": "Ask neutrally about a truthful present identity, feeling, or state; do not guess it for the learner.",
        "question": "How do you feel now?",
        "fallback": "Offer familiar words plus 'or something else', then a frame: 'I am...' or 'I am not...'.",
        "evidence": "A truthful I am / I am not attempt. Negation counts fully.",
    },
    "possession": {
        "move": "Ask about one familiar possession, pet, or family relationship without assuming it exists.",
        "question": "Have you got a pet? / What have you got in your bag?",
        "fallback": "Offer yes/no plus a frame: 'I have got...' or 'I haven't got...'.",
        "evidence": "A truthful have got / haven't got attempt or equivalent possession meaning.",
    },
    "preference": {
        "move": "Invite a real preference between familiar options, then allow a personal alternative.",
        "question": "Do you like rice or noodles? / What food do you like?",
        "fallback": "Offer a choice, then 'I like...' or 'I don't like...'.",
        "evidence": "The learner expresses a genuine like, dislike, or preference.",
    },
    "joining": {
        "move": "Build from one item the learner already named and invite one more connected item.",
        "question": "You like cats. What else do you like?",
        "fallback": "Offer the frame: 'I like ___ and ___.'.",
        "evidence": "Two meaningful ideas joined with and or another target connector.",
    },
    "contrast": {
        "move": "Invite two true ideas that differ so a contrast word is useful.",
        "question": "What do you like but not enjoy doing?",
        "fallback": "Offer only the connector frame: 'I like ___, but...'.",
        "evidence": "Two meaningful ideas connected with but, although, however, even though, or the target contrast form.",
    },
    "frequency": {
        "move": "Ask how often one familiar real action happens.",
        "question": "What do you usually do after school?",
        "fallback": "Offer one frequency choice such as always, sometimes, or never.",
        "evidence": "A meaningful use of a frequency word connected to a real action.",
    },
    "routine": {
        "move": "Ask about one real repeated action in the learner's everyday life.",
        "question": "What do you do after school? / What do you eat in the morning?",
        "fallback": "Offer one familiar action choice, then a short present-simple beginning such as 'I eat...' or 'I go...'.",
        "evidence": "A meaningful present-simple attempt about a real routine, even if the form is not fully stable.",
    },
    "ability": {
        "move": "Ask about a real ability using familiar actions.",
        "question": "What can you do? / Can you run or swim?",
        "fallback": "Offer an action choice, then 'I can...' or 'I can't...'.",
        "evidence": "A truthful can/can't attempt about ability.",
    },
    "location": {
        "move": "Use a visible object or a clearly imagined picture to ask where something is.",
        "question": "Where is your bag? / Is the ball on or under the chair?",
        "fallback": "Offer two position choices, then a short location frame.",
        "evidence": "A meaningful position word or sentence locating an object.",
    },
    "present_continuous": {
        "move": "Create a clear right-now or picture-description context.",
        "question": "What are you doing? / What is the girl doing?",
        "fallback": "Offer two actions, then 'I am...' or 'She is...'.",
        "evidence": "Meaningful action-now language, even with an imperfect -ing form.",
    },
    "description": {
        "move": "Invite description of one familiar person, place, object, or picture.",
        "question": "What does it look like? / What can you see?",
        "fallback": "Ask for one concrete dimension: colour, size, feeling, person, or action.",
        "evidence": "Level-appropriate descriptive detail, from one word at A0 to connected detail at higher levels.",
    },
    "past": {
        "move": "Ask about one real recent event and follow its sequence.",
        "question": "What happened yesterday? / What did you do last weekend?",
        "fallback": "Ask one step at a time or offer 'First..., then...'.",
        "evidence": "Past-time meaning, event sequence, or target past structure, even with errors.",
    },
    "opinion": {
        "move": "Ask for a personal view, then one reason or example.",
        "question": "Which do you prefer, and why? / What do you think about it?",
        "fallback": "Offer 'I think...' or 'I prefer... because...'.",
        "evidence": "A view plus level-appropriate support such as a reason, contrast, or example.",
    },
    "future": {
        "move": "Ask about a real plan or likely next action.",
        "question": "What are you going to do tomorrow? / What is your next plan?",
        "fallback": "Offer a time choice and 'I am going to...'.",
        "evidence": "Future intention, plan, prediction, or target future structure.",
    },
    "hypothetical": {
        "move": "Offer one age-appropriate imagined situation with a clear decision or consequence.",
        "question": "What would you do if...? / What might have happened if...?",
        "fallback": "Break it into choice plus reason; provide only the opening clause.",
        "evidence": "A meaningful conditional, possibility, speculation, or counterfactual response.",
    },
    "sequence": {
        "move": "Invite a short beginning-middle-end account.",
        "question": "What happened first, then, and in the end?",
        "fallback": "Ask for only the next event or offer one sequence connector.",
        "evidence": "Two or more ordered events or appropriate sequence markers.",
    },
    "reported_speech": {
        "move": "Create one clear relay situation where the learner reports another person's words or question.",
        "question": "Your friend says, 'I will come tomorrow.' How would you tell me?",
        "fallback": "Offer only the beginning: 'My friend said...'.",
        "evidence": "A meaningful attempt to report a statement, question, request, or change of viewpoint.",
    },
    "question_formation": {
        "move": "Give the learner a genuine reason to ask Zoe one question about the current topic.",
        "question": "What would you like to ask me about it?",
        "fallback": "Offer a question word or opening only: 'What...?' / 'Do you...?'.",
        "evidence": "A meaningful learner-generated question, even if word order is imperfect.",
    },
    "advice": {
        "move": "Share one low-stakes, age-appropriate problem and invite practical advice.",
        "question": "I feel tired before homework. What should I do?",
        "fallback": "Offer only the opening: 'You should...'.",
        "evidence": "A meaningful suggestion using the target advice language or equivalent meaning.",
    },
    "modality": {
        "move": "Create one real or imagined situation where possibility, advice, permission, or obligation matters.",
        "question": "What might happen? / What should the person do? / What must happen?",
        "fallback": "Offer only the target modal and let the learner complete the idea.",
        "evidence": "A meaningful use of the target modal meaning, even if form or nuance is not fully stable.",
    },
    "listening_comprehension": {
        "move": "Say one short level-matched statement containing a clear detail, then ask one question about its meaning.",
        "question": "I put the blue book under the chair. Where is the book?",
        "fallback": "Repeat the same information once more simply, then offer two meaning choices.",
        "evidence": "The learner identifies the main point, detail, meaning, attitude, or inference requested.",
    },
    "repair_comprehension": {
        "move": "Create a brief role-play where the learner needs to ask for repetition, clarification, or rephrasing.",
        "question": "Imagine you did not hear me clearly. What can you ask?",
        "fallback": "Offer one opening only: 'Can you...?' or 'What does... mean?'.",
        "evidence": "The learner uses a meaningful repair or clarification move and can continue afterward.",
    },
    "vocabulary_precision": {
        "move": "Invite the learner to make an existing idea more exact, vivid, idiomatic, or context-appropriate.",
        "question": "What word describes it more exactly? / How else could you say that?",
        "fallback": "Offer two candidate words with different meanings and ask which fits.",
        "evidence": "A more precise word, collocation, idiom, paraphrase, or appropriate lexical choice.",
    },
    "register": {
        "move": "Give one realistic audience change so the learner adapts the same message.",
        "question": "How would you say that to a teacher?",
        "fallback": "Do one audience only and offer a short opening phrase.",
        "evidence": "A meaningful shift in formality, tone, or audience fit.",
    },
    "argument": {
        "move": "Introduce a clear claim or trade-off and invite a supported response.",
        "question": "What is your view, with one reason?",
        "fallback": "Ask for claim plus one reason before adding counterargument.",
        "evidence": "A position developed with reasoning, evidence, qualification, or response to opposition.",
    },
    "discourse": {
        "move": "Give the learner a small multi-part explanation where signposting, reference, or cohesion helps the listener follow.",
        "question": "Can you explain that in two clearly linked parts?",
        "fallback": "Prompt the missing relationship only: addition, contrast, cause, result, return to topic, or reference.",
        "evidence": "The learner organizes and links ideas with appropriate discourse markers, reference, or substitution.",
    },
    "extended_speech": {
        "move": "Give a bounded speaking task with a clear shape rather than repeatedly saying 'tell me more'.",
        "question": "Give your main idea, one example, and a short conclusion.",
        "fallback": "Prompt only the missing next part: idea, example, consequence, or conclusion.",
        "evidence": "A sustained, organized response appropriate to the level target.",
    },
    "interaction": {
        "move": "Keep a real back-and-forth thread alive and leave space for the learner to add, repair, or redirect.",
        "question": "Use one natural follow-up based on their last meaning.",
        "fallback": "Offer a choice or a simple repair phrase without changing the topic.",
        "evidence": "The learner sustains, repairs, extends, joins, or redirects the exchange.",
    },
    "self_expression": {
        "move": "Invite the learner to express a personally meaningful, complex, emotional, abstract, or creative idea in their own way.",
        "question": "What idea do you most want to express precisely?",
        "fallback": "Narrow to one experience, value, or creative choice and ask for the main point first.",
        "evidence": "The learner communicates an authentic idea with the independence, precision, range, and naturalness described by the skill.",
    },
    "structure": {
        "move": "Create a meaning-rich context where the target structure is useful, without naming the grammar rule.",
        "question": "Ask one content question that naturally invites the structure shown in the skill.",
        "fallback": "Offer only the beginning of the target pattern, then let the learner complete it.",
        "evidence": "A meaningful attempt at the target structure; accuracy is judged separately from communicative evidence.",
    },
}


def _category(skill_text: str) -> str:
    text = skill_text.lower()

    # A0 and concrete communicative functions first.
    if (
        "'a' and 'the'" in text
        or " a and the" in text
        or "'a', 'an', and 'the'" in text
    ):
        return "articles"
    if any(term in text for term in [
        "name colours", "name familiar", "name things in english", "say numbers",
        "name everyday objects", "name family members", "common animals",
        "basic foods", "simple action words",
    ]):
        return "naming"
    if any(term in text for term in ["my name", "my age", "introduce myself", "say my name"]):
        return "self_intro"
    if "'i am'" in text or "i am not" in text:
        return "identity_state"
    if "have got" in text or "haven't got" in text:
        return "possession"
    if any(term in text for term in ["first, then", "after that", "in the end"]):
        return "sequence"
    if any(term in text for term in [
        "join two", "use 'and'", "linking words", "connecting phrases",
    ]):
        return "joining"
    if any(term in text for term in ["use 'but'", "contrast words", "however, although", "even though"]):
        return "contrast"
    if "because" in text or "give a reason" in text:
        return "opinion"
    if any(term in text for term in ["i like", "i don't like", "things i like", "do you like", "prefer"]):
        return "preference"
    if any(term in text for term in ["positions", "where things are", "on the chair", "on, in, under"]):
        return "location"
    if any(term in text for term in [
        "what can you do", "able to do", "i can run", "can't fly",
        "talk about ability", "ability",
    ]):
        return "ability"
    if "together in a story" in text:
        return "sequence"
    if any(term in text for term in ["present continuous", "right now", "what are you doing", "happening now"]):
        return "present_continuous"
    if any(term in text for term in ["frequency words", "always, usually", "sometimes, never", "how often"]):
        return "frequency"
    if any(term in text for term in [
        "what i do every day", "daily routine", "everyday routine",
    ]):
        return "routine"
    if any(term in text for term in [
        "ask simple questions", "ask questions using", "form questions",
        "ask detailed questions", "ask natural follow-up questions",
    ]):
        return "question_formation"
    if any(term in text for term in [
        "ask someone to repeat", "repair a conversation", "ask for clarification",
        "ask for repetition", "clarify misunderstandings", "check understanding",
        "handle misunderstandings", "rephrase when", "self-correct and rephrase",
        "recover from mistakes",
    ]):
        return "repair_comprehension"
    if any(term in text for term in [
        "understand someone", "understand the main point", "understand most",
        "understand fast", "understand natural speech", "understand vocabulary in context",
        "understand implied", "understand humour", "understand humor",
        "understand cultural", "follow complex", "follow and fully engage",
        "understand and engage", "catch every word", "listen",
        "tone and emotion", "sarcasm",
    ]):
        return "listening_comprehension"

    # Interaction and sustained fluency before broad lexical matches.
    if any(term in text for term in [
        "keep a simple exchange", "back-and-forth", "keep going", "joining a conversation",
        "join a conversation", "switch between topics", "multiparty", "take the floor",
        "conversation coherent", "conversation i didn't prepare", "engage with native speakers",
        "hold a short conversation", "keep a conversation going", "handle interruptions",
        "interact with ease", "contribute to discussions", "sustain a conversation",
        "participate actively", "respond naturally", "without long silences",
        "get my meaning across", "slow but steady pace", "naturally and spontaneously",
        "hold my own", "contribute effectively", "anything that comes up",
        "contributions are always relevant", "short sentences on very familiar topics",
        "common phrases in conversation", "buy time", "let me think",
        "comfortable pace", "no hesitation", "make myself understood",
    ]):
        return "interaction"
    if any(term in text for term in [
        "express who i really am", "communicate any idea", "feel completely natural",
        "not a foreign language", "language is no longer a barrier",
        "precision, warmth, authority, and creativity",
    ]):
        return "self_expression"
    if any(term in text for term in [
        "speak for", "extended", "several minutes", "3–5 minutes", "without any preparation",
        "organising ideas", "organize ideas", "organise what i say", "well-structured discourse",
        "sustained", "complex idea clearly", "complex sentences without losing",
        "communicate complex ideas", "speak at length", "hold the floor",
    ]):
        return "extended_speech"

    # Time, stance, and discourse functions.
    if "reported speech" in text or "report what" in text:
        return "reported_speech"
    if any(term in text for term in [
        "past ", "past-", "yesterday", "last week", "used to", "recently", "what happened",
        "present perfect",
    ]):
        return "past"
    if any(term in text for term in ["future", "going to", "tomorrow", "plan", "prediction"]):
        return "future"
    if any(term in text for term in [
        "conditional", "if i", "might have", "could have", "should have", "speculat",
    ]):
        return "hypothetical"
    if any(term in text for term in ["give simple advice", "give advice", "should to give"]):
        return "advice"
    if "modal verbs" in text:
        return "modality"
    if any(term in text for term in [
        "argumentation", "structured argument", "build structured arguments",
        "persuad", "claim", "evidence", "challenge someone's opinion",
        "defend my", "defend and challenge",
    ]):
        return "argument"
    if any(term in text for term in ["register", "formal and informal", "casual", "audience"]):
        return "register"
    if any(term in text for term in [
        "discourse marker", "linking adverbial", "reference and substitution",
        "coherent", "linking devices", "organise speech", "organize speech",
    ]):
        return "discourse"
    if any(term in text for term in ["opinion", "because", "reason", "i think", "i believe", "counter"]):
        return "opinion"
    if any(term in text for term in ["first, then", "after that", "in the end", "sequence", "story"]):
        return "sequence"

    # Description and lexical development.
    if any(term in text for term in ["describe", "descriptive", "look like", "adjective", "nuanced ideas"]):
        return "description"
    if any(term in text for term in [
        "vocabulary", "words", "idiom", "collocation", "paraphrase", "more than one way",
        "precise", "figurative", "poetic", "allusions", "nominalisation",
    ]):
        return "vocabulary_precision"

    return "structure"


def resolve_skill_text(skill_id: str, level: str | None = None) -> str | None:
    """Resolve a skill only when its ID is valid for the supplied level.

    Flat skill IDs are globally unique. Unit skill IDs repeat at every level,
    so a level is required to resolve them safely.
    """
    if skill_id in SKILLS:
        meta = SKILLS[skill_id]
        if level and meta["level"] != str(level).upper():
            return None
        return meta["text"]

    if not level:
        return None

    for unit in UNITS.get(str(level).upper(), []):
        for skill in unit.get("skills", []):
            if skill.get("id") == skill_id:
                return skill.get("text")
    return None


def get_elicitation_plan_for(skill_id: str, level: str | None = None) -> dict:
    skill = resolve_skill_text(skill_id, level)
    if not skill:
        logging.warning(
            "Ignoring unknown or level-mismatched elicitation target %s at %s",
            skill_id,
            level,
        )
        return {
            "id": skill_id,
            "fn": "interaction",
            "skill": "General conversation practice",
            "valid": False,
            **PLANS["interaction"],
        }
    category = _category(skill)
    return {
        "id": skill_id,
        "fn": category,
        "skill": skill,
        "valid": True,
        **PLANS[category],
    }


def plan_text(ids: list[str], level: str | None = None) -> str:
    if not ids:
        return "No specific target. Follow the learner's meaning and keep one coherent exchange going."

    valid_plans = []
    for skill_id in ids:
        plan = get_elicitation_plan_for(skill_id, level)
        if plan["valid"]:
            valid_plans.append(plan)

    lines = []
    for index, plan in enumerate(valid_plans):
        role = "PRIMARY" if index == 0 else "WATCH ONLY"
        lines.append(
            f"{role} {plan['id']} ({plan['fn']})\n"
            f"- Skill: {plan['skill']}\n"
            f"- Natural move: {plan['move']}\n"
            f"- Prompt options: choose exactly ONE; never combine them: {plan['question']}\n"
            f"- If support is needed: {plan['fallback']}\n"
            f"- Learner evidence: {plan['evidence']}"
        )
    if not lines:
        return "No valid specific target. Follow the learner's meaning and keep one coherent exchange going."
    return "\n\n".join(lines)
