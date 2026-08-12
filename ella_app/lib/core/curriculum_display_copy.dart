// Student-facing display copy for garden curriculum surfaces.
// Source: docs/rephrased-references/ (July 2026 refresh).
// Canonical API/framework curriculum text remains unchanged; these maps only
// shorten labels for child-facing UI.

/// One A0 curriculum unit: its unit number and the ordered skill IDs it holds.
class A0Unit {
  final int unit;
  final List<String> skillIds;
  const A0Unit(this.unit, this.skillIds);
}

class CurriculumDisplayCopy {
  const CurriculumDisplayCopy._();

  static String unitName({
    required String level,
    required int unit,
    required String fallback,
  }) => _unitNames[_unitKey(level, unit)] ?? fallback;

  static String unitDescription({
    required String level,
    required int unit,
    required String fallback,
  }) => _unitDescriptions[_unitKey(level, unit)] ?? fallback;

  static String skillText({
    required String level,
    required int unit,
    required String skillId,
    required String fallback,
  }) => _skillTexts[_skillKey(level, unit, skillId)] ?? fallback;

  /// The A0 ("Dawn Glade") curriculum framework: 5 units, each with its skill
  /// IDs in display order. A0 skills live only in this display copy (not in
  /// [kFlatSkills]), so the garden reconstructs the A0 completed garden from
  /// this catalog. Skill IDs encode their strand (e.g. `U1-VOC-01`).
  static const List<A0Unit> a0Units = [
    A0Unit(1, ['U1-VOC-01', 'U1-VOC-02', 'U1-GRA-01', 'U1-FLU-01']),
    A0Unit(2, ['U2-VOC-01', 'U2-GRA-01', 'U2-GRA-02', 'U2-FLU-01']),
    A0Unit(3, ['U3-VOC-01', 'U3-GRA-01', 'U3-GRA-02', 'U3-FLU-01']),
    A0Unit(4, ['U4-VOC-01', 'U4-GRA-01', 'U4-GRA-02', 'U4-FLU-01']),
    A0Unit(5, ['U5-GRA-01', 'U5-GRA-02', 'U5-FLU-01', 'U5-FLU-02']),
  ];

  static String _unitKey(String level, int unit) =>
      '${level.trim().toUpperCase()}:$unit';

  static String _skillKey(String level, int unit, String skillId) =>
      '${level.trim().toUpperCase()}:$unit:${skillId.trim()}';

  static const Map<String, String> _unitNames = {
    'A0:1': r'''First Words''',
    'A0:2': r'''Introducing Yourself''',
    'A0:3': r'''Likes & Dislikes''',
    'A0:4': r'''What I Can Do''',
    'A0:5': r'''Right Now''',
    'A1:1': r'''My World''',
    'A1:2': r'''The Past''',
    'A1:3': r'''My Opinions''',
    'A1:4': r'''Future Plans''',
    'A1:5': r'''Real Conversations''',
    'A2:1': r'''Better Words''',
    'A2:2': r'''Richer Past''',
    'A2:3': r'''Deeper Opinions''',
    'A2:4': r'''Longer Speech''',
    'A2:5': r'''Staying Flexible''',
    'B1:1': r'''Precise Words''',
    'B1:2': r'''Complex Grammar''',
    'B1:3': r'''Coherent Speech''',
    'B1:4': r'''Debate & Persuasion''',
    'B1:5': r'''Spontaneous Fluency''',
    'B2:1': r'''Nuanced Words''',
    'B2:2': r'''Effortless Grammar''',
    'B2:3': r'''Extended Discourse''',
    'B2:4': r'''Register Flexibility''',
    'B2:5': r'''Precise Impact''',
    'C1:1': r'''Word Mastery''',
    'C1:2': r'''Grammar as Craft''',
    'C1:3': r'''Full Range''',
    'C1:4': r'''My English''',
    'C1:5': r'''Full Mastery''',
  };

