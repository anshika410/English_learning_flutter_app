-- ============================================================
-- ELLA — Seed data (FINAL, verified against ella-loop-sim-2.html)
-- Run AFTER schema.sql + rls.sql.
-- Counts: 124 flat skills + 19 unit skills = 143 rows in skill_catalogue.
-- (A1 and A2 have only 6 FLU skills each — that's why it's 124, not 126.)
-- ============================================================

-- Seeds run as the service role (or via the SQL editor), bypassing RLS.

-- ------------------------------------------------------------
-- 1. skill_catalogue — FLAT CEFR SKILLS (kind = 'flat')
-- ------------------------------------------------------------
insert into skill_catalogue (skill_id, level, strand, statement_text, kind) values
-- A1 (VOC 7, GRA 7, FLU 6 = 20)
('A1-VOC-01','A1','VOC','I can say my name, age, and where I''m from.','flat'),
('A1-VOC-02','A1','VOC','I can name everyday objects at home and school.','flat'),
('A1-VOC-03','A1','VOC','I can say numbers, colours, and days of the week.','flat'),
('A1-VOC-04','A1','VOC','I can name family members, common animals, and basic foods.','flat'),
('A1-VOC-05','A1','VOC','I can use simple action words — eat, sleep, run, sit, write.','flat'),
('A1-VOC-06','A1','VOC','I can describe how I feel — happy, sad, tired, hungry.','flat'),
('A1-VOC-07','A1','VOC','I can use the words I know to make myself understood in everyday situations.','flat'),
('A1-GRA-01','A1','GRA','I can say ''I am'' and ''I am not'' to describe myself.','flat'),
('A1-GRA-02','A1','GRA','I can make simple sentences — I like dogs. I have a pen.','flat'),
('A1-GRA-03','A1','GRA','I can talk about what I do every day using present simple — I go, I eat.','flat'),
('A1-GRA-04','A1','GRA','I can make negative sentences — I don''t like, I don''t have.','flat'),
('A1-GRA-05','A1','GRA','I can ask simple questions — Do you like cricket? What is this?','flat'),
('A1-GRA-06','A1','GRA','I can use ''and'' to join two ideas.','flat'),
('A1-GRA-07','A1','GRA','I am starting to use ''a'', ''an'', and ''the'' — and I''m learning when to use which one.','flat'),
('A1-FLU-01','A1','FLU','I can speak in short sentences on very familiar topics.','flat'),
('A1-FLU-02','A1','FLU','I can keep a simple exchange going for 2–3 turns.','flat'),
('A1-FLU-03','A1','FLU','I can understand someone if they speak slowly and clearly.','flat'),
('A1-FLU-04','A1','FLU','I can ask someone to repeat when I don''t understand.','flat'),
('A1-FLU-05','A1','FLU','I can get my meaning across even when I only have a word or two — and I keep trying even when it''s difficult.','flat'),
('A1-FLU-06','A1','FLU','I can introduce myself to someone new in English and keep going even when it''s hard.','flat'),
-- A2 (VOC 7, GRA 7, FLU 6 = 20)
('A2-VOC-01','A2','VOC','I can talk about topics like food, travel, weather, shopping, and school.','flat'),
('A2-VOC-02','A2','VOC','I can use words to describe past events and experiences.','flat'),
('A2-VOC-03','A2','VOC','I can use opinion words — I think, I feel, I believe, in my opinion.','flat'),
('A2-VOC-04','A2','VOC','I can use linking words — and, but, because, so, then.','flat'),
('A2-VOC-05','A2','VOC','I can understand and use common phrases in conversation.','flat'),
('A2-VOC-06','A2','VOC','I have enough words to talk about everyday topics and express how I feel.','flat'),
('A2-VOC-07','A2','VOC','I can use words for feelings — excited, nervous, proud, bored.','flat'),
('A2-GRA-01','A2','GRA','I can talk about the past using past simple — I went, I ate, I saw.','flat'),
('A2-GRA-02','A2','GRA','I can use ''going to'' to talk about future plans.','flat'),
('A2-GRA-03','A2','GRA','I can use comparative adjectives — bigger, faster, more interesting.','flat'),
('A2-GRA-04','A2','GRA','I can use ''can'' and ''can''''t'' to talk about ability.','flat'),
('A2-GRA-05','A2','GRA','I can use ''should'' to give simple advice.','flat'),
('A2-GRA-06','A2','GRA','I can use ''there is'' and ''there are'' to describe places.','flat'),
('A2-GRA-07','A2','GRA','I can ask questions using who, what, where, when, and why.','flat'),
('A2-FLU-01','A2','FLU','I can hold a short conversation on familiar topics without long silences.','flat'),
('A2-FLU-02','A2','FLU','I can understand the main point even when I don''t catch every word.','flat'),
('A2-FLU-03','A2','FLU','I can use simple phrases to buy time — ''let me think'', ''I mean''.','flat'),
('A2-FLU-04','A2','FLU','I can repair a conversation when I make a mistake.','flat'),
('A2-FLU-05','A2','FLU','I can speak at a slow but steady pace on topics I know well.','flat'),
('A2-FLU-06','A2','FLU','I can talk about my daily life, interests, and opinions — and it feels like a real conversation.','flat'),
-- B1 (VOC 7, GRA 7, FLU 7 = 21)
('B1-VOC-01','B1','VOC','I can discuss topics like health, education, and technology in simple terms.','flat'),
('B1-VOC-02','B1','VOC','I can use more specific words to make my ideas clearer — not just ''nice'' but ''generous'', not just ''said'' but ''explained''.','flat'),
('B1-VOC-03','B1','VOC','I can understand and use common idioms and fixed phrases.','flat'),
('B1-VOC-04','B1','VOC','I can use contrast words — however, on the other hand, although.','flat'),
('B1-VOC-05','B1','VOC','I can use sequence words — first, then, after that, finally.','flat'),
('B1-VOC-06','B1','VOC','I have enough vocabulary to discuss a range of topics and organise my ideas clearly.','flat'),
('B1-VOC-07','B1','VOC','I can use formal and informal vocabulary depending on the situation.','flat'),
('B1-GRA-01','B1','GRA','I can use present perfect to talk about experiences — I have visited, I have tried.','flat'),
('B1-GRA-02','B1','GRA','I can use ''will'' and ''going to'' to talk about the future in different ways.','flat'),
('B1-GRA-03','B1','GRA','I can use first conditional — If I study, I will pass.','flat'),
('B1-GRA-04','B1','GRA','I can use modal verbs — might, should, could, must — with reasonable accuracy.','flat'),
('B1-GRA-05','B1','GRA','I can use relative clauses — the person who, the place where.','flat'),
('B1-GRA-06','B1','GRA','I can use a range of tenses together in a story or description.','flat'),
('B1-GRA-07','B1','GRA','I can use passive sentences — It was made, It is used.','flat'),
('B1-FLU-01','B1','FLU','I can speak for about a minute on a familiar topic without stopping.','flat'),
('B1-FLU-02','B1','FLU','I can keep a conversation going even when I make grammar mistakes.','flat'),
('B1-FLU-03','B1','FLU','I can switch between topics naturally in a conversation.','flat'),
('B1-FLU-04','B1','FLU','I can understand most of what someone says even at a normal pace.','flat'),
('B1-FLU-05','B1','FLU','I can express and explain my opinions clearly enough to be understood.','flat'),
('B1-FLU-06','B1','FLU','I can join a conversation, add my ideas, and keep things going — even on topics I didn''t prepare for.','flat'),
('B1-FLU-07','B1','FLU','I can tell a story or describe an event with a clear structure.','flat'),
-- B2 (VOC 7, GRA 7, FLU 7 = 21)
('B2-VOC-01','B2','VOC','I can discuss abstract and complex topics — justice, identity, progress, culture.','flat'),
('B2-VOC-02','B2','VOC','I can use a wide range of vocabulary including less common words.','flat'),
('B2-VOC-03','B2','VOC','I can use idiomatic language naturally without it sounding forced.','flat'),
('B2-VOC-04','B2','VOC','I can choose precise words to say exactly what I mean.','flat'),
('B2-VOC-05','B2','VOC','I can understand vocabulary in context even if I haven''t seen it before.','flat'),
('B2-VOC-06','B2','VOC','I have a wide vocabulary that lets me say what I mean, even on complex topics.','flat'),
('B2-VOC-07','B2','VOC','I can use different registers — casual with friends, formal in a debate.','flat'),
('B2-GRA-01','B2','GRA','I can use a wide range of tenses accurately in extended speech.','flat'),
('B2-GRA-02','B2','GRA','I can use complex conditionals — If I had studied, I would have passed.','flat'),
('B2-GRA-03','B2','GRA','I can use reported speech — She said that she would come.','flat'),
('B2-GRA-04','B2','GRA','I can use a range of linking devices to build clear, structured arguments.','flat'),
('B2-GRA-05','B2','GRA','I can use passive and active voice flexibly depending on emphasis.','flat'),
('B2-GRA-06','B2','GRA','I can use cleft sentences for emphasis — What I mean is… It was she who…','flat'),
('B2-GRA-07','B2','GRA','I make grammar mistakes occasionally but they rarely affect understanding.','flat'),
('B2-FLU-01','B2','FLU','I can speak naturally and at a comfortable pace without noticeable effort.','flat'),
('B2-FLU-02','B2','FLU','I can handle interruptions and unexpected questions without losing my thread.','flat'),
('B2-FLU-03','B2','FLU','I can argue, persuade, and negotiate in English with confidence.','flat'),
('B2-FLU-04','B2','FLU','I can understand fast, natural speech including different accents.','flat'),
('B2-FLU-05','B2','FLU','I can pick up on tone and emotion — sarcasm, humour, frustration — in conversation.','flat'),
('B2-FLU-06','B2','FLU','I can recover from mistakes smoothly without the conversation breaking down.','flat'),
('B2-FLU-07','B2','FLU','I can express who I am in English — my personality, my opinions, my sense of humour.','flat'),
-- C1 (VOC 7, GRA 7, FLU 7 = 21)
('C1-VOC-01','C1','VOC','I can use a wide range of vocabulary to give and exchange views — on familiar topics and unfamiliar ones.','flat'),
('C1-VOC-02','C1','VOC','I can use abstract and less common vocabulary naturally — words like ''empathetic'', ''burden'', ''asset'', ''cycle of life'' come up in my speech without effort.','flat'),
('C1-VOC-03','C1','VOC','I can choose words precisely — I know the difference between near-synonyms and pick the one that fits the moment.','flat'),
('C1-VOC-04','C1','VOC','I can use vocabulary to convey my attitude and point of view, not just the facts — my word choice reflects how I feel about what I''m saying.','flat'),
('C1-VOC-05','C1','VOC','I can shift between formal and informal language naturally, depending on who I''m speaking to and what the situation calls for.','flat'),
('C1-VOC-06','C1','VOC','I have the vocabulary I need for any topic I want to talk about — and I can always find a way to say exactly what I mean.','flat'),
('C1-VOC-07','C1','VOC','I sometimes choose a word that isn''t quite right, but it rarely gets in the way — I always find a way to get my meaning across.','flat'),
('C1-GRA-01','C1','GRA','I can use a wide range of grammatical structures with confidence — complex sentences, passive forms, participle clauses, and more.','flat'),
('C1-GRA-02','C1','GRA','I can use modal verbs accurately to speculate, deduce, and express criticism — ''it must have been'', ''she could have known'', ''they should have acted''.','flat'),
('C1-GRA-03','C1','GRA','I can use discourse markers and cohesive devices to organise and connect what I say — my speech flows naturally and is easy for the listener to follow.','flat'),
('C1-GRA-04','C1','GRA','I can express complex ideas concisely — I don''t just describe things, I can name them precisely and build on them.','flat'),
('C1-GRA-05','C1','GRA','I can use conditional and hypothetical structures accurately across different tenses — I make occasional minor errors but they don''t change my meaning.','flat'),
('C1-GRA-06','C1','GRA','I can produce extended, coherent responses that are easy to follow — my ideas connect and build on each other naturally.','flat'),
('C1-GRA-07','C1','GRA','I make occasional errors — especially in complex structures — but they rarely affect understanding and don''t interrupt the flow of what I''m saying.','flat'),
('C1-FLU-01','C1','FLU','I can speak at length with very little hesitation — on familiar topics and on abstract or unfamiliar ones too.','flat'),
('C1-FLU-02','C1','FLU','I can understand and engage with complex ideas, abstract concepts, and unfamiliar subjects in conversation.','flat'),
('C1-FLU-03','C1','FLU','I can contribute effectively to discussions — I develop my own ideas, respond to others, and widen the conversation rather than just answering questions.','flat'),
('C1-FLU-04','C1','FLU','I can adjust how I speak depending on the situation — a casual conversation and a more formal discussion feel equally natural to me.','flat'),
('C1-FLU-05','C1','FLU','My responses are always relevant and coherent — I stay on topic, develop ideas clearly, and use varied language to keep the listener engaged.','flat'),
('C1-FLU-06','C1','FLU','I can interact with ease — I link what I say to what others have said, help move the conversation forward, and negotiate towards a shared understanding.','flat'),
('C1-FLU-07','C1','FLU','I can talk about anything that comes up — even topics I haven''t prepared for — with confidence and very little hesitation.','flat'),
-- C2 (VOC 7, GRA 7, FLU 7 = 21)
('C2-VOC-01','C2','VOC','I can use vocabulary flexibly and naturally across any topic — my word choices feel appropriate and precise without effort.','flat'),
('C2-VOC-02','C2','VOC','I can use less common words and phrases naturally — expressions like ''a detriment to'', ''especially in this day and age'', ''carry forward'', and ''strive for'' appear in my speech without sounding forced.','flat'),
('C2-VOC-03','C2','VOC','I can use idiomatic language, phrasal verbs, and figurative expressions as a natural part of how I speak — not as things I''ve memorised but as things I''ve genuinely absorbed.','flat'),
('C2-VOC-04','C2','VOC','My vocabulary is flexible enough to allow me to reformulate, paraphrase, and express the same idea in different ways depending on what the moment requires.','flat'),
('C2-VOC-05','C2','VOC','I can discuss abstract ideas and complex concepts with the same ease I use to talk about everyday topics.','flat'),
('C2-VOC-06','C2','VOC','I can use less common and sophisticated words without sounding unnatural — they feel like a genuine part of how I speak.','flat'),
('C2-VOC-07','C2','VOC','My vocabulary feels like mine — precise, flexible, and natural across every topic and situation.','flat'),
('C2-GRA-01','C2','GRA','I use a wide range of grammatical forms with flexibility and accuracy — my language feels natural, not constructed.','flat'),
('C2-GRA-02','C2','GRA','I can use complex structures — complex conditionals, passive forms, embedded clauses — accurately and naturally in extended speech.','flat'),
('C2-GRA-03','C2','GRA','My grammar supports my meaning rather than getting in the way of it — I can say exactly what I mean, even when the idea is complex or abstract.','flat'),
('C2-GRA-04','C2','GRA','I can use stress, intonation, and grammatical emphasis to highlight what matters most in what I''m saying.','flat'),
('C2-GRA-05','C2','GRA','I make very few errors — and when I do, they are minor and do not affect understanding or the natural flow of my speech.','flat'),
('C2-GRA-06','C2','GRA','I can handle any grammatical demand a conversation places on me — from quick casual responses to extended, structured arguments.','flat'),
('C2-GRA-07','C2','GRA','My grammar is flexible — I can vary my structures to add emphasis, adjust formality, or make my speech more engaging.','flat'),
('C2-FLU-01','C2','FLU','I can communicate on any topic — familiar, unfamiliar, abstract, or complex — with no hesitation.','flat'),
('C2-FLU-02','C2','FLU','My contributions are always relevant and well-developed — I don''t just respond to what others say, I extend ideas, introduce new angles, and help move the conversation forward.','flat'),
('C2-FLU-03','C2','FLU','I can produce extended, coherent stretches of language with flexibility and ease — my speech is organised, varied, and clear even in complex exchanges.','flat'),
('C2-FLU-04','C2','FLU','I can interact with ease — linking my contributions to others, interweaving my ideas into the conversation, and leading discussions towards a conclusion.','flat'),
('C2-FLU-05','C2','FLU','I can adapt the language I use to give emphasis, fit the situation, or be more precise — reformulating and paraphrasing naturally when it helps.','flat'),
('C2-FLU-06','C2','FLU','I can discuss abstract ideas, unfamiliar topics, and complex concepts with accuracy and flexibility — this is what English at its highest level feels like.','flat'),
('C2-FLU-07','C2','FLU','English at this level feels effortless — not because it''s easy, but because I''ve made it my own.','flat');

-- ------------------------------------------------------------
-- 2. skill_catalogue — UNIT SKILLS (kind = 'unit')  — 19 rows
-- ------------------------------------------------------------
insert into skill_catalogue (skill_id, level, strand, statement_text, kind, unit_step, unit_name, unit_focus) values
('U1-VOC-01',null,'VOC','I can describe what people look like and how they feel using simple adjectives.','unit','1','Describing the world','Moving from naming things to describing them.'),
('U1-GRA-01',null,'GRA','I can use the present continuous to describe what is happening now — She is running.','unit','1','Describing the world','Moving from naming things to describing them.'),
('U1-FLU-01',null,'FLU','I can describe a picture or a place using 3–4 connected sentences.','unit','1','Describing the world','Moving from naming things to describing them.'),
('U2-VOC-01',null,'VOC','I can use past time expressions — yesterday, last week, a long time ago.','unit','2','Talking about the past','Starting to use past tense to share what happened.'),
('U2-GRA-01',null,'GRA','I can use past simple with regular verbs — I walked, I watched, I played.','unit','2','Talking about the past','Starting to use past tense to share what happened.'),
('U2-GRA-02',null,'GRA','I can use some irregular past verbs — I went, I saw, I ate, I had.','unit','2','Talking about the past','Starting to use past tense to share what happened.'),
('U2-FLU-01',null,'FLU','I can talk about something I did recently in a few connected sentences.','unit','2','Talking about the past','Starting to use past tense to share what happened.'),
('U3-VOC-01',null,'VOC','I can use simple opinion words — I think, I feel, I prefer, I love, I hate.','unit','3','Giving opinions and reasons','Beginning to say what I think and why.'),
('U3-GRA-01',null,'GRA','I can use ''because'' to give a reason — I like cricket because it''s exciting.','unit','3','Giving opinions and reasons','Beginning to say what I think and why.'),
('U3-GRA-02',null,'GRA','I can use ''but'' to show contrast — I like football but not swimming.','unit','3','Giving opinions and reasons','Beginning to say what I think and why.'),
('U3-FLU-01',null,'FLU','I can share a simple opinion and give at least one reason for it.','unit','3','Giving opinions and reasons','Beginning to say what I think and why.'),
('U4-VOC-01',null,'VOC','I can use frequency words — always, usually, sometimes, never, often.','unit','4','Talking about plans','Extending into the future — making and sharing plans.'),
('U4-VOC-02',null,'VOC','I can use future time expressions — tomorrow, next week, soon, one day.','unit','4','Talking about plans','Extending into the future — making and sharing plans.'),
('U4-GRA-01',null,'GRA','I can use ''going to'' to talk about a plan — I''m going to study tonight.','unit','4','Talking about plans','Extending into the future — making and sharing plans.'),
('U4-FLU-01',null,'FLU','I can talk about what I am going to do and give a simple reason why.','unit','4','Talking about plans','Extending into the future — making and sharing plans.'),
('U5-VOC-01',null,'VOC','I can use connecting phrases — first, then, after that, in the end.','unit','5','Holding a real conversation','Using everything together in a real back-and-forth.'),
('U5-GRA-01',null,'GRA','I can use present simple, present continuous, and past simple together in a story.','unit','5','Holding a real conversation','Using everything together in a real back-and-forth.'),
('U5-FLU-01',null,'FLU','I can hold a short back-and-forth conversation on a familiar topic without long pauses.','unit','5','Holding a real conversation','Using everything together in a real back-and-forth.'),
('U5-FLU-02',null,'FLU','I can keep going even when I''m not 100% sure of every word.','unit','5','Holding a real conversation','Using everything together in a real back-and-forth.');

-- ------------------------------------------------------------
-- 3. topics_catalogue  (sample — extend from the simulator's TOPICS object)
--    NOTE: the simulator's full TOPICS list has ~11-12 topics per level.
--    Seed at least these to make pick-topic work; add the rest from ella-loop-sim-2.html.
-- ------------------------------------------------------------
insert into topics_catalogue (level, theme, topic, starters) values
('A1','Self','My name and where I''m from','What is your name? · Where do you live?'),
('A1','Daily life','My school','What subjects do you study? · Who is your favourite teacher?'),
('A1','Daily life','My family','Who is in your family? · Do you have brothers or sisters?'),
('A1','Interests','Animals I like','What animals do you like? · Do you have a pet?'),
('A1','Interests','Food I eat','What do you eat for breakfast? · What is your favourite food?'),
('A2','Daily life','My daily routine','What time do you wake up? · What do you do after school?'),
('A2','Interests','Games and sports','What games do you play? · Who do you play with?'),
('A2','Experiences','A festival I enjoyed','Which festival do you like? · What did you do?'),
('B1','Society','Technology in my life','How do you use phones or computers? · What is good or bad about them?'),
('B1','Society','Health and habits','What keeps people healthy? · What habits would you change?'),
('B2','Abstract','Justice and fairness','What does fairness mean to you? · Can you give an example?'),
('C1','Abstract','Progress and change','Is all progress good? · What change has mattered most?'),
('C2','Abstract','Identity and culture','What shapes who we are? · How does culture change over time?');

-- ------------------------------------------------------------
-- 4. app_prompts  (placeholders — replace content with the simulator's DEFAULT_PROMPTS)
--    Keep this table only if you chose editable prompts (Spec Part G / D2).
-- ------------------------------------------------------------
insert into app_prompts (key, content, version) values
('base',     'REPLACE WITH DEFAULT_PROMPTS.base from ella-loop-sim-2.html', 1),
('profileA1','REPLACE WITH DEFAULT_PROMPTS.profileA1', 1),
('profileB1','REPLACE WITH DEFAULT_PROMPTS.profileB1', 1),
('convSkill','REPLACE WITH DEFAULT_PROMPTS.convSkill', 1),
('convUnit', 'REPLACE WITH DEFAULT_PROMPTS.convUnit', 1),
('judge',    'REPLACE WITH DEFAULT_PROMPTS.judge', 1);

-- ------------------------------------------------------------
-- 5. Row-count assertions — fail loudly if a seed is short.
-- ------------------------------------------------------------
do $$
declare flat_count int; unit_count int;
begin
  select count(*) into flat_count from skill_catalogue where kind = 'flat';
  select count(*) into unit_count from skill_catalogue where kind = 'unit';
  if flat_count <> 124 then
    raise exception 'flat skill count is % (expected 124)', flat_count;
  end if;
  if unit_count <> 19 then
    raise exception 'unit skill count is % (expected 19)', unit_count;
  end if;
  raise notice 'Seed OK: % flat + % unit skills.', flat_count, unit_count;
end $$;
