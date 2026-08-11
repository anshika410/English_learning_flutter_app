from __future__ import annotations
# Auto-generated from Ella_Framework_Complete.xlsx
# Do not modify manually. Regenerate using parse_framework.py

from datetime import datetime, timezone

# Level headlines
HEADLINES = {
    "A0": "I can talk about myself and things around me.",
    "A1": "I can have simple conversations on everyday topics.",
    "A2": "I can share my opinions and tell stories in English.",
    "B1": "I can speak for about a minute on many different topics.",
    "B2": "I feel comfortable talking with peers about complex things.",
    "C1": "I can communicate on any topic with accuracy, flexibility, and no hesitation."
}

# Flat CEFR skills
CAT = [['A0-VOC-01', 'A0', 'VOC', "I can say my name, age, and where I'm from."], ['A0-VOC-02', 'A0', 'VOC', 'I can name everyday objects at home and school.'], ['A0-VOC-03', 'A0', 'VOC', 'I can say numbers, colours, and days of the week.'], ['A0-VOC-04', 'A0', 'VOC', 'I can name family members, common animals, and basic foods.'], ['A0-VOC-05', 'A0', 'VOC', 'I can use simple action words — eat, sleep, run, sit, write.'], ['A0-VOC-06', 'A0', 'VOC', 'I can describe how I feel — happy, sad, tired, hungry.'], ['A0-VOC-07', 'A0', 'VOC', 'I can use the words I know to make myself understood in everyday situations.'], ['A0-GRA-01', 'A0', 'GRA', "I can say 'I am' and 'I am not' to describe myself."], ['A0-GRA-02', 'A0', 'GRA', 'I can make simple sentences — I like dogs. I have a pen.'], ['A0-GRA-03', 'A0', 'GRA', 'I can talk about what I do every day using present simple — I go, I eat.'], ['A0-GRA-04', 'A0', 'GRA', "I can make negative sentences — I don't like, I don't have."], ['A0-GRA-05', 'A0', 'GRA', 'I can ask simple questions — Do you like cricket? What is this?'], ['A0-GRA-06', 'A0', 'GRA', "I can use 'and' to join two ideas."], ['A0-GRA-07', 'A0', 'GRA', "I am starting to use 'a', 'an', and 'the' — and I'm learning when to use which one."], ['A0-FLU-01', 'A0', 'FLU', 'I can speak in short sentences on very familiar topics.'], ['A0-FLU-02', 'A0', 'FLU', 'I can keep a simple exchange going for 2–3 turns.'], ['A0-FLU-03', 'A0', 'FLU', 'I can understand someone if they speak slowly and clearly.'], ['A0-FLU-04', 'A0', 'FLU', "I can ask someone to repeat when I don't understand."], ['A0-FLU-05', 'A0', 'FLU', "I can get my meaning across even when I only have a word or two — and I keep trying even when it's difficult."], ['A0-FLU-06', 'A0', 'FLU', "I can introduce myself to someone new in English and keep going even when it's hard."], ['A1-VOC-01', 'A1', 'VOC', 'I can talk about topics like food, travel, weather, shopping, and school.'], ['A1-VOC-02', 'A1', 'VOC', 'I can use words to describe past events and experiences.'], ['A1-VOC-03', 'A1', 'VOC', 'I can use opinion words — I think, I feel, I believe, in my opinion.'], ['A1-VOC-04', 'A1', 'VOC', 'I can use linking words — and, but, because, so, then.'], ['A1-VOC-05', 'A1', 'VOC', 'I can understand and use common phrases in conversation.'], ['A1-VOC-06', 'A1', 'VOC', 'I have enough words to talk about everyday topics and express how I feel.'], ['A1-VOC-07', 'A1', 'VOC', 'I can use words for feelings — excited, nervous, proud, bored.'], ['A1-GRA-01', 'A1', 'GRA', 'I can talk about the past using past simple — I went, I ate, I saw.'], ['A1-GRA-02', 'A1', 'GRA', "I can use 'going to' to talk about future plans."], ['A1-GRA-03', 'A1', 'GRA', 'I can use comparative adjectives — bigger, faster, more interesting.'], ['A1-GRA-04', 'A1', 'GRA', "I can use 'can' and 'can't' to talk about ability."], ['A1-GRA-05', 'A1', 'GRA', "I can use 'should' to give simple advice."], ['A1-GRA-06', 'A1', 'GRA', "I can use 'there is' and 'there are' to describe places."], ['A1-GRA-07', 'A1', 'GRA', 'I can ask questions using who, what, where, when, and why.'], ['A1-FLU-01', 'A1', 'FLU', 'I can hold a short conversation on familiar topics without long silences.'], ['A1-FLU-02', 'A1', 'FLU', "I can understand the main point even when I don't catch every word."], ['A1-FLU-03', 'A1', 'FLU', "I can use simple phrases to buy time — 'let me think', 'I mean'."], ['A1-FLU-04', 'A1', 'FLU', 'I can repair a conversation when I make a mistake.'], ['A1-FLU-05', 'A1', 'FLU', 'I can speak at a slow but steady pace on topics I know well.'], ['A1-FLU-06', 'A1', 'FLU', 'I can talk about my daily life, interests, and opinions — and it feels like a real conversation.'], ['A2-VOC-01', 'A2', 'VOC', 'I can discuss topics like health, education, and technology in simple terms.'], ['A2-VOC-02', 'A2', 'VOC', "I can use more specific words to make my ideas clearer — not just 'nice' but 'generous', not just 'said' but 'explained'."], ['A2-VOC-03', 'A2', 'VOC', 'I can understand and use common idioms and fixed phrases.'], ['A2-VOC-04', 'A2', 'VOC', 'I can use contrast words — however, on the other hand, although.'], ['A2-VOC-05', 'A2', 'VOC', 'I can use sequence words — first, then, after that, finally.'], ['A2-VOC-06', 'A2', 'VOC', 'I have enough vocabulary to discuss a range of topics and organise my ideas clearly.'], ['A2-VOC-07', 'A2', 'VOC', 'I can use formal and informal vocabulary depending on the situation.'], ['A2-GRA-01', 'A2', 'GRA', 'I can use present perfect to talk about experiences — I have visited, I have tried.'], ['A2-GRA-02', 'A2', 'GRA', "I can use 'will' and 'going to' to talk about the future in different ways."], ['A2-GRA-03', 'A2', 'GRA', 'I can use first conditional — If I study, I will pass.'], ['A2-GRA-04', 'A2', 'GRA', 'I can use modal verbs — might, should, could, must — with reasonable accuracy.'], ['A2-GRA-05', 'A2', 'GRA', 'I can use relative clauses — the person who, the place where.'], ['A2-GRA-06', 'A2', 'GRA', 'I can use a range of tenses together in a story or description.'], ['A2-GRA-07', 'A2', 'GRA', 'I can use passive sentences — It was made, It is used.'], ['A2-FLU-01', 'A2', 'FLU', 'I can speak for about a minute on a familiar topic without stopping.'], ['A2-FLU-02', 'A2', 'FLU', 'I can keep a conversation going even when I make grammar mistakes.'], ['A2-FLU-03', 'A2', 'FLU', 'I can switch between topics naturally in a conversation.'], ['A2-FLU-04', 'A2', 'FLU', 'I can understand most of what someone says even at a normal pace.'], ['A2-FLU-05', 'A2', 'FLU', 'I can express and explain my opinions clearly enough to be understood.'], ['A2-FLU-06', 'A2', 'FLU', "I can join a conversation, add my ideas, and keep things going — even on topics I didn't prepare for."], ['A2-FLU-07', 'A2', 'FLU', 'I can tell a story or describe an event with a clear structure.'], ['B1-VOC-01', 'B1', 'VOC', 'I can discuss abstract and complex topics — justice, identity, progress, culture.'], ['B1-VOC-02', 'B1', 'VOC', 'I can use a wide range of vocabulary including less common words.'], ['B1-VOC-03', 'B1', 'VOC', 'I can use idiomatic language naturally without it sounding forced.'], ['B1-VOC-04', 'B1', 'VOC', 'I can choose precise words to say exactly what I mean.'], ['B1-VOC-05', 'B1', 'VOC', "I can understand vocabulary in context even if I haven't seen it before."], ['B1-VOC-06', 'B1', 'VOC', 'I have a wide vocabulary that lets me say what I mean, even on complex topics.'], ['B1-VOC-07', 'B1', 'VOC', 'I can use different registers — casual with friends, formal in a debate.'], ['B1-GRA-01', 'B1', 'GRA', 'I can use a wide range of tenses accurately in extended speech.'], ['B1-GRA-02', 'B1', 'GRA', 'I can use complex conditionals — If I had studied, I would have passed.'], ['B1-GRA-03', 'B1', 'GRA', 'I can use reported speech — She said that she would come.'], ['B1-GRA-04', 'B1', 'GRA', 'I can use a range of linking devices to build clear, structured arguments.'], ['B1-GRA-05', 'B1', 'GRA', 'I can use passive and active voice flexibly depending on emphasis.'], ['B1-GRA-06', 'B1', 'GRA', 'I can use cleft sentences for emphasis — What I mean is… It was she who…'], ['B1-GRA-07', 'B1', 'GRA', 'I make grammar mistakes occasionally but they rarely affect understanding.'], ['B1-FLU-01', 'B1', 'FLU', 'I can speak naturally and at a comfortable pace without noticeable effort.'], ['B1-FLU-02', 'B1', 'FLU', 'I can handle interruptions and unexpected questions without losing my thread.'], ['B1-FLU-03', 'B1', 'FLU', 'I can argue, persuade, and negotiate in English with confidence.'], ['B1-FLU-04', 'B1', 'FLU', 'I can understand fast, natural speech including different accents.'], ['B1-FLU-05', 'B1', 'FLU', 'I can pick up on tone and emotion — sarcasm, humour, frustration — in conversation.'], ['B1-FLU-06', 'B1', 'FLU', 'I can recover from mistakes smoothly without the conversation breaking down.'], ['B1-FLU-07', 'B1', 'FLU', 'I can express who I am in English — my personality, my opinions, my sense of humour.'], ['B2-VOC-01', 'B2', 'VOC', 'I can use a wide range of vocabulary to give and exchange views — on familiar topics and unfamiliar ones.'], ['B2-VOC-02', 'B2', 'VOC', "I can use abstract and less common vocabulary naturally — words like 'empathetic', 'burden', 'asset', 'cycle of life' come up in my speech without effort."], ['B2-VOC-03', 'B2', 'VOC', 'I can choose words precisely — I know the difference between near-synonyms and pick the one that fits the moment.'], ['B2-VOC-04', 'B2', 'VOC', "I can use vocabulary to convey my attitude and point of view, not just the facts — my word choice reflects how I feel about what I'm saying."], ['B2-VOC-05', 'B2', 'VOC', "I can shift between formal and informal language naturally, depending on who I'm speaking to and what the situation calls for."], ['B2-VOC-06', 'B2', 'VOC', 'I have the vocabulary I need for any topic I want to talk about — and I can always find a way to say exactly what I mean.'], ['B2-VOC-07', 'B2', 'VOC', "I sometimes choose a word that isn't quite right, but it rarely gets in the way — I always find a way to get my meaning across."], ['B2-GRA-01', 'B2', 'GRA', 'I can use a wide range of grammatical structures with confidence — complex sentences, passive forms, participle clauses, and more.'], ['B2-GRA-02', 'B2', 'GRA', "I can use modal verbs accurately to speculate, deduce, and express criticism — 'it must have been', 'she could have known', 'they should have acted'."], ['B2-GRA-03', 'B2', 'GRA', 'I can use discourse markers and cohesive devices to organise and connect what I say — my speech flows naturally and is easy for the listener to follow.'], ['B2-GRA-04', 'B2', 'GRA', "I can express complex ideas concisely — I don't just describe things, I can name them precisely and build on them."], ['B2-GRA-05', 'B2', 'GRA', "I can use conditional and hypothetical structures accurately across different tenses — I make occasional minor errors but they don't change my meaning."], ['B2-GRA-06', 'B2', 'GRA', 'I can produce extended, coherent responses that are easy to follow — my ideas connect and build on each other naturally.'], ['B2-GRA-07', 'B2', 'GRA', "I make occasional errors — especially in complex structures — but they rarely affect understanding and don't interrupt the flow of what I'm saying."], ['B2-FLU-01', 'B2', 'FLU', 'I can speak at length with very little hesitation — on familiar topics and on abstract or unfamiliar ones too.'], ['B2-FLU-02', 'B2', 'FLU', 'I can understand and engage with complex ideas, abstract concepts, and unfamiliar subjects in conversation.'], ['B2-FLU-03', 'B2', 'FLU', 'I can contribute effectively to discussions — I develop my own ideas, respond to others, and widen the conversation rather than just answering questions.'], ['B2-FLU-04', 'B2', 'FLU', 'I can adjust how I speak depending on the situation — a casual conversation and a more formal discussion feel equally natural to me.'], ['B2-FLU-05', 'B2', 'FLU', 'My responses are always relevant and coherent — I stay on topic, develop ideas clearly, and use varied language to keep the listener engaged.'], ['B2-FLU-06', 'B2', 'FLU', 'I can interact with ease — I link what I say to what others have said, help move the conversation forward, and negotiate towards a shared understanding.'], ['B2-FLU-07', 'B2', 'FLU', "I can talk about anything that comes up — even topics I haven't prepared for — with confidence and very little hesitation."], ['C1-VOC-01', 'C1', 'VOC', 'I can use vocabulary flexibly and naturally across any topic — my word choices feel appropriate and precise without effort.'], ['C1-VOC-02', 'C1', 'VOC', "I can use less common words and phrases naturally — expressions like 'a detriment to', 'especially in this day and age', 'carry forward', and 'strive for' appear in my speech without sounding forced."], ['C1-VOC-03', 'C1', 'VOC', "I can use idiomatic language, phrasal verbs, and figurative expressions as a natural part of how I speak — not as things I've memorised but as things I've genuinely absorbed."], ['C1-VOC-04', 'C1', 'VOC', 'My vocabulary is flexible enough to allow me to reformulate, paraphrase, and express the same idea in different ways depending on what the moment requires.'], ['C1-VOC-05', 'C1', 'VOC', 'I can discuss abstract ideas and complex concepts with the same ease I use to talk about everyday topics.'], ['C1-VOC-06', 'C1', 'VOC', 'I can use less common and sophisticated words without sounding unnatural — they feel like a genuine part of how I speak.'], ['C1-VOC-07', 'C1', 'VOC', 'My vocabulary feels like mine — precise, flexible, and natural across every topic and situation.'], ['C1-GRA-01', 'C1', 'GRA', 'I use a wide range of grammatical forms with flexibility and accuracy — my language feels natural, not constructed.'], ['C1-GRA-02', 'C1', 'GRA', 'I can use complex structures — complex conditionals, passive forms, embedded clauses — accurately and naturally in extended speech.'], ['C1-GRA-03', 'C1', 'GRA', 'My grammar supports my meaning rather than getting in the way of it — I can say exactly what I mean, even when the idea is complex or abstract.'], ['C1-GRA-04', 'C1', 'GRA', "I can use stress, intonation, and grammatical emphasis to highlight what matters most in what I'm saying."], ['C1-GRA-05', 'C1', 'GRA', 'I make very few errors — and when I do, they are minor and do not affect understanding or the natural flow of my speech.'], ['C1-GRA-06', 'C1', 'GRA', 'I can handle any grammatical demand a conversation places on me — from quick casual responses to extended, structured arguments.'], ['C1-GRA-07', 'C1', 'GRA', 'My grammar is flexible — I can vary my structures to add emphasis, adjust formality, or make my speech more engaging.'], ['C1-FLU-01', 'C1', 'FLU', 'I can communicate on any topic — familiar, unfamiliar, abstract, or complex — with no hesitation.'], ['C1-FLU-02', 'C1', 'FLU', "My contributions are always relevant and well-developed — I don't just respond to what others say, I extend ideas, introduce new angles, and help move the conversation forward."], ['C1-FLU-03', 'C1', 'FLU', 'I can produce extended, coherent stretches of language with flexibility and ease — my speech is organised, varied, and clear even in complex exchanges.'], ['C1-FLU-04', 'C1', 'FLU', 'I can interact with ease — linking my contributions to others, interweaving my ideas into the conversation, and leading discussions towards a conclusion.'], ['C1-FLU-05', 'C1', 'FLU', 'I can adapt the language I use to give emphasis, fit the situation, or be more precise — reformulating and paraphrasing naturally when it helps.'], ['C1-FLU-06', 'C1', 'FLU', 'I can discuss abstract ideas, unfamiliar topics, and complex concepts with accuracy and flexibility — this is what English at its highest level feels like.'], ['C1-FLU-07', 'C1', 'FLU', "English at this level feels effortless — not because it's easy, but because I've made it my own."]]

