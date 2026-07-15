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
    'A0:1:U1-VOC-01': r'''Colours and numbers''',
    'A0:1:U1-VOC-02': r'''Name animals and things''',
    'A0:1:U1-GRA-01': r'''Use a and the''',
    'A0:1:U1-FLU-01': r'''Name what you see''',
    'A0:2:U2-VOC-01': r'''Say who you are''',
    'A0:2:U2-GRA-01': r'''Say I am happy''',
    'A0:2:U2-GRA-02': r'''Say I have got''',
    'A0:2:U2-FLU-01': r'''Introduce yourself in English''',
    'A0:3:U3-VOC-01': r'''Name your favourite things''',
    'A0:3:U3-GRA-01': r'''Say what you like''',
    'A0:3:U3-GRA-02': r'''Join ideas with and''',
    'A0:3:U3-FLU-01': r'''Answer Do you like...?''',
    'A0:4:U4-VOC-01': r'''Use on, in, under''',
    'A0:4:U4-GRA-01': r'''Say I can run''',
    'A0:4:U4-GRA-02': r'''Say where things are''',
    'A0:4:U4-FLU-01': r'''Answer What can you do?''',
    'A0:5:U5-GRA-01': r'''Say she is running''',
    'A0:5:U5-GRA-02': r'''Answer What are you doing?''',
    'A0:5:U5-FLU-01': r'''Keep a chat going''',
    'A0:5:U5-FLU-02': r'''Keep trying with few words''',
    'A1:1:U1-VOC-01': r'''Describe people and how they feel''',
    'A1:1:U1-GRA-01': r'''Talk about what's happening right now''',
    'A1:1:U1-FLU-01': r'''Describe a place or a picture''',
    'A1:2:U2-VOC-01': r'''Use words like yesterday, last week''',
    'A1:2:U2-GRA-01': r'''Use walked, played, watched correctly''',
    'A1:2:U2-GRA-02': r'''Use tricky past words like went, saw''',
    'A1:2:U2-FLU-01': r'''Tell a short story about your day''',
    'A1:3:U3-VOC-01': r'''Use opinion words like I think, I feel''',
    'A1:3:U3-GRA-01': r'''Give a reason using because''',
    'A1:3:U3-GRA-02': r'''Show contrast using but''',
    'A1:3:U3-FLU-01': r'''Share your opinion and explain why''',
    'A1:4:U4-VOC-01': r'''Use words like always, sometimes, never''',
    'A1:4:U4-VOC-02': r'''Use words like tomorrow, next week''',
    'A1:4:U4-GRA-01': r'''Say what you're going to do''',
    'A1:4:U4-FLU-01': r'''Talk about your plans and why''',
    'A1:5:U5-VOC-01': r'''Connect ideas with first, then, after that''',
    'A1:5:U5-GRA-01': r'''Mix past, present, and future together''',
    'A1:5:U5-FLU-01': r'''Keep a conversation going without pauses''',
    'A1:5:U5-FLU-02': r'''Keep speaking even when you're unsure''',
    'A2:1:U1-VOC-01': r'''Choose richer, exact words''',
    'A2:1:U1-VOC-02': r'''Use everyday idioms naturally''',
    'A2:1:U1-GRA-01': r'''Connect past to now''',
    'A2:1:U1-FLU-01': r'''Say it another way''',
    'A2:2:U2-VOC-01': r'''Use however and although''',
    'A2:2:U2-GRA-01': r'''Say what was happening''',
    'A2:2:U2-GRA-02': r'''Use used to''',
    'A2:2:U2-FLU-01': r'''Move between past and present''',
    'A2:3:U3-VOC-01': r'''Frame opinions with I believe''',
    'A2:3:U3-GRA-01': r'''Predict with if and will''',
    'A2:3:U3-GRA-02': r'''Use might, could, should''',
    'A2:3:U3-FLU-01': r'''Opinion, reason, and example''',
    'A2:4:U4-VOC-01': r'''Use as a result, in addition''',
    'A2:4:U4-GRA-01': r'''Add detail with who, which''',
    'A2:4:U4-FLU-01': r'''Speak for a full minute''',
    'A2:4:U4-FLU-02': r'''Organise your thoughts clearly''',
    'A2:5:U5-VOC-01': r'''Choose formal or casual words''',
    'A2:5:U5-GRA-01': r'''Use many tenses together''',
    'A2:5:U5-FLU-01': r'''Switch topics without losing thread''',
    'A2:5:U5-FLU-02': r'''Handle unplanned conversations''',
    'B1:1:U1-VOC-01': r'''Use precise, uncommon words''',
    'B1:1:U1-VOC-02': r'''Use natural word pairings''',
    'B1:1:U1-GRA-01': r'''Imagine if things were different''',
    'B1:1:U1-FLU-01': r'''Express complexity without oversimplifying''',
    'B1:2:U2-VOC-01': r'''Soften claims without retreating''',
    'B1:2:U2-GRA-01': r'''Say what could have happened''',
    'B1:2:U2-GRA-02': r'''Report what someone said''',
    'B1:2:U2-FLU-01': r'''Build complex, clear sentences''',
    'B1:3:U3-VOC-01': r'''Guide listeners with so, anyway''',
    'B1:3:U3-GRA-01': r'''Switch active and passive''',
    'B1:3:U3-FLU-01': r'''Speak clearly for five minutes''',
    'B1:3:U3-FLU-02': r'''Stay coherent as topics shift''',
    'B1:4:U4-VOC-01': r'''Speak the language of debate''',
    'B1:4:U4-GRA-01': r'''Build structured arguments''',
    'B1:4:U4-GRA-02': r'''Emphasise with cleft sentences''',
    'B1:4:U4-FLU-01': r'''Challenge and defend opinions respectfully''',
    'B1:5:U5-VOC-01': r'''Match tone to any situation''',
    'B1:5:U5-GRA-01': r'''Control complex grammar confidently''',
    'B1:5:U5-FLU-01': r'''Speak freely without preparation''',
    'B1:5:U5-FLU-02': r'''Make English truly yours''',
    'B2:1:U1-VOC-01': r'''Use sophisticated vocabulary anywhere''',
    'B2:1:U1-VOC-02': r'''Use paradox, integrity, legacy''',
    'B2:1:U1-GRA-01': r'''Flip word order for emphasis''',
    'B2:1:U1-FLU-01': r'''Express subtle, nuanced ideas''',
    'B2:2:U2-VOC-01': r'''Compress thoughts into phrases''',
    'B2:2:U2-GRA-01': r'''Use should have, could have''',
    'B2:2:U2-GRA-02': r'''Use complex phrases naturally''',
    'B2:2:U2-FLU-01': r'''Make complex ideas clear''',
    'B2:3:U3-VOC-01': r'''Steer speech with consequently, nevertheless''',
    'B2:3:U3-GRA-01': r'''Avoid repetition skilfully''',
    'B2:3:U3-FLU-01': r'''Speak at length, clearly organised''',
    'B2:3:U3-FLU-02': r'''Join professional discussions confidently''',
    'B2:4:U4-VOC-01': r'''Mix figurative and formal language''',
    'B2:4:U4-GRA-01': r'''Use clefts, fronting, ellipsis''',
    'B2:4:U4-FLU-01': r'''Shift from casual to formal''',
    'B2:5:U5-VOC-01': r'''Carry irony, humour, attitude''',
    'B2:5:U5-GRA-01': r'''Catch your own rare errors''',
    'B2:5:U5-FLU-01': r'''Communicate complex ideas precisely''',
    'B2:5:U5-FLU-02': r'''Feel natural in English anywhere''',
    'C1:1:U1-VOC-01': r'''Choose words like a writer''',
    'C1:1:U1-VOC-02': r'''Match tone and culture perfectly''',
    'C1:1:U1-GRA-01': r'''Make formal grammar feel natural''',
    'C1:1:U1-FLU-01': r'''Express any idea, however complex''',
    'C1:2:U2-VOC-01': r'''Use poetic language naturally''',
    'C1:2:U2-GRA-01': r'''Shape grammar for effect''',
    'C1:2:U2-GRA-02': r'''Use formal or literary structures''',
    'C1:2:U2-FLU-01': r'''Speak at length, unprepared''',
    'C1:3:U3-VOC-01': r'''Understand cultural and historical references''',
    'C1:3:U3-GRA-01': r'''Master reported speech and conditionals''',
    'C1:3:U3-FLU-01': r'''Engage native speakers anywhere''',
    'C1:3:U3-FLU-02': r'''Lead group conversations skilfully''',
    'C1:4:U4-VOC-01': r'''Feel English as your own''',
    'C1:4:U4-GRA-01': r'''Use grammar without thinking''',
    'C1:4:U4-FLU-01': r'''English is simply your language''',
    'C1:5:U5-VOC-01': r'''Command a native speaker's vocabulary''',
    'C1:5:U5-GRA-01': r'''Command grammar in every context''',
    'C1:5:U5-FLU-01': r'''Speak with precision and warmth''',
    'C1:5:U5-FLU-02': r'''Let English be your bridge''',
  };
}
