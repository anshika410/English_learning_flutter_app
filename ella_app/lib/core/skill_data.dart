// Skill catalogue — matches ella-loop-sim-2.html CAT + UNITS_A1 exactly.
// Counts: 124 flat skills + 19 unit skills = 143 total.
// A1 and A2 have only 6 FLU skills each (not 7). This is intentional.

class SkillDef {
  final String id;
  final String? level; // null for unit skills
  final String strand; // 'VOC' | 'GRA' | 'FLU'
  final String text;

  const SkillDef({
    required this.id,
    this.level,
    required this.strand,
    required this.text,
  });
}

class UnitSkillRef {
  final String id;
  final String strand;
  final String text;

  const UnitSkillRef({
    required this.id,
    required this.strand,
    required this.text,
  });
}

class UnitStep {
  final String step; // '1'..'5'
  final String name;
  final String focus;
  final List<UnitSkillRef> skills;

  const UnitStep({
    required this.step,
    required this.name,
    required this.focus,
    required this.skills,
  });
}

// ── 124 flat CEFR skills ────────────────────────────────────────────────────

const List<SkillDef> kFlatSkills = [
  SkillDef(
    id: 'A0-VOC-01',
    level: 'A0',
    strand: 'VOC',
    text: "I can name familiar objects, animals, or colours when they come up in conversation.",
  ),
  SkillDef(
    id: 'A0-VOC-02',
    level: 'A0',
    strand: 'VOC',
    text: "I can use basic numbers when they come up in a simple conversation.",
  ),
  SkillDef(
    id: 'A0-GRA-01',
    level: 'A0',
    strand: 'GRA',
    text: "I can use a, an, or the when naming a familiar object.",
  ),
  SkillDef(
    id: 'A0-FLU-01',
    level: 'A0',
    strand: 'FLU',
    text: "I can respond to a simple question with a familiar word or short phrase.",
  ),
  SkillDef(
    id: 'A0-FLU-02',
    level: 'A0',
    strand: 'FLU',
    text: "I can give a simple introduction with a name and age.",
  ),
  SkillDef(
    id: 'A0-VOC-03',
    level: 'A0',
    strand: 'VOC',
    text: "I can say who someone is in a family.",
  ),
  SkillDef(
    id: 'A0-GRA-02',
    level: 'A0',
    strand: 'GRA',
    text: "I can use I am or I am not to describe myself or a character.",
  ),
  SkillDef(
    id: 'A0-GRA-03',
    level: 'A0',
    strand: 'GRA',
    text: "I can say what I or another person has.",
  ),
  SkillDef(
    id: 'A0-VOC-04',
    level: 'A0',
    strand: 'VOC',
    text: "I can use familiar food, activity, animal, or colour words when they come up in conversation.",
  ),
  SkillDef(
    id: 'A0-GRA-04',
    level: 'A0',
    strand: 'GRA',
    text: "I can use I like or I don't like to express a preference.",
  ),
  SkillDef(
    id: 'A0-GRA-05',
    level: 'A0',
    strand: 'GRA',
    text: "I can use and to add another word or idea.",
  ),
  SkillDef(
    id: 'A0-FLU-03',
    level: 'A0',
    strand: 'FLU',
    text: "I can take part in a simple conversation about likes and dislikes.",
  ),
  SkillDef(
    id: 'A0-VOC-05',
    level: 'A0',
    strand: 'VOC',
    text: "I can use familiar action or position words when describing a simple situation.",
  ),
  SkillDef(
    id: 'A0-GRA-06',
    level: 'A0',
    strand: 'GRA',
    text: "I can use can or can't to talk about ability.",
  ),
  SkillDef(
    id: 'A0-GRA-07',
    level: 'A0',
    strand: 'GRA',
    text: "I can use a simple location sentence to say where something is.",
  ),
  SkillDef(
    id: 'A0-FLU-04',
    level: 'A0',
    strand: 'FLU',
    text: "I can take part in a simple exchange about abilities or locations.",
  ),
  SkillDef(
    id: 'A0-VOC-06',
    level: 'A0',
    strand: 'VOC',
    text: "I can use familiar action words when talking about what someone is doing.",
  ),
  SkillDef(
    id: 'A0-GRA-08',
    level: 'A0',
    strand: 'GRA',
    text: "I can use the present continuous to say what is happening now.",
  ),
  SkillDef(
    id: 'A0-FLU-05',
    level: 'A0',
    strand: 'FLU',
    text: "I can take part in a short exchange about a current activity.",
  ),
  SkillDef(
    id: 'A0-FLU-06',
    level: 'A0',
    strand: 'FLU',
    text: "I can ask for repetition when I do not understand.",
  ),
  SkillDef(
    id: 'A1-VOC-01',
    level: 'A1',
    strand: 'VOC',
    text: "I can use simple adjectives to describe how a person looks or feels.",
  ),
  SkillDef(
    id: 'A1-GRA-01',
    level: 'A1',
    strand: 'GRA',
    text: "I can use the present continuous throughout a brief description of a scene.",
  ),
  SkillDef(
    id: 'A1-FLU-01',
    level: 'A1',
    strand: 'FLU',
    text: "I can give a short, connected description of a person, place, or scene.",
  ),
  SkillDef(
    id: 'A1-FLU-02',
    level: 'A1',
    strand: 'FLU',
    text: "I can answer a follow-up question by adding a relevant detail.",
  ),
  SkillDef(
    id: 'A1-VOC-02',
    level: 'A1',
    strand: 'VOC',
    text: "I can use familiar past-time words when talking about an event.",
  ),
  SkillDef(
    id: 'A1-GRA-02',
    level: 'A1',
    strand: 'GRA',
    text: "I can use common past-simple verbs to talk about completed actions.",
  ),
  SkillDef(
    id: 'A1-FLU-03',
    level: 'A1',
    strand: 'FLU',
    text: "I can recount a short event in a clear order.",
  ),
  SkillDef(
    id: 'A1-FLU-04',
    level: 'A1',
    strand: 'FLU',
    text: "I can answer a simple question about a short spoken story.",
  ),
  SkillDef(
    id: 'A1-VOC-03',
    level: 'A1',
    strand: 'VOC',
    text: "I can use familiar phrases to introduce an opinion.",
  ),
  SkillDef(
    id: 'A1-GRA-03',
    level: 'A1',
    strand: 'GRA',
    text: "I can use because to connect an opinion to a reason.",
  ),
  SkillDef(
    id: 'A1-GRA-04',
    level: 'A1',
    strand: 'GRA',
    text: "I can use but to contrast two simple ideas.",
  ),
  SkillDef(
    id: 'A1-FLU-05',
    level: 'A1',
    strand: 'FLU',
    text: "I can explain a simple opinion and respond to a related follow-up.",
  ),
  SkillDef(
    id: 'A1-VOC-04',
    level: 'A1',
    strand: 'VOC',
    text: "I can use familiar time words when talking about routines or plans.",
  ),
  SkillDef(
    id: 'A1-GRA-05',
    level: 'A1',
    strand: 'GRA',
    text: "I can use going to to talk about a plan.",
  ),
  SkillDef(
    id: 'A1-FLU-06',
    level: 'A1',
    strand: 'FLU',
    text: "I can discuss a simple plan and respond to a question about it.",
  ),
  SkillDef(
    id: 'A1-VOC-05',
    level: 'A1',
    strand: 'VOC',
    text: "I can use simple sequence words to organise what I say.",
  ),
  SkillDef(
    id: 'A1-GRA-06',
    level: 'A1',
    strand: 'GRA',
    text: "I can move between present and past forms when the meaning requires it.",
  ),
  SkillDef(
    id: 'A1-FLU-07',
    level: 'A1',
    strand: 'FLU',
    text: "I can stay in a familiar-topic conversation as it develops.",
  ),
  SkillDef(
    id: 'A1-FLU-08',
    level: 'A1',
    strand: 'FLU',
    text: "I can ask for repetition or say something another way after a communication problem.",
  ),
  SkillDef(
    id: 'A2-VOC-01',
    level: 'A2',
    strand: 'VOC',
    text: "I can replace a general word with a more precise descriptive word.",
  ),
  SkillDef(
    id: 'A2-VOC-02',
    level: 'A2',
    strand: 'VOC',
    text: "I can use a familiar fixed expression appropriately in conversation.",
  ),
  SkillDef(
    id: 'A2-GRA-01',
    level: 'A2',
    strand: 'GRA',
    text: "I can use the present perfect when a past experience or continuing situation is connected to now.",
  ),
  SkillDef(
    id: 'A2-FLU-01',
    level: 'A2',
    strand: 'FLU',
    text: "I can explain an idea another way when a word is missing.",
  ),
  SkillDef(
    id: 'A2-VOC-03',
    level: 'A2',
    strand: 'VOC',
    text: "I can use contrast words to connect differing ideas.",
  ),
  SkillDef(
    id: 'A2-GRA-02',
    level: 'A2',
    strand: 'GRA',
    text: "I can combine past continuous background with a past-simple event.",
  ),
  SkillDef(
    id: 'A2-GRA-03',
    level: 'A2',
    strand: 'GRA',
    text: "I can use used to to contrast a past habit or state with the present.",
  ),
  SkillDef(
    id: 'A2-FLU-02',
    level: 'A2',
    strand: 'FLU',
    text: "I can tell a past story with background, a main event, and a clear ending.",
  ),
  SkillDef(
    id: 'A2-VOC-04',
    level: 'A2',
    strand: 'VOC',
    text: "I can use stance phrases to show that a claim is my opinion.",
  ),
  SkillDef(
    id: 'A2-GRA-04',
    level: 'A2',
    strand: 'GRA',
    text: "I can use a first conditional to explain a realistic consequence.",
  ),
  SkillDef(
    id: 'A2-GRA-05',
    level: 'A2',
    strand: 'GRA',
    text: "I can choose a suitable modal for advice, possibility, or obligation.",
  ),
  SkillDef(
    id: 'A2-FLU-03',
    level: 'A2',
    strand: 'FLU',
    text: "I can develop and defend a simple opinion in conversation.",
  ),
  SkillDef(
    id: 'A2-VOC-05',
    level: 'A2',
    strand: 'VOC',
    text: "I can use linking expressions to show addition, contrast, or result.",
  ),
  SkillDef(
    id: 'A2-GRA-06',
    level: 'A2',
    strand: 'GRA',
    text: "I can use a relative clause to identify or describe something more precisely.",
  ),
  SkillDef(
    id: 'A2-FLU-04',
    level: 'A2',
    strand: 'FLU',
    text: "I can organise an extended response so the main line is easy to follow.",
  ),
  SkillDef(
    id: 'A2-FLU-05',
    level: 'A2',
    strand: 'FLU',
    text: "I can return to my main point after a clarification question.",
  ),
  SkillDef(
    id: 'A2-VOC-06',
    level: 'A2',
    strand: 'VOC',
    text: "I can adjust familiar wording for a more casual or formal situation.",
  ),
  SkillDef(
    id: 'A2-GRA-07',
    level: 'A2',
    strand: 'GRA',
    text: "I can maintain understandable tense control across a story or explanation.",
  ),
  SkillDef(
    id: 'A2-FLU-06',
    level: 'A2',
    strand: 'FLU',
    text: "I can respond to a related topic shift without losing the main thread.",
  ),
  SkillDef(
    id: 'A2-FLU-07',
    level: 'A2',
    strand: 'FLU',
    text: "I can enter a simulated group discussion with a relevant contribution.",
  ),
  SkillDef(
    id: 'B1-VOC-01',
    level: 'B1',
    strand: 'VOC',
    text: "I can replace vague wording with a more precise expression while preserving meaning.",
  ),
  SkillDef(
    id: 'B1-VOC-02',
    level: 'B1',
    strand: 'VOC',
    text: "I can use common collocations appropriately in spontaneous speech.",
  ),
  SkillDef(
    id: 'B1-GRA-01',
    level: 'B1',
    strand: 'GRA',
    text: "I can use a second conditional to explore an unreal or unlikely situation.",
  ),
  SkillDef(
    id: 'B1-FLU-01',
    level: 'B1',
    strand: 'FLU',
    text: "I can explain a complex familiar idea without removing important qualifications.",
  ),
  SkillDef(
    id: 'B1-VOC-03',
    level: 'B1',
    strand: 'VOC',
    text: "I can choose language that shows an appropriate degree of certainty.",
  ),
  SkillDef(
    id: 'B1-GRA-02',
    level: 'B1',
    strand: 'GRA',
    text: "I can use a third conditional to explain an unreal past cause and consequence.",
  ),
  SkillDef(
    id: 'B1-GRA-03',
    level: 'B1',
    strand: 'GRA',
    text: "I can report a statement or question while preserving its meaning.",
  ),
  SkillDef(
    id: 'B1-FLU-02',
    level: 'B1',
    strand: 'FLU',
    text: "I can use complex sentences while keeping the main point clear.",
  ),
  SkillDef(
    id: 'B1-VOC-04',
    level: 'B1',
    strand: 'VOC',
    text: "I can use conversational markers to open, redirect, resume, or close a point.",
  ),
  SkillDef(
    id: 'B1-GRA-04',
    level: 'B1',
    strand: 'GRA',
    text: "I can choose active or passive voice according to what I want to emphasise.",
  ),
  SkillDef(
    id: 'B1-FLU-03',
    level: 'B1',
    strand: 'FLU',
    text: "I can sustain a structured response across connected turns and follow-up questions.",
  ),
  SkillDef(
    id: 'B1-FLU-04',
    level: 'B1',
    strand: 'FLU',
    text: "I can keep a clear main thread when the conversation moves to a related topic.",
  ),
  SkillDef(
    id: 'B1-VOC-05',
    level: 'B1',
    strand: 'VOC',
    text: "I can use language for claims, evidence, and counterarguments in a discussion.",
  ),
  SkillDef(
    id: 'B1-GRA-05',
    level: 'B1',
    strand: 'GRA',
    text: "I can use linking or emphasis structures to make an argument easier to follow.",
  ),
  SkillDef(
    id: 'B1-FLU-05',
    level: 'B1',
    strand: 'FLU',
    text: "I can support a position and address an opposing point.",
  ),
  SkillDef(
    id: 'B1-FLU-06',
    level: 'B1',
    strand: 'FLU',
    text: "I can challenge an idea respectfully and respond to the reply.",
  ),
  SkillDef(
    id: 'B1-VOC-06',
    level: 'B1',
    strand: 'VOC',
    text: "I can adapt my wording for casual, formal, or persuasive speaking.",
  ),
  SkillDef(
    id: 'B1-GRA-06',
    level: 'B1',
    strand: 'GRA',
    text: "I can maintain generally reliable control of B2 grammar across spontaneous tasks.",
  ),
  SkillDef(
    id: 'B1-FLU-07',
    level: 'B1',
    strand: 'FLU',
    text: "I can respond spontaneously to familiar and moderately abstract questions.",
  ),
  SkillDef(
    id: 'B1-FLU-08',
    level: 'B1',
    strand: 'FLU',
    text: "I can convey a personal stance and appropriate humour or emphasis while remaining clear.",
  ),
  SkillDef(
    id: 'B2-VOC-01',
    level: 'B2',
    strand: 'VOC',
    text: "I can choose words for precise meaning, connotation, and context.",
  ),
  SkillDef(
    id: 'B2-VOC-02',
    level: 'B2',
    strand: 'VOC',
    text: "I can explain an abstract concept and distinguish it from a related concept.",
  ),
  SkillDef(
    id: 'B2-GRA-01',
    level: 'B2',
    strand: 'GRA',
    text: "I can use an emphasis structure when it suits the spoken purpose.",
  ),
  SkillDef(
    id: 'B2-FLU-01',
    level: 'B2',
    strand: 'FLU',
    text: "I can express a nuanced position with its qualifications and implications intact.",
  ),
  SkillDef(
    id: 'B2-VOC-03',
    level: 'B2',
    strand: 'VOC',
    text: "I can express a complex idea concisely and unpack it when clarification is needed.",
  ),
  SkillDef(
    id: 'B2-GRA-02',
    level: 'B2',
    strand: 'GRA',
    text: "I can use modal-perfect forms to evaluate or speculate about past actions.",
  ),
  SkillDef(
    id: 'B2-GRA-03',
    level: 'B2',
    strand: 'GRA',
    text: "I can use layered clauses while keeping the sentence understandable.",
  ),
  SkillDef(
    id: 'B2-FLU-02',
    level: 'B2',
    strand: 'FLU',
    text: "I can reformulate a complex answer for a listener without losing its meaning.",
  ),
  SkillDef(
    id: 'B2-VOC-04',
    level: 'B2',
    strand: 'VOC',
    text: "I can use discourse markers to signal consequence, concession, movement, or conclusion.",
  ),
  SkillDef(
    id: 'B2-GRA-04',
    level: 'B2',
    strand: 'GRA',
    text: "I can use reference and substitution to maintain cohesion without confusing repetition.",
  ),
  SkillDef(
    id: 'B2-FLU-03',
    level: 'B2',
    strand: 'FLU',
    text: "I can sustain and organise a complex discussion across connected turns.",
  ),
  SkillDef(
    id: 'B2-FLU-04',
    level: 'B2',
    strand: 'FLU',
    text: "I can contribute effectively to an academic or professional discussion.",
  ),
  SkillDef(
    id: 'B2-VOC-05',
    level: 'B2',
    strand: 'VOC',
    text: "I can adapt vocabulary and register when the audience, relationship, or purpose changes.",
  ),
  SkillDef(
    id: 'B2-GRA-05',
    level: 'B2',
    strand: 'GRA',
    text: "I can choose among neutral, emphatic, and elliptical structures according to purpose.",
  ),
  SkillDef(
    id: 'B2-FLU-05',
    level: 'B2',
    strand: 'FLU',
    text: "I can shift speaking style when the audience or purpose changes.",
  ),
  SkillDef(
    id: 'B2-VOC-06',
    level: 'B2',
    strand: 'VOC',
    text: "I can convey attitude, irony, or humour in a way that makes my intended stance clear.",
  ),
  SkillDef(
    id: 'B2-GRA-06',
    level: 'B2',
    strand: 'GRA',
    text: "I can maintain high grammatical control and self-correct without disrupting the exchange.",
  ),
  SkillDef(
    id: 'B2-FLU-06',
    level: 'B2',
    strand: 'FLU',
    text: "I can present a complex idea, respond to challenge, and refine it for the listener.",
  ),
  SkillDef(
    id: 'B2-FLU-07',
    level: 'B2',
    strand: 'FLU',
    text: "I can handle an unfamiliar high-level speaking task by clarifying and structuring my response.",
  ),
  SkillDef(
    id: 'C1-VOC-01',
    level: 'C1',
    strand: 'VOC',
    text: "I can select words for precision, connotation, and rhetorical effect.",
  ),
  SkillDef(
    id: 'C1-VOC-02',
    level: 'C1',
    strand: 'VOC',
    text: "I can adapt language sensitively to audience, relationship, and purpose.",
  ),
  SkillDef(
    id: 'C1-GRA-01',
    level: 'C1',
    strand: 'GRA',
    text: "I can use formal or literary-style structures selectively when they suit the occasion.",
  ),
  SkillDef(
    id: 'C1-FLU-01',
    level: 'C1',
    strand: 'FLU',
    text: "I can communicate complex, emotional, abstract, or creative content and clarify it when challenged.",
  ),
  SkillDef(
    id: 'C1-VOC-03',
    level: 'C1',
    strand: 'VOC',
    text: "I can create and interpret figurative language that fits the conversational context.",
  ),
  SkillDef(
    id: 'C1-GRA-02',
    level: 'C1',
    strand: 'GRA',
    text: "I can use syntax, rhythm, emphasis, and contrast deliberately to shape a spoken message.",
  ),
  SkillDef(
    id: 'C1-GRA-03',
    level: 'C1',
    strand: 'GRA',
    text: "I can draw on a very wide grammatical repertoire without making marked forms sound inappropriate.",
  ),
  SkillDef(
    id: 'C1-FLU-02',
    level: 'C1',
    strand: 'FLU',
    text: "I can produce an extended, well-structured response to an unseen complex prompt.",
  ),
  SkillDef(
    id: 'C1-VOC-04',
    level: 'C1',
    strand: 'VOC',
    text: "I can infer and discuss an unfamiliar allusion or historically marked expression when context is provided.",
  ),
  SkillDef(
    id: 'C1-GRA-04',
    level: 'C1',
    strand: 'GRA',
    text: "I can flexibly report, hypothesise, and shift emphasis across an extended exchange.",
  ),
  SkillDef(
    id: 'C1-FLU-03',
    level: 'C1',
    strand: 'FLU',
    text: "I can engage with proficient speakers who use varied speaking styles and clarify when necessary.",
  ),
  SkillDef(
    id: 'C1-FLU-04',
    level: 'C1',
    strand: 'FLU',
    text: "I can enter, hold, yield, and regain the floor in a simulated multiparty discussion.",
  ),
  SkillDef(
    id: 'C1-VOC-05',
    level: 'C1',
    strand: 'VOC',
    text: "I can retrieve, replace, and reformulate precise vocabulary under conversational pressure.",
  ),
  SkillDef(
    id: 'C1-GRA-05',
    level: 'C1',
    strand: 'GRA',
    text: "I can maintain grammatical control while planning, responding to challenge, and changing register.",
  ),
  SkillDef(
    id: 'C1-FLU-05',
    level: 'C1',
    strand: 'FLU',
    text: "I can repair a rare language problem unobtrusively while preserving the flow.",
  ),
  SkillDef(
    id: 'C1-FLU-06',
    level: 'C1',
    strand: 'FLU',
    text: "I can sustain a recognisable personal voice across different speaking purposes.",
  ),
  SkillDef(
    id: 'C1-VOC-06',
    level: 'C1',
    strand: 'VOC',
    text: "I can use exceptionally precise and flexible vocabulary across demanding speaking contexts.",
  ),
  SkillDef(
    id: 'C1-GRA-06',
    level: 'C1',
    strand: 'GRA',
    text: "I can use a very broad grammatical repertoire accurately and appropriately across contexts.",
  ),
  SkillDef(
    id: 'C1-FLU-07',
    level: 'C1',
    strand: 'FLU',
    text: "I can deliberately vary warmth, authority, creativity, and restraint while remaining precise.",
  ),
  SkillDef(
    id: 'C1-FLU-08',
    level: 'C1',
    strand: 'FLU',
    text: "I can adapt to unfamiliar, complex speaking purposes without losing precision.",
  ),
];

