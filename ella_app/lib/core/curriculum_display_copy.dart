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
    'A0:1': r'''Naming the world''',
    'A0:2': r'''Introducing yourself''',
    'A0:3': r'''Likes and dislikes''',
    'A0:4': r'''Saying what I can do''',
    'A0:5': r'''Describing right now''',
    'A1:1': r'''Describing the world''',
    'A1:2': r'''Talking about the past''',
    'A1:3': r'''Giving opinions and reasons''',
    'A1:4': r'''Talking about plans''',
    'A1:5': r'''Holding a real conversation''',
    'A2:1': r'''Finding better words''',
    'A2:2': r'''Refining past stories''',
    'A2:3': r'''Backing up opinions''',
    'A2:4': r'''Keeping the thread''',
    'A2:5': r'''Handling the unexpected''',
    'B1:1': r'''Precision in vocabulary''',
    'B1:2': r'''Natural complex grammar''',
    'B1:3': r'''Speaking with coherence''',
    'B1:4': r'''Arguing and persuading''',
    'B1:5': r'''Natural, spontaneous fluency''',
    'B2:1': r'''Words with feeling''',
    'B2:2': r'''Complex grammar with ease''',
    'B2:3': r'''Sustained, coherent discourse''',
    'B2:4': r'''Register flexibility''',
    'B2:5': r'''Speaking with intention''',
    'C1:1': r'''Mastery of vocabulary''',
    'C1:2': r'''Grammar as craft''',
    'C1:3': r'''Full communicative range''',
    'C1:4': r'''Language as identity''',
    'C1:5': r'''Full mastery''',
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
    'A0:1:U1-VOC-01': r'''Colours and numbers up to ten''',
    'A0:1:U1-VOC-02': r'''Name animals and everyday things around you''',
    'A0:1:U1-GRA-01': r'''Say a cat, the bag — use a and the''',
    'A0:1:U1-FLU-01': r'''Point at something and name it in English''',
    'A0:2:U2-VOC-01': r'''Say your name, age, school, and family''',
    'A0:2:U2-GRA-01': r'''Say I am happy or I am not tired''',
    'A0:2:U2-GRA-02': r'''Say I have got a dog or I haven't got a sister''',
    'A0:2:U2-FLU-01': r'''Introduce yourself in a few short phrases''',
    'A0:3:U3-VOC-01': r'''Name your favourite foods, sports, and things''',
    'A0:3:U3-GRA-01': r'''Say I like cricket or I don't like eggs''',
    'A0:3:U3-GRA-02': r'''Join two things together using and''',
    'A0:3:U3-FLU-01': r'''Answer Do you like...? with a real sentence''',
    'A0:4:U4-VOC-01': r'''Use on, in, under, next to, behind''',
    'A0:4:U4-GRA-01': r'''Say I can run or she can't fly''',
    'A0:4:U4-GRA-02': r'''Say where things are — The bag is on the chair''',
    'A0:4:U4-FLU-01': r'''Answer What can you do? with a sentence''',
    'A0:5:U5-GRA-01': r'''Say She is running or They are eating''',
    'A0:5:U5-GRA-02': r'''Answer What are you doing? — I am reading''',
    'A0:5:U5-FLU-01': r'''Keep a short chat going for two or three turns''',
    'A0:5:U5-FLU-02': r'''Keep trying even with just a few words''',
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
    'A2:1:U1-VOC-01': r'''Choose words that are richer and more exact''',
    'A2:1:U1-VOC-02': r'''Use everyday idioms the way they're meant''',
    'A2:1:U1-GRA-01': r'''Talk about what has happened up to now''',
    'A2:1:U1-FLU-01': r'''Find another way to say it when you're stuck''',
    'A2:2:U2-VOC-01': r'''Use contrast words like however and although''',
    'A2:2:U2-GRA-01':
        r'''Describe what was happening when something else happened''',
    'A2:2:U2-GRA-02': r'''Talk about what you used to do''',
    'A2:2:U2-FLU-01': r'''Tell a story switching between past and present''',
    'A2:3:U3-VOC-01': r'''Frame opinions with I believe, in my opinion''',
    'A2:3:U3-GRA-01': r'''Predict what will happen using if and will''',
    'A2:3:U3-GRA-02': r'''Use might, could, should to add more meaning''',
    'A2:3:U3-FLU-01': r'''Give an opinion with a reason and example''',
    'A2:4:U4-VOC-01': r'''Link ideas with as a result, in addition''',
    'A2:4:U4-GRA-01': r'''Add detail using who, which, where, that''',
    'A2:4:U4-FLU-01': r'''Speak for a full minute without running out''',
    'A2:4:U4-FLU-02': r'''Organise your thoughts so others can follow along''',
    'A2:5:U5-VOC-01': r'''Choose formal or casual words for the moment''',
    'A2:5:U5-GRA-01': r'''Use many tenses together accurately in a story''',
    'A2:5:U5-FLU-01': r'''Move between topics without losing your thread''',
    'A2:5:U5-FLU-02':
        r'''Handle conversations you didn't plan or prepare for''',
    'B1:1:U1-VOC-01': r'''Go beyond common words to more precise ones''',
    'B1:1:U1-VOC-02': r'''Use natural word pairings like make a decision''',
    'B1:1:U1-GRA-01': r'''Imagine what would happen if things were different''',
    'B1:1:U1-FLU-01': r'''Say something complex without oversimplifying it''',
    'B1:2:U2-VOC-01': r'''Soften a claim without backing away from it''',
    'B1:2:U2-GRA-01': r'''Reflect on how things could have been different''',
    'B1:2:U2-GRA-02': r'''Report what someone said in your own words''',
    'B1:2:U2-FLU-01':
        r'''Build complex sentences without losing the main point''',
    'B1:3:U3-VOC-01': r'''Guide listeners with words like so, anyway, right''',
    'B1:3:U3-GRA-01':
        r'''Switch between active and passive to shift emphasis''',
    'B1:3:U3-FLU-01': r'''Speak clearly for three to five minutes straight''',
    'B1:3:U3-FLU-02': r'''Stay coherent and on track when topics shift''',
    'B1:4:U4-VOC-01':
        r'''Use the language of debate — argue, counter, support''',
    'B1:4:U4-GRA-01':
        r'''Build structured arguments with strong logical connectors''',
    'B1:4:U4-GRA-02': r'''Highlight what matters most with cleft sentences''',
    'B1:4:U4-FLU-01':
        r'''Respectfully challenge an opinion and defend your own''',
    'B1:5:U5-VOC-01': r'''Match your tone and words to any situation''',
    'B1:5:U5-GRA-01': r'''Control complex grammar with confidence and ease''',
    'B1:5:U5-FLU-01':
        r'''Speak freely on almost anything without preparation''',
    'B1:5:U5-FLU-02': r'''Feel like English is truly your own tool''',
    'B2:1:U1-VOC-01':
        r'''Use sophisticated vocabulary across any topic or context''',
    'B2:1:U1-VOC-02': r'''Use abstract words like paradox, integrity, legacy''',
    'B2:1:U1-GRA-01':
        r'''Flip sentence order for emphasis — Rarely have I...''',
    'B2:1:U1-FLU-01':
        r'''Express subtle, nuanced ideas without simplifying them''',
    'B2:2:U2-VOC-01': r'''Compress a whole thought into a single noun phrase''',
    'B2:2:U2-GRA-01': r'''Use should have, could have, might have with ease''',
    'B2:2:U2-GRA-02':
        r'''Use complex noun phrases and participle clauses naturally''',
    'B2:2:U2-FLU-01':
        r'''Make complex ideas clear without losing the structure''',
    'B2:3:U3-VOC-01':
        r'''Steer longer speech with consequently, nevertheless, and more''',
    'B2:3:U3-GRA-01':
        r'''Avoid repetition by using reference and substitution''',
    'B2:3:U3-FLU-01':
        r'''Speak for several minutes and stay clearly organised''',
    'B2:3:U3-FLU-02':
        r'''Join academic and professional discussions with confidence''',
    'B2:4:U4-VOC-01':
        r'''Mix figurative, idiomatic, and formal language naturally''',
    'B2:4:U4-GRA-01':
        r'''Use cleft sentences, fronting, and ellipsis for effect''',
    'B2:4:U4-FLU-01': r'''Shift instantly from casual chat to formal debate''',
    'B2:5:U5-VOC-01': r'''Use words to carry irony, humour, and attitude''',
    'B2:5:U5-GRA-01': r'''Make only rare errors — and catch them yourself''',
    'B2:5:U5-FLU-01':
        r'''Communicate any complex idea with precision and ease''',
    'B2:5:U5-FLU-02':
        r'''Feel completely natural in English, anywhere, with anyone''',
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