  static const Map<String, String> _unitDescriptions = {
    'A0:1':
        r'''Go from silence to naming — colours, numbers, animals, and things you can point at.''',
    'A0:2':
        r'''Go from naming things to talking about yourself — your name, your age, and what you have.''',
    'A0:3':
        r'''Go from talking about yourself to sharing what you like and don't — your first opinions.''',
    'A0:4':
        r'''Go from opinions to ability — say what you can do, and where things are.''',
    'A0:5':
        r'''Bring it all together — describe what's happening now, and hold a real short conversation.''',
    'A1:1':
        r'''Go from naming things to describing them — people, places, and what's happening around you.''',
    'A1:2':
        r'''Go from describing now to talking about the past — what you did, and what happened.''',
    'A1:3':
        r'''Go from talking about the past to sharing what you think — and why, using because and but.''',
    'A1:4':
        r'''Go from opinions to plans — what you're going to do, and when.''',
    'A1:5':
        r'''Bring past, present, and future together — hold a real back-and-forth conversation.''',
    'A2:1':
        r'''Move from words that work to words that feel right — idioms, present perfect, and paraphrasing.''',
    'A2:2':
        r'''Add precision to the past — what was happening, what used to be, and how to contrast ideas.''',
    'A2:3':
        r'''Move from simple opinions to real arguments — reasons, possibilities, and advice.''',
    'A2:4':
        r'''Build up to a full minute of connected speech — linking ideas clearly, without losing the thread.''',
    'A2:5':
        r'''Get ready for conversations you didn't prepare for — speaking flexibly, whatever comes up.''',
    'B1:1':
        r'''Move from correct words to precise ones — natural collocations, and reasoning about “what if.”''',
    'B1:2':
        r'''Take on the hardest B-level grammar — reported speech, third conditional, and careful hedging.''',
    'B1:3':
        r'''Speak at length with real coherence — several minutes, organised, and easy to follow.''',
    'B1:4':
        r'''Move from sharing opinions to arguing them — defending your view, and challenging others'.''',
    'B1:5':
        r'''Bring B2 together — speaking naturally, without effort, on almost anything.''',
    'B2:1':
        r'''Move from a big vocabulary to a sensitive one — choosing words for effect, not just meaning.''',
    'B2:2':
        r'''Make advanced grammar automatic — precise speculation, and ideas compressed into fewer words.''',
    'B2:3':
        r'''Hold the floor for extended periods — organising ideas in real time, even in formal settings.''',
    'B2:4':
        r'''Shift instantly between styles — formal, casual, or figurative — without losing coherence.''',
    'B2:5':
        r'''Reach the point where language disappears — only what you're saying matters, not how.''',
  };

