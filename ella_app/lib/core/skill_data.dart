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
  // A1: 7 VOC + 7 GRA + 6 FLU = 20
  SkillDef(
    id: 'A1-VOC-01',
    level: 'A1',
    strand: 'VOC',
    text: "I can say my name, age, and where I'm from.",
  ),
  SkillDef(
    id: 'A1-VOC-02',
    level: 'A1',
    strand: 'VOC',
    text: 'I can name everyday objects at home and school.',
  ),
  SkillDef(
    id: 'A1-VOC-03',
    level: 'A1',
    strand: 'VOC',
    text: 'I can say numbers, colours, and days of the week.',
  ),
  SkillDef(
    id: 'A1-VOC-04',
    level: 'A1',
    strand: 'VOC',
    text: 'I can name family members, common animals, and basic foods.',
  ),
  SkillDef(
    id: 'A1-VOC-05',
    level: 'A1',
    strand: 'VOC',
    text: 'I can use simple action words — eat, sleep, run, sit, write.',
  ),
  SkillDef(
    id: 'A1-VOC-06',
    level: 'A1',
    strand: 'VOC',
    text: 'I can describe how I feel — happy, sad, tired, hungry.',
  ),
  SkillDef(
    id: 'A1-VOC-07',
    level: 'A1',
    strand: 'VOC',
    text:
        'I can use the words I know to make myself understood in everyday situations.',
  ),
  SkillDef(
    id: 'A1-GRA-01',
    level: 'A1',
    strand: 'GRA',
    text: "I can say 'I am' and 'I am not' to describe myself.",
  ),
  SkillDef(
    id: 'A1-GRA-02',
    level: 'A1',
    strand: 'GRA',
    text: 'I can make simple sentences — I like dogs. I have a pen.',
  ),
  SkillDef(
    id: 'A1-GRA-03',
    level: 'A1',
    strand: 'GRA',
    text:
        'I can talk about what I do every day using present simple — I go, I eat.',
  ),
  SkillDef(
    id: 'A1-GRA-04',
    level: 'A1',
    strand: 'GRA',
    text: "I can make negative sentences — I don't like, I don't have.",
  ),
  SkillDef(
    id: 'A1-GRA-05',
    level: 'A1',
    strand: 'GRA',
    text: 'I can ask simple questions — Do you like cricket? What is this?',
  ),
  SkillDef(
    id: 'A1-GRA-06',
    level: 'A1',
    strand: 'GRA',
    text: "I can use 'and' to join two ideas.",
  ),
  SkillDef(
    id: 'A1-GRA-07',
    level: 'A1',
    strand: 'GRA',
    text:
        "I am starting to use 'a', 'an', and 'the' — and I'm learning when to use which one.",
  ),
  SkillDef(
    id: 'A1-FLU-01',
    level: 'A1',
    strand: 'FLU',
    text: 'I can speak in short sentences on very familiar topics.',
  ),
  SkillDef(
    id: 'A1-FLU-02',
    level: 'A1',
    strand: 'FLU',
    text: 'I can keep a simple exchange going for 2–3 turns.',
  ),
  SkillDef(
    id: 'A1-FLU-03',
    level: 'A1',
    strand: 'FLU',
    text: 'I can understand someone if they speak slowly and clearly.',
  ),
  SkillDef(
    id: 'A1-FLU-04',
    level: 'A1',
    strand: 'FLU',
    text: "I can ask someone to repeat when I don't understand.",
  ),
  SkillDef(
    id: 'A1-FLU-05',
    level: 'A1',
    strand: 'FLU',
    text:
        "I can get my meaning across even when I only have a word or two — and I keep trying even when it's difficult.",
  ),
  SkillDef(
    id: 'A1-FLU-06',
    level: 'A1',
    strand: 'FLU',
    text:
        "I can introduce myself to someone new in English and keep going even when it's hard.",
  ),

  // A2: 7 VOC + 7 GRA + 6 FLU = 20
  SkillDef(
    id: 'A2-VOC-01',
    level: 'A2',
    strand: 'VOC',
    text:
        'I can talk about topics like food, travel, weather, shopping, and school.',
  ),
  SkillDef(
    id: 'A2-VOC-02',
    level: 'A2',
    strand: 'VOC',
    text: 'I can use words to describe past events and experiences.',
  ),
  SkillDef(
    id: 'A2-VOC-03',
    level: 'A2',
    strand: 'VOC',
    text:
        'I can use opinion words — I think, I feel, I believe, in my opinion.',
  ),
  SkillDef(
    id: 'A2-VOC-04',
    level: 'A2',
    strand: 'VOC',
    text: 'I can use linking words — and, but, because, so, then.',
  ),
  SkillDef(
    id: 'A2-VOC-05',
    level: 'A2',
    strand: 'VOC',
    text: 'I can understand and use common phrases in conversation.',
  ),
  SkillDef(
    id: 'A2-VOC-06',
    level: 'A2',
    strand: 'VOC',
    text:
        'I have enough words to talk about everyday topics and express how I feel.',
  ),
  SkillDef(
    id: 'A2-VOC-07',
    level: 'A2',
    strand: 'VOC',
    text: 'I can use words for feelings — excited, nervous, proud, bored.',
  ),
  SkillDef(
    id: 'A2-GRA-01',
    level: 'A2',
    strand: 'GRA',
    text: 'I can talk about the past using past simple — I went, I ate, I saw.',
  ),
  SkillDef(
    id: 'A2-GRA-02',
    level: 'A2',
    strand: 'GRA',
    text: "I can use 'going to' to talk about future plans.",
  ),
  SkillDef(
    id: 'A2-GRA-03',
    level: 'A2',
    strand: 'GRA',
    text:
        'I can use comparative adjectives — bigger, faster, more interesting.',
  ),
  SkillDef(
    id: 'A2-GRA-04',
    level: 'A2',
    strand: 'GRA',
    text: "I can use 'can' and 'can't' to talk about ability.",
  ),
  SkillDef(
    id: 'A2-GRA-05',
    level: 'A2',
    strand: 'GRA',
    text: "I can use 'should' to give simple advice.",
  ),
  SkillDef(
    id: 'A2-GRA-06',
    level: 'A2',
    strand: 'GRA',
    text: "I can use 'there is' and 'there are' to describe places.",
  ),
  SkillDef(
    id: 'A2-GRA-07',
    level: 'A2',
    strand: 'GRA',
    text: 'I can ask questions using who, what, where, when, and why.',
  ),
  SkillDef(
    id: 'A2-FLU-01',
    level: 'A2',
    strand: 'FLU',
    text:
        'I can hold a short conversation on familiar topics without long silences.',
  ),
  SkillDef(
    id: 'A2-FLU-02',
    level: 'A2',
    strand: 'FLU',
    text: "I can understand the main point even when I don't catch every word.",
  ),
  SkillDef(
    id: 'A2-FLU-03',
    level: 'A2',
    strand: 'FLU',
    text: "I can use simple phrases to buy time — 'let me think', 'I mean'.",
  ),
  SkillDef(
    id: 'A2-FLU-04',
    level: 'A2',
    strand: 'FLU',
    text: 'I can repair a conversation when I make a mistake.',
  ),
  SkillDef(
    id: 'A2-FLU-05',
    level: 'A2',
    strand: 'FLU',
    text: 'I can speak at a slow but steady pace on topics I know well.',
  ),
  SkillDef(
    id: 'A2-FLU-06',
    level: 'A2',
    strand: 'FLU',
    text:
        "I can talk about my daily life, interests, and opinions — and it feels like a real conversation.",
  ),

  // B1: 7 VOC + 7 GRA + 7 FLU = 21
  SkillDef(
    id: 'B1-VOC-01',
    level: 'B1',
    strand: 'VOC',
    text:
        'I can discuss topics like health, education, and technology in simple terms.',
  ),
  SkillDef(
    id: 'B1-VOC-02',
    level: 'B1',
    strand: 'VOC',
    text:
        "I can use more specific words to make my ideas clearer — not just 'nice' but 'generous', not just 'said' but 'explained'.",
  ),
  SkillDef(
    id: 'B1-VOC-03',
    level: 'B1',
    strand: 'VOC',
    text: 'I can understand and use common idioms and fixed phrases.',
  ),
  SkillDef(
    id: 'B1-VOC-04',
    level: 'B1',
    strand: 'VOC',
    text: 'I can use contrast words — however, on the other hand, although.',
  ),
  SkillDef(
    id: 'B1-VOC-05',
    level: 'B1',
    strand: 'VOC',
    text: 'I can use sequence words — first, then, after that, finally.',
  ),
  SkillDef(
    id: 'B1-VOC-06',
    level: 'B1',
    strand: 'VOC',
    text:
        'I have enough vocabulary to discuss a range of topics and organise my ideas clearly.',
  ),
  SkillDef(
    id: 'B1-VOC-07',
    level: 'B1',
    strand: 'VOC',
    text:
        'I can use formal and informal vocabulary depending on the situation.',
  ),
  SkillDef(
    id: 'B1-GRA-01',
    level: 'B1',
    strand: 'GRA',
    text:
        'I can use present perfect to talk about experiences — I have visited, I have tried.',
  ),
  SkillDef(
    id: 'B1-GRA-02',
    level: 'B1',
    strand: 'GRA',
    text:
        "I can use 'will' and 'going to' to talk about the future in different ways.",
  ),
  SkillDef(
    id: 'B1-GRA-03',
    level: 'B1',
    strand: 'GRA',
    text: 'I can use first conditional — If I study, I will pass.',
  ),
  SkillDef(
    id: 'B1-GRA-04',
    level: 'B1',
    strand: 'GRA',
    text:
        'I can use modal verbs — might, should, could, must — with reasonable accuracy.',
  ),
  SkillDef(
    id: 'B1-GRA-05',
    level: 'B1',
    strand: 'GRA',
    text: 'I can use relative clauses — the person who, the place where.',
  ),
  SkillDef(
    id: 'B1-GRA-06',
    level: 'B1',
    strand: 'GRA',
    text: 'I can use a range of tenses together in a story or description.',
  ),
  SkillDef(
    id: 'B1-GRA-07',
    level: 'B1',
    strand: 'GRA',
    text: 'I can use passive sentences — It was made, It is used.',
  ),
  SkillDef(
    id: 'B1-FLU-01',
    level: 'B1',
    strand: 'FLU',
    text:
        'I can speak for about a minute on a familiar topic without stopping.',
  ),
  SkillDef(
    id: 'B1-FLU-02',
    level: 'B1',
    strand: 'FLU',
    text: 'I can keep a conversation going even when I make grammar mistakes.',
  ),
  SkillDef(
    id: 'B1-FLU-03',
    level: 'B1',
    strand: 'FLU',
    text: 'I can switch between topics naturally in a conversation.',
  ),
  SkillDef(
    id: 'B1-FLU-04',
    level: 'B1',
    strand: 'FLU',
    text: "I can understand most of what someone says even at a normal pace.",
  ),
  SkillDef(
    id: 'B1-FLU-05',
    level: 'B1',
    strand: 'FLU',
    text:
        'I can express and explain my opinions clearly enough to be understood.',
  ),
  SkillDef(
    id: 'B1-FLU-06',
    level: 'B1',
    strand: 'FLU',
    text:
        "I can join a conversation, add my ideas, and keep things going — even on topics I didn't prepare for.",
  ),
  SkillDef(
    id: 'B1-FLU-07',
    level: 'B1',
    strand: 'FLU',
    text: 'I can tell a story or describe an event with a clear structure.',
  ),

  // B2: 7 VOC + 7 GRA + 7 FLU = 21
  SkillDef(
    id: 'B2-VOC-01',
    level: 'B2',
    strand: 'VOC',
    text:
        'I can discuss abstract and complex topics — justice, identity, progress, culture.',
  ),
  SkillDef(
    id: 'B2-VOC-02',
    level: 'B2',
    strand: 'VOC',
    text: 'I can use a wide range of vocabulary including less common words.',
  ),
  SkillDef(
    id: 'B2-VOC-03',
    level: 'B2',
    strand: 'VOC',
    text: 'I can use idiomatic language naturally without it sounding forced.',
  ),
  SkillDef(
    id: 'B2-VOC-04',
    level: 'B2',
    strand: 'VOC',
    text: 'I can choose precise words to say exactly what I mean.',
  ),
  SkillDef(
    id: 'B2-VOC-05',
    level: 'B2',
    strand: 'VOC',
    text:
        "I can understand vocabulary in context even if I haven't seen it before.",
  ),
  SkillDef(
    id: 'B2-VOC-06',
    level: 'B2',
    strand: 'VOC',
    text:
        "I have a wide vocabulary that lets me say what I mean, even on complex topics.",
  ),
  SkillDef(
    id: 'B2-VOC-07',
    level: 'B2',
    strand: 'VOC',
    text:
        'I can use different registers — casual with friends, formal in a debate.',
  ),
  SkillDef(
    id: 'B2-GRA-01',
    level: 'B2',
    strand: 'GRA',
    text: 'I can use a wide range of tenses accurately in extended speech.',
  ),
  SkillDef(
    id: 'B2-GRA-02',
    level: 'B2',
    strand: 'GRA',
    text:
        'I can use complex conditionals — If I had studied, I would have passed.',
  ),
  SkillDef(
    id: 'B2-GRA-03',
    level: 'B2',
    strand: 'GRA',
    text: 'I can use reported speech — She said that she would come.',
  ),
  SkillDef(
    id: 'B2-GRA-04',
    level: 'B2',
    strand: 'GRA',
    text:
        'I can use a range of linking devices to build clear, structured arguments.',
  ),
  SkillDef(
    id: 'B2-GRA-05',
    level: 'B2',
    strand: 'GRA',
    text: 'I can use passive and active voice flexibly depending on emphasis.',
  ),
  SkillDef(
    id: 'B2-GRA-06',
    level: 'B2',
    strand: 'GRA',
    text:
        'I can use cleft sentences for emphasis — What I mean is… It was she who…',
  ),
  SkillDef(
    id: 'B2-GRA-07',
    level: 'B2',
    strand: 'GRA',
    text:
        "I make grammar mistakes occasionally but they rarely affect understanding.",
  ),
  SkillDef(
    id: 'B2-FLU-01',
    level: 'B2',
    strand: 'FLU',
    text:
        'I can speak naturally and at a comfortable pace without noticeable effort.',
  ),
  SkillDef(
    id: 'B2-FLU-02',
    level: 'B2',
    strand: 'FLU',
    text:
        'I can handle interruptions and unexpected questions without losing my thread.',
  ),
  SkillDef(
    id: 'B2-FLU-03',
    level: 'B2',
    strand: 'FLU',
    text: 'I can argue, persuade, and negotiate in English with confidence.',
  ),
  SkillDef(
    id: 'B2-FLU-04',
    level: 'B2',
    strand: 'FLU',
    text: 'I can understand fast, natural speech including different accents.',
  ),
  SkillDef(
    id: 'B2-FLU-05',
    level: 'B2',
    strand: 'FLU',
    text:
        'I can pick up on tone and emotion — sarcasm, humour, frustration — in conversation.',
  ),
  SkillDef(
    id: 'B2-FLU-06',
    level: 'B2',
    strand: 'FLU',
    text:
        "I can recover from mistakes smoothly without the conversation breaking down.",
  ),
  SkillDef(
    id: 'B2-FLU-07',
    level: 'B2',
    strand: 'FLU',
    text:
        'I can express who I am in English — my personality, my opinions, my sense of humour.',
  ),

  // C1: 7 VOC + 7 GRA + 7 FLU = 21
  SkillDef(
    id: 'C1-VOC-01',
    level: 'C1',
    strand: 'VOC',
    text:
        'I can use a wide range of vocabulary to give and exchange views — on familiar topics and unfamiliar ones.',
  ),
  SkillDef(
    id: 'C1-VOC-02',
    level: 'C1',
    strand: 'VOC',
    text:
        "I can use abstract and less common vocabulary naturally — words like 'empathetic', 'burden', 'asset', 'cycle of life' come up in my speech without effort.",
  ),
  SkillDef(
    id: 'C1-VOC-03',
    level: 'C1',
    strand: 'VOC',
    text:
        "I can choose words precisely — I know the difference between near-synonyms and pick the one that fits the moment.",
  ),
  SkillDef(
    id: 'C1-VOC-04',
    level: 'C1',
    strand: 'VOC',
    text:
        "I can use vocabulary to convey my attitude and point of view, not just the facts — my word choice reflects how I feel about what I'm saying.",
  ),
  SkillDef(
    id: 'C1-VOC-05',
    level: 'C1',
    strand: 'VOC',
    text:
        "I can shift between formal and informal language naturally, depending on who I'm speaking to and what the situation calls for.",
  ),
  SkillDef(
    id: 'C1-VOC-06',
    level: 'C1',
    strand: 'VOC',
    text:
        "I have the vocabulary I need for any topic I want to talk about — and I can always find a way to say exactly what I mean.",
  ),
  SkillDef(
    id: 'C1-VOC-07',
    level: 'C1',
    strand: 'VOC',
    text:
        "I sometimes choose a word that isn't quite right, but it rarely gets in the way — I always find a way to get my meaning across.",
  ),
  SkillDef(
    id: 'C1-GRA-01',
    level: 'C1',
    strand: 'GRA',
    text:
        'I can use a wide range of grammatical structures with confidence — complex sentences, passive forms, participle clauses, and more.',
  ),
  SkillDef(
    id: 'C1-GRA-02',
    level: 'C1',
    strand: 'GRA',
    text:
        "I can use modal verbs accurately to speculate, deduce, and express criticism — 'it must have been', 'she could have known', 'they should have acted'.",
  ),
  SkillDef(
    id: 'C1-GRA-03',
    level: 'C1',
    strand: 'GRA',
    text:
        'I can use discourse markers and cohesive devices to organise and connect what I say — my speech flows naturally and is easy for the listener to follow.',
  ),
  SkillDef(
    id: 'C1-GRA-04',
    level: 'C1',
    strand: 'GRA',
    text:
        "I can express complex ideas concisely — I don't just describe things, I can name them precisely and build on them.",
  ),
  SkillDef(
    id: 'C1-GRA-05',
    level: 'C1',
    strand: 'GRA',
    text:
        'I can use conditional and hypothetical structures accurately across different tenses — I make occasional minor errors but they don\'t change my meaning.',
  ),
  SkillDef(
    id: 'C1-GRA-06',
    level: 'C1',
    strand: 'GRA',
    text:
        'I can produce extended, coherent responses that are easy to follow — my ideas connect and build on each other naturally.',
  ),
  SkillDef(
    id: 'C1-GRA-07',
    level: 'C1',
    strand: 'GRA',
    text:
        "I make occasional errors — especially in complex structures — but they rarely affect understanding and don't interrupt the flow of what I'm saying.",
  ),
  SkillDef(
    id: 'C1-FLU-01',
    level: 'C1',
    strand: 'FLU',
    text:
        'I can speak at length with very little hesitation — on familiar topics and on abstract or unfamiliar ones too.',
  ),
  SkillDef(
    id: 'C1-FLU-02',
    level: 'C1',
    strand: 'FLU',
    text:
        'I can understand and engage with complex ideas, abstract concepts, and unfamiliar subjects in conversation.',
  ),
  SkillDef(
    id: 'C1-FLU-03',
    level: 'C1',
    strand: 'FLU',
    text:
        'I can contribute effectively to discussions — I develop my own ideas, respond to others, and widen the conversation rather than just answering questions.',
  ),
  SkillDef(
    id: 'C1-FLU-04',
    level: 'C1',
    strand: 'FLU',
    text:
        'I can adjust how I speak depending on the situation — a casual conversation and a more formal discussion feel equally natural to me.',
  ),
  SkillDef(
    id: 'C1-FLU-05',
    level: 'C1',
    strand: 'FLU',
    text:
        'My responses are always relevant and coherent — I stay on topic, develop ideas clearly, and use varied language to keep the listener engaged.',
  ),
  SkillDef(
    id: 'C1-FLU-06',
    level: 'C1',
    strand: 'FLU',
    text:
        'I can interact with ease — I link what I say to what others have said, help move the conversation forward, and negotiate towards a shared understanding.',
  ),
  SkillDef(
    id: 'C1-FLU-07',
    level: 'C1',
    strand: 'FLU',
    text:
        "I can talk about anything that comes up — even topics I haven't prepared for — with confidence and very little hesitation.",
  ),

  // C2: 7 VOC + 7 GRA + 7 FLU = 21
  SkillDef(
    id: 'C2-VOC-01',
    level: 'C2',
    strand: 'VOC',
    text:
        'I can use vocabulary flexibly and naturally across any topic — my word choices feel appropriate and precise without effort.',
  ),
  SkillDef(
    id: 'C2-VOC-02',
    level: 'C2',
    strand: 'VOC',
    text:
        "I can use less common words and phrases naturally — expressions like 'a detriment to', 'especially in this day and age', 'carry forward', and 'strive for' appear in my speech without sounding forced.",
  ),
  SkillDef(
    id: 'C2-VOC-03',
    level: 'C2',
    strand: 'VOC',
    text:
        "I can use idiomatic language, phrasal verbs, and figurative expressions as a natural part of how I speak — not as things I've memorised but as things I've genuinely absorbed.",
  ),
  SkillDef(
    id: 'C2-VOC-04',
    level: 'C2',
    strand: 'VOC',
    text:
        'My vocabulary is flexible enough to allow me to reformulate, paraphrase, and express the same idea in different ways depending on what the moment requires.',
  ),
  SkillDef(
    id: 'C2-VOC-05',
    level: 'C2',
    strand: 'VOC',
    text:
        'I can discuss abstract ideas and complex concepts with the same ease I use to talk about everyday topics.',
  ),
  SkillDef(
    id: 'C2-VOC-06',
    level: 'C2',
    strand: 'VOC',
    text:
        "I can use less common and sophisticated words without sounding unnatural — they feel like a genuine part of how I speak.",
  ),
  SkillDef(
    id: 'C2-VOC-07',
    level: 'C2',
    strand: 'VOC',
    text:
        'My vocabulary feels like mine — precise, flexible, and natural across every topic and situation.',
  ),
  SkillDef(
    id: 'C2-GRA-01',
    level: 'C2',
    strand: 'GRA',
    text:
        'I use a wide range of grammatical forms with flexibility and accuracy — my language feels natural, not constructed.',
  ),
  SkillDef(
    id: 'C2-GRA-02',
    level: 'C2',
    strand: 'GRA',
    text:
        'I can use complex structures — complex conditionals, passive forms, embedded clauses — accurately and naturally in extended speech.',
  ),
  SkillDef(
    id: 'C2-GRA-03',
    level: 'C2',
    strand: 'GRA',
    text:
        "My grammar supports my meaning rather than getting in the way of it — I can say exactly what I mean, even when the idea is complex or abstract.",
  ),
  SkillDef(
    id: 'C2-GRA-04',
    level: 'C2',
    strand: 'GRA',
    text:
        "I can use stress, intonation, and grammatical emphasis to highlight what matters most in what I'm saying.",
  ),
  SkillDef(
    id: 'C2-GRA-05',
    level: 'C2',
    strand: 'GRA',
    text:
        "I make very few errors — and when I do, they are minor and do not affect understanding or the natural flow of my speech.",
  ),
  SkillDef(
    id: 'C2-GRA-06',
    level: 'C2',
    strand: 'GRA',
    text:
        'I can handle any grammatical demand a conversation places on me — from quick casual responses to extended, structured arguments.',
  ),
  SkillDef(
    id: 'C2-GRA-07',
    level: 'C2',
    strand: 'GRA',
    text:
        'My grammar is flexible — I can vary my structures to add emphasis, adjust formality, or make my speech more engaging.',
  ),
  SkillDef(
    id: 'C2-FLU-01',
    level: 'C2',
    strand: 'FLU',
    text:
        'I can communicate on any topic — familiar, unfamiliar, abstract, or complex — with no hesitation.',
  ),
  SkillDef(
    id: 'C2-FLU-02',
    level: 'C2',
    strand: 'FLU',
    text:
        "I don't just respond to what others say, I extend ideas, introduce new angles, and help move the conversation forward.",
  ),
  SkillDef(
    id: 'C2-FLU-03',
    level: 'C2',
    strand: 'FLU',
    text:
        'I can produce extended, coherent stretches of language with flexibility and ease — my speech is organised, varied, and clear even in complex exchanges.',
  ),
  SkillDef(
    id: 'C2-FLU-04',
    level: 'C2',
    strand: 'FLU',
    text:
        'I can interact with ease — linking my contributions to others, interweaving my ideas into the conversation, and leading discussions towards a conclusion.',
  ),
  SkillDef(
    id: 'C2-FLU-05',
    level: 'C2',
    strand: 'FLU',
    text:
        'I can adapt the language I use to give emphasis, fit the situation, or be more precise — reformulating and paraphrasing naturally when it helps.',
  ),
  SkillDef(
    id: 'C2-FLU-06',
    level: 'C2',
    strand: 'FLU',
    text:
        'I can discuss abstract ideas, unfamiliar topics, and complex concepts with accuracy and flexibility — this is what English at its highest level feels like.',
  ),
  SkillDef(
    id: 'C2-FLU-07',
    level: 'C2',
    strand: 'FLU',
    text:
        "English at this level feels effortless — not because it's easy, but because I've made it my own.",
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
            'I can describe what people look like and how they feel using simple adjectives.',
      ),
      UnitSkillRef(
        id: 'U1-GRA-01',
        strand: 'GRA',
        text:
            'I can use the present continuous to describe what is happening now — She is running.',
      ),
      UnitSkillRef(
        id: 'U1-FLU-01',
        strand: 'FLU',
        text:
            'I can describe a picture or a place using 3–4 connected sentences.',
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
            'I can use past time expressions — yesterday, last week, a long time ago.',
      ),
      UnitSkillRef(
        id: 'U2-GRA-01',
        strand: 'GRA',
        text:
            'I can use past simple with regular verbs — I walked, I watched, I played.',
      ),
      UnitSkillRef(
        id: 'U2-GRA-02',
        strand: 'GRA',
        text:
            'I can use some irregular past verbs — I went, I saw, I ate, I had.',
      ),
      UnitSkillRef(
        id: 'U2-FLU-01',
        strand: 'FLU',
        text:
            'I can talk about something I did recently in a few connected sentences.',
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
            'I can use simple opinion words — I think, I feel, I prefer, I love, I hate.',
      ),
      UnitSkillRef(
        id: 'U3-GRA-01',
        strand: 'GRA',
        text:
            "I can use 'because' to give a reason — I like cricket because it's exciting.",
      ),
      UnitSkillRef(
        id: 'U3-GRA-02',
        strand: 'GRA',
        text:
            "I can use 'but' to show contrast — I like football but not swimming.",
      ),
      UnitSkillRef(
        id: 'U3-FLU-01',
        strand: 'FLU',
        text:
            'I can share a simple opinion and give at least one reason for it.',
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
            'I can use frequency words — always, usually, sometimes, never, often.',
      ),
      UnitSkillRef(
        id: 'U4-VOC-02',
        strand: 'VOC',
        text:
            'I can use future time expressions — tomorrow, next week, soon, one day.',
      ),
      UnitSkillRef(
        id: 'U4-GRA-01',
        strand: 'GRA',
        text:
            "I can use 'going to' to talk about a plan — I'm going to study tonight.",
      ),
      UnitSkillRef(
        id: 'U4-FLU-01',
        strand: 'FLU',
        text:
            'I can talk about what I am going to do and give a simple reason why.',
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
            'I can use connecting phrases — first, then, after that, in the end.',
      ),
      UnitSkillRef(
        id: 'U5-GRA-01',
        strand: 'GRA',
        text:
            'I can use present simple, present continuous, and past simple together in a story.',
      ),
      UnitSkillRef(
        id: 'U5-FLU-01',
        strand: 'FLU',
        text:
            'I can hold a short back-and-forth conversation on a familiar topic without long pauses.',
      ),
      UnitSkillRef(
        id: 'U5-FLU-02',
        strand: 'FLU',
        text: "I can keep going even when I'm not 100% sure of every word.",
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