# Transition Step-by-Step Curriculum
UNITS = {'A0': [{'step': '1', 'name': 'First words', 'focus': 'Naming the things I can see.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can name colours and say numbers 1–10.', 'needs': ['naming']}, {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can name familiar animals and everyday objects at school and home.', 'needs': ['naming']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': "I can use 'a' and 'the' in a simple phrase — a cat, the bag.", 'needs': ['any']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can name things in English when someone points at them.', 'needs': ['naming']}]}, {'step': '2', 'name': 'I am and I have got', 'focus': 'Saying who I am and what I have.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can say my name, my age, and the name of my school and family members.', 'needs': ['naming', 'describing']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': "I can say 'I am' and 'I am not' — I am happy. I am not tired.", 'needs': ['describing']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': "I can use 'I have got' — I have got a dog. I haven't got a sister.", 'needs': ['describing']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can introduce myself in English in a few short phrases.', 'needs': ['any']}]}, {'step': '3', 'name': "I like and I don't like", 'focus': "Saying what I enjoy — and what I don't.", 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can name things I like — food, sports, animals, colours.', 'needs': ['preference']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': "I can say 'I like' and 'I don't like' — I like cricket. I don't like eggs.", 'needs': ['preference']}, {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': "I can use 'and' to join two things — I like cats and dogs.", 'needs': ['any']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': "I can answer 'Do you like...?' with a short sentence, not just yes or no.", 'needs': ['preference']}]}, {'step': '4', 'name': 'I can', 'focus': 'Saying what I am able to do.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can name positions — on, in, under, next to, behind.', 'needs': ['describing']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': "I can use 'can' to say what someone is able to do — I can run. She can't fly.", 'needs': ['describing']}, {'id': 'U4-GRA-02', 'strand': 'GRA', 'text': 'I can say where things are — The bag is on the chair. There is a pen on the table.', 'needs': ['describing']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': "I can answer 'What can you do?' with a simple sentence.", 'needs': ['any']}]}, {'step': '5', 'name': 'What is happening?', 'focus': 'Using present continuous and putting it all together in a short exchange.', 'skills': [{'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use present continuous for right now — She is running. They are eating.', 'needs': ['describing']}, {'id': 'U5-GRA-02', 'strand': 'GRA', 'text': 'I can answer questions in the present — What are you doing? I am reading.', 'needs': ['describing']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can keep a simple exchange going for 2–3 turns on a familiar topic.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can keep going even when I only have a few words.', 'needs': ['any']}]}], 'A1': [{'step': '1', 'name': 'Describing the world', 'focus': 'Moving from naming things to describing them.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can describe what people look like and how they feel using simple adjectives.', 'needs': ['describing']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use the present continuous to describe what is happening now — She is running.', 'needs': ['describing']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can describe a picture or a place using 3–4 connected sentences.', 'needs': ['describing']}]}, {'step': '2', 'name': 'Talking about the past', 'focus': 'Starting to use past tense to share what happened.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use past time expressions — yesterday, last week, a long time ago.', 'needs': ['past_event']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use past simple with regular verbs — I walked, I watched, I played.', 'needs': ['past_event']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use some irregular past verbs — I went, I saw, I ate, I had.', 'needs': ['past_event']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can talk about something I did recently in a few connected sentences.', 'needs': ['past_event', 'narrative']}]}, {'step': '3', 'name': 'Giving opinions and reasons', 'focus': 'Beginning to say what I think and why.', 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use simple opinion words — I think, I feel, I prefer, I love, I hate.', 'needs': ['preference', 'opinion']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': "I can use 'because' to give a reason — I like cricket because it's exciting.", 'needs': ['preference', 'opinion']}, {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': "I can use 'but' to show contrast — I like football but not swimming.", 'needs': ['preference', 'comparison']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can share a simple opinion and give at least one reason for it.', 'needs': ['opinion']}]}, {'step': '4', 'name': 'Talking about plans', 'focus': 'Extending into the future — making and sharing plans.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use frequency words — always, usually, sometimes, never, often.', 'needs': ['routine']}, {'id': 'U4-VOC-02', 'strand': 'VOC', 'text': 'I can use future time expressions — tomorrow, next week, soon, one day.', 'needs': ['future_plan']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': "I can use 'going to' to talk about a plan — I'm going to study tonight.", 'needs': ['future_plan']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can talk about what I am going to do and give a simple reason why.', 'needs': ['future_plan', 'opinion']}]}, {'step': '5', 'name': 'Holding a real conversation', 'focus': 'Using everything together in a real back-and-forth.', 'skills': [{'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use connecting phrases — first, then, after that, in the end.', 'needs': ['narrative']}, {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use present simple, present continuous, and past simple together in a story.', 'needs': ['any']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can hold a short back-and-forth conversation on a familiar topic without long pauses.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': "I can keep going even when I'm not 100% sure of every word.", 'needs': ['any']}]}], 'A2': [{'step': '1', 'name': 'Finding better words', 'focus': 'Moving from words that work to words that feel right.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can use a wider range of descriptive words to make my ideas more interesting.', 'needs': ['describing']}, {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can understand and use common idioms I hear regularly.', 'needs': ['any']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': "I can use present perfect to connect past and present — I've lived here for 3 years.", 'needs': ['past_event', 'narrative']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': "I can express an idea in more than one way when I'm not sure of a word.", 'needs': ['any']}]}, {'step': '2', 'name': 'Talking about the past with more precision', 'focus': 'Describing not just what happened, but what was happening and what used to be.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use sequence and contrast words — however, although, even though.', 'needs': ['narrative', 'comparison']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use past continuous with past simple — I was eating when she called.', 'needs': ['past_event', 'narrative']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': "I can use 'used to' to talk about past habits.", 'needs': ['past_event', 'routine']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can tell a story that moves naturally between past and present.', 'needs': ['narrative', 'past_event']}]}, {'step': '3', 'name': 'Expressing opinions with depth', 'focus': 'Moving from simple opinions to supported arguments.', 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use reporting words — I think, I believe, in my opinion, it seems to me.', 'needs': ['opinion']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use first conditional — If I study hard, I will pass.', 'needs': ['hypothetical']}, {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': 'I can use modal verbs — might, could, should, must — with reasonable accuracy.', 'needs': ['opinion', 'hypothetical']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can give an opinion, support it with a reason, and add an example.', 'needs': ['opinion', 'explanation']}]}, {'step': '4', 'name': 'Speaking for longer without losing the thread', 'focus': 'Building up to a full minute of organised, connected speech.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use linking adverbials — as a result, in addition, on the other hand.', 'needs': ['explanation', 'narrative']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use relative clauses to add detail — the person who, the place where.', 'needs': ['any']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can speak for about 1 minute on a familiar topic without stopping.', 'needs': ['any']}, {'id': 'U4-FLU-02', 'strand': 'FLU', 'text': 'I can organise what I say so others can follow my thinking easily.', 'needs': ['any']}]}, {'step': '5', 'name': 'Handling unpredictable conversations', 'focus': 'Communicating flexibly in varied situations.', 'skills': [{'id': 'U5-VOC-01', 'strand': 'VOC', 'text': "I can use formal and informal vocabulary depending on who I'm talking to.", 'needs': ['any']}, {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use a range of tenses together accurately in an extended story or explanation.', 'needs': ['narrative', 'past_event']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can switch between topics in a conversation without losing the thread.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': "I feel comfortable joining a conversation I didn't prepare for.", 'needs': ['any']}]}], 'B1': [{'step': '1', 'name': 'Precision in vocabulary', 'focus': 'Choosing more exact and sophisticated words.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can use a wider range of vocabulary including less common and more precise words.', 'needs': ['any']}, {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can use collocations naturally — make a decision, pay attention, take a risk.', 'needs': ['any']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use second conditional fluently — If I had more time, I would travel more.', 'needs': ['hypothetical']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can express a complex idea clearly without simplifying it too much.', 'needs': ['abstract', 'opinion']}]}, {'step': '2', 'name': 'Using complex grammar naturally', 'focus': 'Using third conditional, reported speech, and hedging language with confidence.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use hedging language — it could be argued, there is some evidence that.', 'needs': ['opinion', 'argumentation']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use third conditional — If I had studied harder, I would have passed.', 'needs': ['hypothetical', 'past_event']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use reported speech fluidly — She said she would come. He asked if I was okay.', 'needs': ['narrative', 'past_event']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can use complex sentences without losing the main point.', 'needs': ['any']}]}, {'step': '3', 'name': 'Speaking at length with coherence', 'focus': 'Building extended, well-organised spoken responses.', 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use discourse markers to organise speech — right, so, as I was saying, anyway.', 'needs': ['any']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use passive and active voice flexibly depending on what I want to emphasise.', 'needs': ['explanation']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can speak for 3–5 minutes on a topic I care about with clear structure.', 'needs': ['any']}, {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can keep a conversation coherent even when the topic shifts.', 'needs': ['any']}]}, {'step': '4', 'name': 'Arguing and persuading', 'focus': 'Moving from sharing opinions to defending and challenging ideas.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use vocabulary for argumentation — claim, evidence, argue, counter, support.', 'needs': ['argumentation']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use a range of linking devices to build structured arguments.', 'needs': ['argumentation', 'opinion']}, {'id': 'U4-GRA-02', 'strand': 'GRA', 'text': 'I can use cleft sentences for emphasis — What I mean is… It was she who…', 'needs': ['any']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': "I can challenge someone's opinion respectfully and explain my own position clearly.", 'needs': ['argumentation', 'opinion']}]}, {'step': '5', 'name': 'Natural, spontaneous fluency', 'focus': 'Speaking without noticeable effort on a wide range of topics.', 'skills': [{'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use different registers — casual, formal, persuasive — depending on context.', 'needs': ['any']}, {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use all B2 grammar structures accurately with very few errors.', 'needs': ['any']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can speak naturally and spontaneously on almost any familiar topic.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I feel like English is a tool I can rely on to express who I really am.', 'needs': ['any']}]}], 'B2': [{'step': '1', 'name': 'Choosing words with more precision and feeling', 'focus': 'Moving from a large vocabulary to a sensitive one — words chosen for effect, not just meaning.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can use sophisticated vocabulary across academic and professional contexts.', 'needs': ['any']}, {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can use abstract vocabulary fluently — paradox, implication, integrity, legacy.', 'needs': ['any']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use inversion for emphasis naturally — Rarely have I heard such an argument.', 'needs': ['any']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can express nuanced ideas, not just basic ones.', 'needs': ['any']}]}, {'step': '2', 'name': 'Complex grammar with ease', 'focus': 'Using advanced grammar without effort or hesitation.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use nominalisation to compress meaning — the rise in, the failure to act.', 'needs': ['any']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use all modal perfects — should have, could have, might have — appropriately.', 'needs': ['any']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use complex noun phrases and participle clauses fluently.', 'needs': ['any']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can produce complex sentences that are still clear and easy to follow.', 'needs': ['any']}]}, {'step': '3', 'name': 'Sustained, coherent discourse', 'focus': 'Holding the floor for extended periods.', 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use linking adverbials and discourse markers fluently — consequently, nevertheless.', 'needs': ['any']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use reference and substitution to avoid repetition across long stretches of speech.', 'needs': ['any']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can speak for several minutes on any topic, organising ideas clearly as I go.', 'needs': ['any']}, {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can hold my own in academic and professional discussions.', 'needs': ['any']}]}, {'step': '4', 'name': 'Register flexibility', 'focus': 'Adapting instantly to any speaking context or audience.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use figurative, idiomatic, and formal vocabulary naturally in the same conversation.', 'needs': ['any']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use a range of emphatic and stylistic structures — clefts, fronting, ellipsis.', 'needs': ['any']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can shift instantly from casual conversation to formal debate without effort.', 'needs': ['any']}]}, {'step': '5', 'name': 'Speaking with real precision and effect', 'focus': 'Language that creates the exact effect the student intends — in any situation.', 'skills': [{'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use vocabulary to convey attitude, irony, humour, and subtle meaning.', 'needs': ['any']}, {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'My grammar is essentially accurate — errors are rare, minor, and self-corrected.', 'needs': ['any']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can communicate complex ideas with the precision and confidence of a skilled speaker.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I feel completely natural when speaking English in any situation.', 'needs': ['any']}]}], 'C1': [{'step': '1', 'name': 'Mastery of vocabulary', 'focus': 'Moving towards native-level vocabulary range and sensitivity.', 'skills': [{'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can use vocabulary with the precision and creativity of a skilled writer.', 'needs': ['any']}, {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can understand and produce language with perfect register and cultural fit.', 'needs': ['any']}, {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use grammatical structures from literary and formal English fluently.', 'needs': ['any']}, {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can communicate any idea I have in English — complex, emotional, abstract, creative.', 'needs': ['any']}]}, {'step': '2', 'name': 'Grammar as craft', 'focus': 'Using grammar not just accurately but artistically.', 'skills': [{'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use figurative, symbolic, and poetic language naturally.', 'needs': ['any']}, {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use grammar to create stylistic effects — rhythm, emphasis, contrast.', 'needs': ['any']}, {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use any grammatical structure found in formal writing or oratory.', 'needs': ['any']}, {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can produce extended, well-structured discourse without any preparation.', 'needs': ['any']}]}, {'step': '3', 'name': 'Full communicative range', 'focus': 'Handling any conversation, audience, or register effortlessly.', 'skills': [{'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can understand cultural allusions, literary references, and historical vocabulary.', 'needs': ['any']}, {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use all forms of reported speech, conditionals, and complex passives naturally.', 'needs': ['any']}, {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can follow and fully engage with native speakers in any context.', 'needs': ['any']}, {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can manage multiparty conversations and take the floor with skill.', 'needs': ['any']}]}, {'step': '4', 'name': 'Language as identity', 'focus': 'English feels like yours — not a language you learned, but one you live in.', 'skills': [{'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use English vocabulary with the same instinct and feeling as in my first language.', 'needs': ['any']}, {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'My grammar is fully automatic — I communicate through it, not with it.', 'needs': ['any']}, {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I feel that English is not a foreign language — it is simply a language I speak.', 'needs': ['any']}]}, {'step': '5', 'name': 'Full mastery', 'focus': 'Arriving at the highest level of English proficiency.', 'skills': [{'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I have mastery of English vocabulary equal to a highly educated native speaker.', 'needs': ['any']}, {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I have complete command of English grammar in all contexts and styles.', 'needs': ['any']}, {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can communicate with precision, warmth, authority, and creativity in English.', 'needs': ['any']}, {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'Language is no longer a barrier — it is a bridge to everything.', 'needs': ['any']}]}]}

# Level-aligned Conversation Topics
LEVEL_TOPICS = {
    "A0": [
        {
            "id": "a0_1",
            "name": "My name and where I'm from",
            "shortName": "My Name",
            "affordances": [
                "naming",
                "describing"
            ]
        },
        {
            "id": "a0_2",
            "name": "My family",
            "shortName": "My Family",
            "affordances": [
                "naming",
                "describing",
                "preference"
            ]
        },
        {
            "id": "a0_3",
            "name": "My school",
            "shortName": "School",
            "affordances": [
                "describing",
                "routine",
                "preference"
            ]
        },
        {
            "id": "a0_4",
            "name": "Food I like",
            "shortName": "Food",
            "affordances": [
                "naming",
                "preference",
                "describing"
            ]
        },
        {
            "id": "a0_5",
            "name": "My daily routine",
            "shortName": "Routine",
            "affordances": [
                "routine",
                "describing",
                "present_action"
            ]
        },
        {
            "id": "a0_6",
            "name": "Things I like and don't like",
            "shortName": "Liking",
            "affordances": [
                "preference"
            ]
        },
        {
            "id": "a0_7",
            "name": "Animals",
            "shortName": "Animals",
            "affordances": [
                "naming",
                "describing",
                "preference"
            ]
        },
        {
            "id": "a0_8",
            "name": "Colours, numbers, and shapes",
            "shortName": "Colours",
            "affordances": [
                "naming"
            ]
        },
        {
            "id": "a0_9",
            "name": "My home",
            "shortName": "Home",
            "affordances": [
                "naming",
                "describing",
                "present_action"
            ]
        },
        {
            "id": "a0_10",
            "name": "Sports and games",
            "shortName": "Sports",
            "affordances": [
                "preference",
                "present_action",
                "describing"
            ]
        },
        {
            "id": "a0_11",
            "name": "Festivals I celebrate",
            "shortName": "Festivals",
            "affordances": [
                "describing",
                "preference",
                "naming"
            ]
        },
        {
            "id": "a0_12",
            "name": "My favourite film, show, or cartoon",
            "shortName": "Favourite Show",
            "affordances": [
                "preference",
                "describing",
                "naming"
            ],
            "isNew": True
        },
        {
            "id": "a0_13",
            "name": "Games we play at break time",
            "shortName": "Break Time",
            "affordances": [
                "present_action",
                "describing",
                "preference"
            ],
            "isNew": True
        },
        {
            "id": "a0_14",
            "name": "My birthday",
            "shortName": "Birthday",
            "affordances": [
                "describing",
                "preference",
                "naming"
            ],
            "isNew": True
        },
        {
            "id": "a0_15",
            "name": "Things I can do",
            "shortName": "Things I Can Do",
            "affordances": [
                "describing",
                "preference"
            ],
            "isNew": True
        },
        {
            "id": "a0_16",
            "name": "My bag and what is inside it",
            "shortName": "My Bag",
            "affordances": [
                "naming",
                "describing",
                "present_action"
            ],
            "isNew": True
        }
    ],
    "A1": [
        {
            "id": "a1_1",
            "name": "My hobbies and free time",
            "shortName": "Hobbies",
            "affordances": [
                "preference",
                "describing",
                "routine"
            ]
        },
        {
            "id": "a1_2",
            "name": "My friends",
            "shortName": "Friends",
            "affordances": [
                "describing",
                "past_event",
                "narrative",
                "preference"
            ]
        },
        {
            "id": "a1_3",
            "name": "A typical week",
            "shortName": "My Week",
            "affordances": [
                "routine",
                "describing"
            ]
        },
        {
            "id": "a1_4",
            "name": "Shopping and markets",
            "shortName": "Shopping",
            "affordances": [
                "describing",
                "preference",
                "past_event"
            ]
        },
        {
            "id": "a1_5",
            "name": "Food and restaurants",
            "shortName": "Eating Out",
            "affordances": [
                "preference",
                "describing",
                "comparison"
            ]
        },
        {
            "id": "a1_6",
            "name": "My city or town",
            "shortName": "My City",
            "affordances": [
                "describing",
                "comparison",
                "opinion"
            ]
        },
        {
            "id": "a1_7",
            "name": "Weather and seasons",
            "shortName": "Weather",
            "affordances": [
                "describing",
                "comparison",
                "routine"
            ]
        },
        {
            "id": "a1_8",
            "name": "Transport and travel",
            "shortName": "Travel",
            "affordances": [
                "describing",
                "preference",
                "past_event"
            ]
        },
        {
            "id": "a1_9",
            "name": "A trip or holiday",
            "shortName": "Trips",
            "affordances": [
                "past_event",
                "narrative",
                "describing"
            ]
        },
        {
            "id": "a1_10",
            "name": "Films and TV shows",
            "shortName": "Films & TV",
            "affordances": [
                "preference",
                "opinion",
                "narrative",
                "describing"
            ]
        },
        {
            "id": "a1_11",
            "name": "Celebrations and special days",
            "shortName": "Celebrations",
            "affordances": [
                "past_event",
                "narrative",
                "describing"
            ]
        },
        {
            "id": "a1_12",
            "name": "School subjects \u2014 likes and dislikes",
            "shortName": "Subjects",
            "affordances": [
                "preference",
                "opinion",
                "comparison"
            ]
        },
        {
            "id": "a1_13",
            "name": "My plans for the holidays",
            "shortName": "Holiday Plans",
            "affordances": [
                "future_plan",
                "preference",
                "narrative"
            ],
            "isNew": True
        },
        {
            "id": "a1_14",
            "name": "A place I want to visit one day",
            "shortName": "Dream Place",
            "affordances": [
                "future_plan",
                "describing",
                "preference"
            ],
            "isNew": True
        },
        {
            "id": "a1_15",
            "name": "What I want to learn next",
            "shortName": "Learning Next",
            "affordances": [
                "future_plan",
                "preference",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "a1_16",
            "name": "A person I look up to",
            "shortName": "Someone I Admire",
            "affordances": [
                "describing",
                "opinion",
                "narrative"
            ],
            "isNew": True
        }
    ],
    "A2": [
        {
            "id": "a2_1",
            "name": "My ambitions and future plans",
            "shortName": "Ambitions",
            "affordances": [
                "future_plan",
                "opinion",
                "hypothetical"
            ]
        },
        {
            "id": "a2_2",
            "name": "My personality and values",
            "shortName": "Who I Am",
            "affordances": [
                "describing",
                "opinion",
                "abstract"
            ]
        },
        {
            "id": "a2_3",
            "name": "Education in India",
            "shortName": "Education",
            "affordances": [
                "opinion",
                "comparison",
                "explanation"
            ]
        },
        {
            "id": "a2_4",
            "name": "Social media and technology",
            "shortName": "Social Media",
            "affordances": [
                "opinion",
                "comparison",
                "explanation"
            ]
        },
        {
            "id": "a2_5",
            "name": "City life vs. village life",
            "shortName": "City vs Village",
            "affordances": [
                "comparison",
                "opinion",
                "describing"
            ]
        },
        {
            "id": "a2_6",
            "name": "Festivals and traditions",
            "shortName": "Traditions",
            "affordances": [
                "narrative",
                "describing",
                "past_event"
            ]
        },
        {
            "id": "a2_7",
            "name": "The environment and pollution",
            "shortName": "Environment",
            "affordances": [
                "opinion",
                "explanation",
                "abstract"
            ]
        },
        {
            "id": "a2_8",
            "name": "Health and lifestyle",
            "shortName": "Health",
            "affordances": [
                "opinion",
                "comparison",
                "explanation"
            ]
        },
        {
            "id": "a2_9",
            "name": "Indian cinema and music",
            "shortName": "Cinema & Music",
            "affordances": [
                "preference",
                "opinion",
                "narrative",
                "describing"
            ]
        },
        {
            "id": "a2_10",
            "name": "Friendship and trust",
            "shortName": "Friendship",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ]
        },
        {
            "id": "a2_11",
            "name": "News and current events",
            "shortName": "The News",
            "affordances": [
                "opinion",
                "explanation",
                "narrative"
            ]
        },
        {
            "id": "a2_12",
            "name": "Cricket and sport in India",
            "shortName": "Cricket & Sport",
            "affordances": [
                "preference",
                "narrative",
                "opinion",
                "comparison"
            ]
        },
        {
            "id": "a2_13",
            "name": "How my life has changed since I was younger",
            "shortName": "Growing Up",
            "affordances": [
                "past_event",
                "routine",
                "narrative",
                "comparison"
            ],
            "isNew": True
        },
        {
            "id": "a2_14",
            "name": "A time I had to make a difficult choice",
            "shortName": "Hard Choices",
            "affordances": [
                "past_event",
                "narrative",
                "opinion",
                "hypothetical"
            ],
            "isNew": True
        },
        {
            "id": "a2_15",
            "name": "Rules I would change if I were in charge",
            "shortName": "My Rules",
            "affordances": [
                "hypothetical",
                "opinion",
                "argumentation"
            ],
            "isNew": True
        },
        {
            "id": "a2_16",
            "name": "A misunderstanding that taught me something",
            "shortName": "Mix-Ups",
            "affordances": [
                "past_event",
                "narrative",
                "explanation"
            ],
            "isNew": True
        },
        {
            "id": "a2_17",
            "name": "My family",
            "shortName": "My Family",
            "affordances": [
                "describing",
                "narrative",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "a2_18",
            "name": "Food and cooking",
            "shortName": "Food",
            "affordances": [
                "preference",
                "describing",
                "narrative"
            ],
            "isNew": True
        }
    ],
    "B1": [
        {
            "id": "b1_1",
            "name": "Culture and identity",
            "shortName": "Culture",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ]
        },
        {
            "id": "b1_2",
            "name": "Gender equality in India",
            "shortName": "Gender Equality",
            "affordances": [
                "opinion",
                "argumentation",
                "abstract"
            ]
        },
        {
            "id": "b1_3",
            "name": "Education and success",
            "shortName": "Success",
            "affordances": [
                "opinion",
                "abstract",
                "comparison"
            ]
        },
        {
            "id": "b1_4",
            "name": "AI and the future of work",
            "shortName": "AI & Work",
            "affordances": [
                "abstract",
                "opinion",
                "hypothetical"
            ]
        },
        {
            "id": "b1_5",
            "name": "Social media, mental health, young people",
            "shortName": "Youth & Mind",
            "affordances": [
                "opinion",
                "explanation",
                "abstract"
            ]
        },
        {
            "id": "b1_6",
            "name": "Climate change and India's responsibility",
            "shortName": "Climate & India",
            "affordances": [
                "argumentation",
                "explanation",
                "abstract"
            ]
        },
        {
            "id": "b1_7",
            "name": "Migration and opportunity",
            "shortName": "Migration",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ]
        },
        {
            "id": "b1_8",
            "name": "Tradition vs. modernity",
            "shortName": "Old vs New",
            "affordances": [
                "comparison",
                "abstract",
                "opinion"
            ]
        },
        {
            "id": "b1_9",
            "name": "Fake news and media literacy",
            "shortName": "Fake News",
            "affordances": [
                "opinion",
                "explanation",
                "argumentation"
            ]
        },
        {
            "id": "b1_10",
            "name": "Entrepreneurship and startups",
            "shortName": "Startups",
            "affordances": [
                "narrative",
                "opinion",
                "explanation"
            ]
        },
        {
            "id": "b1_11",
            "name": "Indian literature and storytelling",
            "shortName": "Indian Stories",
            "affordances": [
                "abstract",
                "narrative",
                "opinion"
            ]
        },
        {
            "id": "b1_12",
            "name": "Privilege and opportunity",
            "shortName": "Privilege",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "b1_13",
            "name": "A belief I changed my mind about",
            "shortName": "Changed My Mind",
            "affordances": [
                "narrative",
                "past_event",
                "opinion",
                "abstract"
            ],
            "isNew": True
        },
        {
            "id": "b1_14",
            "name": "What would India look like in 50 years?",
            "shortName": "India 2075",
            "affordances": [
                "hypothetical",
                "abstract",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "b1_15",
            "name": "Is it ever OK to break a rule?",
            "shortName": "Breaking Rules",
            "affordances": [
                "hypothetical",
                "argumentation",
                "abstract"
            ],
            "isNew": True
        },
        {
            "id": "b1_16",
            "name": "A decision that changed someone's life",
            "shortName": "Big Decisions",
            "affordances": [
                "past_event",
                "narrative",
                "hypothetical",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "b1_17",
            "name": "Sports and games I follow and play",
            "shortName": "Sports",
            "affordances": [
                "opinion",
                "narrative",
                "comparison",
                "hypothetical"
            ],
            "isNew": True
        },
        {
            "id": "b1_18",
            "name": "Music and entertainment I enjoy",
            "shortName": "Music",
            "affordances": [
                "preference",
                "opinion",
                "narrative"
            ],
            "isNew": True
        },
        {
            "id": "b1_19",
            "name": "My family and the people close to me",
            "shortName": "My Family",
            "affordances": [
                "describing",
                "narrative",
                "opinion",
                "abstract"
            ],
            "isNew": True
        },
        {
            "id": "b1_20",
            "name": "Food, cooking, and what it means to me",
            "shortName": "Food",
            "affordances": [
                "preference",
                "narrative",
                "opinion",
                "comparison"
            ],
            "isNew": True
        }
    ],
    "B2": [
        {
            "id": "b2_1",
            "name": "What does it mean to be Indian today?",
            "shortName": "Being Indian",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ]
        },
        {
            "id": "b2_2",
            "name": "Moral dilemmas in everyday life",
            "shortName": "Moral Dilemmas",
            "affordances": [
                "hypothetical",
                "argumentation",
                "abstract"
            ]
        },
        {
            "id": "b2_3",
            "name": "The ethics of AI",
            "shortName": "AI Ethics",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "b2_4",
            "name": "Caste, class, and social mobility",
            "shortName": "Caste & Class",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "b2_5",
            "name": "Sustainability and lifestyle choices",
            "shortName": "Sustainability",
            "affordances": [
                "argumentation",
                "comparison",
                "abstract"
            ]
        },
        {
            "id": "b2_6",
            "name": "Mental health and stigma",
            "shortName": "Mental Health",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ]
        },
        {
            "id": "b2_7",
            "name": "Democracy and young people",
            "shortName": "Youth & Democracy",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "b2_8",
            "name": "English in India \u2014 opportunity or inequality?",
            "shortName": "English in India",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "b2_9",
            "name": "Art, music, and what they say about a society",
            "shortName": "Art & Society",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ]
        },
        {
            "id": "b2_10",
            "name": "Success, happiness, and meaning",
            "shortName": "What Is Success?",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ]
        },
        {
            "id": "b2_11",
            "name": "India's role in the world",
            "shortName": "India & World",
            "affordances": [
                "abstract",
                "argumentation",
                "explanation"
            ]
        },
        {
            "id": "b2_12",
            "name": "Science, superstition, and belief",
            "shortName": "Science vs Belief",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "b2_13",
            "name": "Is creativity learned or innate?",
            "shortName": "Creativity",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ],
            "isNew": True
        },
        {
            "id": "b2_14",
            "name": "Should history be taught differently?",
            "shortName": "Rethink History",
            "affordances": [
                "argumentation",
                "abstract",
                "comparison"
            ],
            "isNew": True
        },
        {
            "id": "b2_15",
            "name": "Privacy vs. security",
            "shortName": "Privacy vs Safety",
            "affordances": [
                "argumentation",
                "abstract",
                "hypothetical"
            ],
            "isNew": True
        },
        {
            "id": "b2_16",
            "name": "What does \"home\" really mean?",
            "shortName": "Meaning of Home",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ],
            "isNew": True
        },
        {
            "id": "b2_17",
            "name": "Sport and what it means to me",
            "shortName": "Sports",
            "affordances": [
                "opinion",
                "narrative",
                "abstract",
                "argumentation"
            ],
            "isNew": True
        },
        {
            "id": "b2_18",
            "name": "Music and its role in my life",
            "shortName": "Music",
            "affordances": [
                "opinion",
                "abstract",
                "narrative"
            ],
            "isNew": True
        },
        {
            "id": "b2_19",
            "name": "Family, relationships, and what shapes us",
            "shortName": "My Family",
            "affordances": [
                "abstract",
                "narrative",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "b2_20",
            "name": "Food, culture, and identity",
            "shortName": "Food",
            "affordances": [
                "abstract",
                "opinion",
                "narrative",
                "comparison"
            ],
            "isNew": True
        }
    ],
    "C1": [
        {
            "id": "c1_1",
            "name": "Does language shape thought?",
            "shortName": "Language & Thought",
            "affordances": [
                "abstract",
                "explanation",
                "opinion"
            ]
        },
        {
            "id": "c1_2",
            "name": "Justice, fairness, and what we owe each other",
            "shortName": "Justice",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "c1_3",
            "name": "How do we know what we know?",
            "shortName": "Knowledge",
            "affordances": [
                "abstract",
                "explanation",
                "opinion"
            ]
        },
        {
            "id": "c1_4",
            "name": "What makes us human in an age of machines?",
            "shortName": "Being Human",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "c1_5",
            "name": "Power, privilege, and who gets to tell the story",
            "shortName": "Power & Story",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ]
        },
        {
            "id": "c1_6",
            "name": "The future of democracy",
            "shortName": "Future Democracy",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "c1_7",
            "name": "The ethics of genetic technology",
            "shortName": "Gene Ethics",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "c1_8",
            "name": "What is art for?",
            "shortName": "Purpose of Art",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ]
        },
        {
            "id": "c1_9",
            "name": "The self \u2014 fixed or fluid?",
            "shortName": "The Self",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ]
        },
        {
            "id": "c1_10",
            "name": "The limits of globalisation",
            "shortName": "Globalisation",
            "affordances": [
                "abstract",
                "argumentation",
                "comparison"
            ]
        },
        {
            "id": "c1_11",
            "name": "Freedom \u2014 how much is too much?",
            "shortName": "Limits of Freedom",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "c1_12",
            "name": "What do we owe future generations?",
            "shortName": "Future Generations",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ]
        },
        {
            "id": "c1_13",
            "name": "Is there such a thing as a universal moral truth?",
            "shortName": "Moral Truth",
            "affordances": [
                "abstract",
                "argumentation",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "c1_14",
            "name": "The ethics of memory \u2014 choosing to forget",
            "shortName": "Right to Forget",
            "affordances": [
                "abstract",
                "hypothetical",
                "opinion"
            ],
            "isNew": True
        },
        {
            "id": "c1_15",
            "name": "Individual responsibility in a broken system",
            "shortName": "Broken Systems",
            "affordances": [
                "abstract",
                "argumentation",
                "hypothetical"
            ],
            "isNew": True
        },
        {
            "id": "c1_16",
            "name": "Can humour change the world?",
            "shortName": "Power of Humour",
            "affordances": [
                "abstract",
                "opinion",
                "argumentation"
            ],
            "isNew": True
        },
        {
            "id": "c1_17",
            "name": "Sport, competition, and what drives us",
            "shortName": "Sports",
            "affordances": [
                "abstract",
                "opinion",
                "argumentation"
            ],
            "isNew": True
        },
        {
            "id": "c1_18",
            "name": "Music, art, and emotion",
            "shortName": "Music",
            "affordances": [
                "abstract",
                "opinion",
                "explanation"
            ],
            "isNew": True
        },
        {
            "id": "c1_19",
            "name": "Family, belonging, and identity",
            "shortName": "My Family",
            "affordances": [
                "abstract",
                "opinion",
                "narrative"
            ],
            "isNew": True
        },
        {
            "id": "c1_20",
            "name": "Food, culture, and memory",
            "shortName": "Food",
            "affordances": [
                "abstract",
                "narrative",
                "opinion"
            ],
            "isNew": True
        }
    ]
}