  static const Map<String, String> _skillTexts = {
    'A0:1:U1-VOC-01': r'''Name objects and colours''',
    'A0:1:U1-VOC-02': r'''Use numbers in conversation''',
    'A0:1:U1-GRA-01': r'''Use a, an, the''',
    'A0:1:U1-FLU-01': r'''Answer a simple question''',
    'A0:2:U2-FLU-01': r'''Say your name and age''',
    'A0:2:U2-VOC-01': r'''Name people in your family''',
    'A0:2:U2-GRA-01': r'''Use I am, I'm not''',
    'A0:2:U2-GRA-02': r'''Say what you have''',
    'A0:3:U3-VOC-01': r'''Use familiar everyday words''',
    'A0:3:U3-GRA-01': r'''Use like and don't like''',
    'A0:3:U3-GRA-02': r'''Join ideas using and''',
    'A0:3:U3-FLU-01': r'''Talk about your likes''',
    'A0:4:U4-VOC-01': r'''Use action and place words''',
    'A0:4:U4-GRA-01': r'''Use can and can't''',
    'A0:4:U4-GRA-02': r'''Say where things are''',
    'A0:4:U4-FLU-01': r'''Talk about your abilities''',
    'A0:5:U5-VOC-01': r'''Use words for doing things''',
    'A0:5:U5-GRA-01': r'''Say what is happening now''',
    'A0:5:U5-FLU-01': r'''Keep a short talk going''',
    'A0:5:U5-FLU-02': r'''Ask to hear it again''',
    'A1:1:U1-VOC-01': r'''Describe people and feelings''',
    'A1:1:U1-GRA-01': r'''Say what's happening now''',
    'A1:1:U1-FLU-01': r'''Describe a place or scene''',
    'A1:1:U1-FLU-02': r'''Add detail when asked''',
    'A1:2:U2-VOC-01': r'''Use yesterday, last week''',
    'A1:2:U2-GRA-01': r'''Use common past tense verbs''',
    'A1:2:U2-FLU-01': r'''Tell a short event clearly''',
    'A1:2:U2-FLU-02': r'''Answer questions about stories''',
    'A1:3:U3-VOC-01': r'''Use I think, I feel''',
    'A1:3:U3-GRA-01': r'''Give reasons with because''',
    'A1:3:U3-GRA-02': r'''Show contrast using but''',
    'A1:3:U3-FLU-01': r'''Give your opinion and why''',
    'A1:4:U4-VOC-01': r'''Use time and frequency words''',
    'A1:4:U4-GRA-01': r'''Use going to for plans''',
    'A1:4:U4-FLU-01': r'''Share your plans and why''',
    'A1:5:U5-VOC-01': r'''Use first, then, after that''',
    'A1:5:U5-GRA-01': r'''Mix past and present''',
    'A1:5:U5-FLU-01': r'''Keep the conversation flowing''',
    'A1:5:U5-FLU-02': r'''Ask or try another way''',
    'A2:1:U1-VOC-01': r'''Choose more precise words''',
    'A2:1:U1-VOC-02': r'''Use common fixed phrases''',
    'A2:1:U1-GRA-01': r'''Use the present perfect''',
    'A2:1:U1-FLU-01': r'''Explain it a different way''',
    'A2:2:U2-VOC-01': r'''Use contrast and linking words''',
    'A2:2:U2-GRA-01': r'''Combine background and event''',
    'A2:2:U2-GRA-02': r'''Use used to for habits''',
    'A2:2:U2-FLU-01': r'''Tell a full, clear story''',
    'A2:3:U3-VOC-01': r'''Show it's your opinion''',
    'A2:3:U3-GRA-01': r'''Use if for consequences''',
    'A2:3:U3-GRA-02': r'''Use should, could, might''',
    'A2:3:U3-FLU-01': r'''Defend your opinion clearly''',
    'A2:4:U4-VOC-01': r'''Link ideas with also, however''',
    'A2:4:U4-GRA-01': r'''Add detail with who, that''',
    'A2:4:U4-FLU-01': r'''Speak longer, stay organised''',
    'A2:4:U4-FLU-02': r'''Get back to your point''',
    'A2:5:U5-VOC-01': r'''Adjust words for the situation''',
    'A2:5:U5-GRA-01': r'''Control tenses across a story''',
    'A2:5:U5-FLU-01': r'''Follow a topic change smoothly''',
    'A2:5:U5-FLU-02': r'''Jump into a group discussion''',
    'B1:1:U1-VOC-01': r'''Replace vague with precise words''',
    'B1:1:U1-VOC-02': r'''Use natural word combinations''',
    'B1:1:U1-GRA-01': r'''Explore what if situations''',
    'B1:1:U1-FLU-01': r'''Explain complex ideas fully''',
    'B1:2:U2-VOC-01': r'''Show how certain you are''',
    'B1:2:U2-GRA-01': r'''Discuss unreal past events''',
    'B1:2:U2-GRA-02': r'''Report what someone said''',
    'B1:2:U2-FLU-01': r'''Keep complex sentences clear''',
    'B1:3:U3-VOC-01': r'''Guide speech with signal words''',
    'B1:3:U3-GRA-01': r'''Choose active or passive voice''',
    'B1:3:U3-FLU-01': r'''Speak at length with structure''',
    'B1:3:U3-FLU-02': r'''Hold your thread through shifts''',
    'B1:4:U4-VOC-01': r'''Use claim and evidence language''',
    'B1:4:U4-GRA-01': r'''Emphasise points with structure''',
    'B1:4:U4-FLU-01': r'''Support and defend a position''',
    'B1:4:U4-FLU-02': r'''Challenge ideas respectfully''',
    'B1:5:U5-VOC-01': r'''Adapt words to any setting''',
    'B1:5:U5-GRA-01': r'''Use grammar reliably throughout''',
    'B1:5:U5-FLU-01': r'''Respond to anything spontaneously''',
    'B1:5:U5-FLU-02': r'''Show personality while staying clear''',
    'B2:1:U1-VOC-01': r'''Choose words for effect''',
    'B2:1:U1-VOC-02': r'''Explain and compare abstract ideas''',
    'B2:1:U1-GRA-01': r'''Emphasise with word order''',
    'B2:1:U1-FLU-01': r'''Express subtle, nuanced ideas''',
    'B2:2:U2-VOC-01': r'''Compress and unpack ideas''',
    'B2:2:U2-GRA-01': r'''Use should have, could have''',
    'B2:2:U2-GRA-02': r'''Layer clauses and stay clear''',
    'B2:2:U2-FLU-01': r'''Rephrase for your listener''',
    'B2:3:U3-VOC-01': r'''Steer speech with signal words''',
    'B2:3:U3-GRA-01': r'''Avoid repetition skilfully''',
    'B2:3:U3-FLU-01': r'''Sustain a complex discussion''',
    'B2:3:U3-FLU-02': r'''Join professional discussions confidently''',
    'B2:4:U4-VOC-01': r'''Adapt language to your audience''',
    'B2:4:U4-GRA-01': r'''Choose emphatic or subtle structures''',
    'B2:4:U4-FLU-01': r'''Shift style to fit context''',
    'B2:5:U5-VOC-01': r'''Carry irony, humour, attitude''',
    'B2:5:U5-GRA-01': r'''Catch and fix rare errors''',
    'B2:5:U5-FLU-01': r'''Present, defend, and refine ideas''',
    'B2:5:U5-FLU-02': r'''Handle any unfamiliar task''',
    'C1:1:U1-VOC-01': r'''Choose words for rhetorical effect''',
    'C1:1:U1-VOC-02': r'''Adapt language to any audience''',
    'C1:1:U1-GRA-01': r'''Use literary structures selectively''',
    'C1:1:U1-FLU-01': r'''Express and defend any idea''',
    'C1:2:U2-VOC-01': r'''Create and read figurative language''',
    'C1:2:U2-GRA-01': r'''Use rhythm, emphasis, contrast''',
    'C1:2:U2-GRA-02': r'''Use the full grammar range''',
    'C1:2:U2-FLU-01': r'''Respond to unseen complex prompts''',
    'C1:3:U3-VOC-01': r'''Discuss unfamiliar references in context''',
    'C1:3:U3-GRA-01': r'''Report, hypothesise, shift emphasis''',
    'C1:3:U3-FLU-01': r'''Engage with varied speaker styles''',
    'C1:3:U3-FLU-02': r'''Manage the floor in discussion''',
    'C1:4:U4-VOC-01': r'''Find words fast under pressure''',
    'C1:4:U4-GRA-01': r'''Keep grammar steady under load''',
    'C1:4:U4-FLU-01': r'''Fix problems without breaking flow''',
    'C1:4:U4-FLU-02': r'''Sustain your personal voice''',
    'C1:5:U5-VOC-01': r'''Master vocabulary across contexts''',
    'C1:5:U5-GRA-01': r'''Command grammar in all styles''',
    'C1:5:U5-FLU-01': r'''Vary warmth, authority, creativity''',
    'C1:5:U5-FLU-02': r'''Adapt to any speaking purpose''',
  };
}