// ── 19 unit skills across 5 steps ───────────────────────────────────────────

const List<UnitStep> kUnitSteps = [
  UnitStep(
    step: '1',
    name: 'Describing the world',
    focus: 'Moving from naming things to describing them.',
    skills: [
      UnitSkillRef(
        id: 'U1-VOC-01',
        strand: 'VOC',
        text:
            'I can use simple adjectives to describe how a person looks or feels.',
      ),
      UnitSkillRef(
        id: 'U1-GRA-01',
        strand: 'GRA',
        text:
            'I can use the present continuous throughout a brief description of a scene.',
      ),
      UnitSkillRef(
        id: 'U1-FLU-01',
        strand: 'FLU',
        text:
            'I can give a short, connected description of a person, place, or scene.',
      ),
      UnitSkillRef(
        id: 'U1-FLU-02',
        strand: 'FLU',
        text:
            'I can answer a follow-up question by adding a relevant detail.',
      ),
    ],
  ),
  UnitStep(
    step: '2',
    name: 'Talking about the past',
    focus: 'Starting to use past tense to share what happened.',
    skills: [
      UnitSkillRef(
        id: 'U2-VOC-01',
        strand: 'VOC',
        text:
            'I can use familiar past-time words when talking about an event.',
      ),
      UnitSkillRef(
        id: 'U2-GRA-01',
        strand: 'GRA',
        text:
            'I can use common past-simple verbs to talk about completed actions.',
      ),
      UnitSkillRef(
        id: 'U2-FLU-01',
        strand: 'FLU',
        text:
            'I can recount a short event in a clear order.',
      ),
      UnitSkillRef(
        id: 'U2-FLU-02',
        strand: 'FLU',
        text:
            'I can answer a simple question about a short spoken story.',
      ),
    ],
  ),
  UnitStep(
    step: '3',
    name: 'Giving opinions and reasons',
    focus: 'Beginning to say what I think and why.',
    skills: [
      UnitSkillRef(
        id: 'U3-VOC-01',
        strand: 'VOC',
        text:
            'I can use familiar phrases to introduce an opinion.',
      ),
      UnitSkillRef(
        id: 'U3-GRA-01',
        strand: 'GRA',
        text:
            'I can use because to connect an opinion to a reason.',
      ),
      UnitSkillRef(
        id: 'U3-GRA-02',
        strand: 'GRA',
        text:
            'I can use but to contrast two simple ideas.',
      ),
      UnitSkillRef(
        id: 'U3-FLU-01',
        strand: 'FLU',
        text:
            'I can explain a simple opinion and respond to a related follow-up.',
      ),
    ],
  ),
  UnitStep(
    step: '4',
    name: 'Talking about plans',
    focus: 'Extending into the future — making and sharing plans.',
    skills: [
      UnitSkillRef(
        id: 'U4-VOC-01',
        strand: 'VOC',
        text:
            'I can use familiar time words when talking about routines or plans.',
      ),
      UnitSkillRef(
        id: 'U4-GRA-01',
        strand: 'GRA',
        text:
            'I can use going to to talk about a plan.',
      ),
      UnitSkillRef(
        id: 'U4-FLU-01',
        strand: 'FLU',
        text:
            'I can discuss a simple plan and respond to a question about it.',
      ),
    ],
  ),
  UnitStep(
    step: '5',
    name: 'Holding a real conversation',
    focus: 'Using everything together in a real back-and-forth.',
    skills: [
      UnitSkillRef(
        id: 'U5-VOC-01',
        strand: 'VOC',
        text:
            'I can use simple sequence words to organise what I say.',
      ),
      UnitSkillRef(
        id: 'U5-GRA-01',
        strand: 'GRA',
        text:
            'I can move between present and past forms when the meaning requires it.',
      ),
      UnitSkillRef(
        id: 'U5-FLU-01',
        strand: 'FLU',
        text:
            'I can stay in a familiar-topic conversation as it develops.',
      ),
      UnitSkillRef(
        id: 'U5-FLU-02',
        strand: 'FLU',
        text:
            'I can ask for repetition or say something another way after a communication problem.',
      ),
    ],
  ),
];

// ── Lookup maps ─────────────────────────────────────────────────────────────

final Map<String, SkillDef> kFlatSkillsById = {
  for (final s in kFlatSkills) s.id: s,
};

final Map<String, UnitSkillRef> kUnitSkillsById = {
  for (final u in kUnitSteps)
    for (final s in u.skills) s.id: s,
};

// ── Helper functions ─────────────────────────────────────────────────────────

List<SkillDef> skillsAtLevel(String level) =>
    kFlatSkills.where((s) => s.level == level).toList();

String skillText(String id) {
  final flat = kFlatSkillsById[id];
  if (flat != null) return flat.text;
  final unit = kUnitSkillsById[id];
  if (unit != null) return unit.text;
  return id;
}

String strandOf(String id) {
  final flat = kFlatSkillsById[id];
  if (flat != null) return flat.strand;
  final unit = kUnitSkillsById[id];
  if (unit != null) return unit.strand;
  return 'VOC';
}