# Maps for quick lookup
SKILLS = {item[0]: {"level": item[1], "strand": item[2], "text": item[3]} for item in CAT}

UNIT_SKILLS = {}
UNIT_SKILLS_BY_LEVEL = {}
for lvl, u_list in UNITS.items():
    for u in u_list:
        for s in u["skills"]:
            metadata = {
                "id": s["id"],
                "strand": s["strand"],
                "text": s["text"],
                "step": u["step"],
                "step_name": u["name"],
                "level": lvl
            }
            UNIT_SKILLS_BY_LEVEL[(lvl, s["id"])] = metadata
            # Backward-compatible membership/strand map. Unit IDs repeat at
            # every level, so never use this map for level-less text lookup.
            UNIT_SKILLS.setdefault(s["id"], metadata)

STRANDS = {
    "VOC": "Vocabulary",
    "GRA": "Grammar",
    "FLU": "Fluency"
}

OWN_BAR = {
    "A0": 0.70,
    "A1": 0.70,
    "A2": 0.70,
    "B1": 0.70,
    "B2": 0.70,
    "C1": 0.70
}

FLOOR = 0.70
SIGHTINGS_TO_OWN = 3

# Skill Affordances Mapping
SKILL_AFFORDANCES = {
    "A0-VOC-01": ["naming"],
    "A0-VOC-02": ["naming"],
    "A0-VOC-03": ["any"],
    "A0-VOC-04": ["naming"],
    "A0-VOC-05": ["naming", "describing"],
    "A0-VOC-06": ["describing"],
    "A0-VOC-07": ["describing"],
    "A0-GRA-01": ["any"],
    "A0-GRA-02": ["preference"],
    "A0-GRA-03": ["preference"],
    "A0-GRA-04": ["any"],
    "A0-GRA-05": ["preference"],
    "A0-GRA-06": ["describing"],
    "A0-GRA-07": ["describing"],
    "A0-FLU-01": ["describing"],
    "A0-FLU-02": ["any"],
    "A0-FLU-03": ["describing"],
    "A0-FLU-04": ["describing"],
    "A0-FLU-05": ["any"],
    "A0-FLU-06": ["any"],
    "A1-VOC-01": ["describing"],
    "A1-VOC-02": ["describing"],
    "A1-VOC-03": ["describing"],
    "A1-VOC-04": ["past_event"],
    "A1-VOC-05": ["past_event"],
    "A1-VOC-06": ["past_event"],
    "A1-VOC-07": ["past_event", "narrative"],
    "A1-GRA-01": ["preference", "opinion"],
    "A1-GRA-02": ["preference", "opinion"],
    "A1-GRA-03": ["preference", "comparison"],
    "A1-GRA-04": ["opinion"],
    "A1-GRA-05": ["routine"],
    "A1-GRA-06": ["future_plan"],
    "A1-GRA-07": ["future_plan"],
    "A1-FLU-01": ["future_plan", "opinion"],
    "A1-FLU-02": ["narrative"],
    "A1-FLU-03": ["any"],
    "A1-FLU-04": ["any"],
    "A1-FLU-05": ["any"],
    "A1-FLU-06": ["any"],
    "A2-VOC-01": ["describing"],
    "A2-VOC-02": ["any"],
    "A2-VOC-03": ["past_event", "narrative"],
    "A2-VOC-04": ["any"],
    "A2-VOC-05": ["narrative", "comparison"],
    "A2-VOC-06": ["past_event", "narrative"],
    "A2-VOC-07": ["past_event", "routine"],
    "A2-GRA-01": ["narrative", "past_event"],
    "A2-GRA-02": ["opinion"],
    "A2-GRA-03": ["hypothetical"],
    "A2-GRA-04": ["opinion", "hypothetical"],
    "A2-GRA-05": ["opinion", "explanation"],
    "A2-GRA-06": ["explanation", "narrative"],
    "A2-GRA-07": ["any"],
    "A2-FLU-01": ["any"],
    "A2-FLU-02": ["any"],
    "A2-FLU-03": ["any"],
    "A2-FLU-04": ["narrative", "past_event"],
    "A2-FLU-05": ["any"],
    "A2-FLU-06": ["any"],
    "A2-FLU-07": ["any"],
    "B1-VOC-01": ["any"],
    "B1-VOC-02": ["any"],
    "B1-VOC-03": ["hypothetical"],
    "B1-VOC-04": ["abstract", "opinion"],
    "B1-VOC-05": ["opinion", "argumentation"],
    "B1-VOC-06": ["hypothetical", "past_event"],
    "B1-VOC-07": ["narrative", "past_event"],
    "B1-GRA-01": ["any"],
    "B1-GRA-02": ["any"],
    "B1-GRA-03": ["explanation"],
    "B1-GRA-04": ["any"],
    "B1-GRA-05": ["any"],
    "B1-GRA-06": ["argumentation"],
    "B1-GRA-07": ["argumentation", "opinion"],
    "B1-FLU-01": ["any"],
    "B1-FLU-02": ["argumentation", "opinion"],
    "B1-FLU-03": ["any"],
    "B1-FLU-04": ["any"],
    "B1-FLU-05": ["any"],
    "B1-FLU-06": ["any"],
    "B1-FLU-07": ["any"],
    "B2-VOC-01": ["any"],
    "B2-VOC-02": ["abstract", "argumentation"],
    "B2-VOC-03": ["any"],
    "B2-VOC-04": ["any"],
    "B2-VOC-05": ["any"],
    "B2-VOC-06": ["any"],
    "B2-VOC-07": ["any"],
    "B2-GRA-01": ["any"],
    "B2-GRA-02": ["any"],
    "B2-GRA-03": ["any"],
    "B2-GRA-04": ["any"],
    "B2-GRA-05": ["any"],
    "B2-GRA-06": ["any"],
    "B2-GRA-07": ["any"],
    "B2-FLU-01": ["any"],
    "B2-FLU-02": ["any"],
    "B2-FLU-03": ["any"],
    "B2-FLU-04": ["any"],
    "B2-FLU-05": ["any"],
    "B2-FLU-06": ["any"],
    "B2-FLU-07": ["any"],
    "C1-VOC-01": ["any"],
    "C1-VOC-02": ["any"],
    "C1-VOC-03": ["any"],
    "C1-VOC-04": ["any"],
    "C1-VOC-05": ["any"],
    "C1-VOC-06": ["any"],
    "C1-VOC-07": ["any"],
    "C1-GRA-01": ["any"],
    "C1-GRA-02": ["any"],
    "C1-GRA-03": ["any"],
    "C1-GRA-04": ["any"],
    "C1-GRA-05": ["any"],
    "C1-GRA-06": ["any"],
    "C1-GRA-07": ["any"],
    "C1-FLU-01": ["any"],
    "C1-FLU-02": ["any"],
    "C1-FLU-03": ["any"],
    "C1-FLU-04": ["any"],
    "C1-FLU-05": ["any"],
    "C1-FLU-06": ["any"],
    "C1-FLU-07": ["any"],
}

# Backward-compatible re-exports (lazy to avoid circular imports)
def __getattr__(name):
    _HELPERS = {
        "_normalise_level", "_split_unit_progress_key", "unit_progress_key",
        "progress_key_for", "public_skill_id", "is_valid_skill_for_level",
        "make_due_next", "validate_due_next", "progress_value",
        "public_progress_for_level", "get_skill_text", "get_skill_strand",
        "own_bar", "bucket_of",
    }
    _ENGINE = {
        "unit_complete", "active_step", "prioritize_skills",
        "due_unit", "due_skill", "targets_list_for", "apply_merge",
    }
    if name in _HELPERS:
        from app.core import curriculum_helpers
        return getattr(curriculum_helpers, name)
    if name in _ENGINE:
        from app.core import progression_engine
        return getattr(progression_engine, name)
    raise AttributeError(f"module 'app.core.curriculum_data' has no attribute {name!r}")

