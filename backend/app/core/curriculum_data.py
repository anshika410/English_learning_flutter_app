from __future__ import annotations
# Generated from topic-skill-affordance-v6.md
# Do not modify manually.

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
CAT = [
    ['A0-VOC-01', 'A0', 'VOC', 'I can name familiar objects, animals, or colours when they come up in conversation.'],
    ['A0-VOC-02', 'A0', 'VOC', 'I can use basic numbers when they come up in a simple conversation.'],
    ['A0-GRA-01', 'A0', 'GRA', 'I can use a, an, or the when naming a familiar object.'],
    ['A0-FLU-01', 'A0', 'FLU', 'I can respond to a simple question with a familiar word or short phrase.'],
    ['A0-FLU-02', 'A0', 'FLU', 'I can give a simple introduction with a name and age.'],
    ['A0-VOC-03', 'A0', 'VOC', 'I can say who someone is in a family.'],
    ['A0-GRA-02', 'A0', 'GRA', 'I can use I am or I am not to describe myself or a character.'],
    ['A0-GRA-03', 'A0', 'GRA', 'I can say what I or another person has.'],
    ['A0-VOC-04', 'A0', 'VOC', 'I can use familiar food, activity, animal, or colour words when they come up in conversation.'],
    ['A0-GRA-04', 'A0', 'GRA', "I can use I like or I don't like to express a preference."],
    ['A0-GRA-05', 'A0', 'GRA', 'I can use and to add another word or idea.'],
    ['A0-FLU-03', 'A0', 'FLU', 'I can take part in a simple conversation about likes and dislikes.'],
    ['A0-VOC-05', 'A0', 'VOC', 'I can use familiar action or position words when describing a simple situation.'],
    ['A0-GRA-06', 'A0', 'GRA', "I can use can or can't to talk about ability."],
    ['A0-GRA-07', 'A0', 'GRA', 'I can use a simple location sentence to say where something is.'],
    ['A0-FLU-04', 'A0', 'FLU', 'I can take part in a simple exchange about abilities or locations.'],
    ['A0-VOC-06', 'A0', 'VOC', 'I can use familiar action words when talking about what someone is doing.'],
    ['A0-GRA-08', 'A0', 'GRA', 'I can use the present continuous to say what is happening now.'],
    ['A0-FLU-05', 'A0', 'FLU', 'I can take part in a short exchange about a current activity.'],
    ['A0-FLU-06', 'A0', 'FLU', 'I can ask for repetition when I do not understand.'],
    ['A1-VOC-01', 'A1', 'VOC', 'I can use simple adjectives to describe how a person looks or feels.'],
    ['A1-GRA-01', 'A1', 'GRA', 'I can use the present continuous throughout a brief description of a scene.'],
    ['A1-FLU-01', 'A1', 'FLU', 'I can give a short, connected description of a person, place, or scene.'],
    ['A1-FLU-02', 'A1', 'FLU', 'I can answer a follow-up question by adding a relevant detail.'],
    ['A1-VOC-02', 'A1', 'VOC', 'I can use familiar past-time words when talking about an event.'],
    ['A1-GRA-02', 'A1', 'GRA', 'I can use common past-simple verbs to talk about completed actions.'],
    ['A1-FLU-03', 'A1', 'FLU', 'I can recount a short event in a clear order.'],
    ['A1-FLU-04', 'A1', 'FLU', 'I can answer a simple question about a short spoken story.'],
    ['A1-VOC-03', 'A1', 'VOC', 'I can use familiar phrases to introduce an opinion.'],
    ['A1-GRA-03', 'A1', 'GRA', 'I can use because to connect an opinion to a reason.'],
    ['A1-GRA-04', 'A1', 'GRA', 'I can use but to contrast two simple ideas.'],
    ['A1-FLU-05', 'A1', 'FLU', 'I can explain a simple opinion and respond to a related follow-up.'],
    ['A1-VOC-04', 'A1', 'VOC', 'I can use familiar time words when talking about routines or plans.'],
    ['A1-GRA-05', 'A1', 'GRA', 'I can use going to to talk about a plan.'],
    ['A1-FLU-06', 'A1', 'FLU', 'I can discuss a simple plan and respond to a question about it.'],
    ['A1-VOC-05', 'A1', 'VOC', 'I can use simple sequence words to organise what I say.'],
    ['A1-GRA-06', 'A1', 'GRA', 'I can move between present and past forms when the meaning requires it.'],
    ['A1-FLU-07', 'A1', 'FLU', 'I can stay in a familiar-topic conversation as it develops.'],
    ['A1-FLU-08', 'A1', 'FLU', 'I can ask for repetition or say something another way after a communication problem.'],
    ['A2-VOC-01', 'A2', 'VOC', 'I can replace a general word with a more precise descriptive word.'],
    ['A2-VOC-02', 'A2', 'VOC', 'I can use a familiar fixed expression appropriately in conversation.'],
    ['A2-GRA-01', 'A2', 'GRA', 'I can use the present perfect when a past experience or continuing situation is connected to now.'],
    ['A2-FLU-01', 'A2', 'FLU', 'I can explain an idea another way when a word is missing.'],
    ['A2-VOC-03', 'A2', 'VOC', 'I can use contrast words to connect differing ideas.'],
    ['A2-GRA-02', 'A2', 'GRA', 'I can combine past continuous background with a past-simple event.'],
    ['A2-GRA-03', 'A2', 'GRA', 'I can use used to to contrast a past habit or state with the present.'],
    ['A2-FLU-02', 'A2', 'FLU', 'I can tell a past story with background, a main event, and a clear ending.'],
    ['A2-VOC-04', 'A2', 'VOC', 'I can use stance phrases to show that a claim is my opinion.'],
    ['A2-GRA-04', 'A2', 'GRA', 'I can use a first conditional to explain a realistic consequence.'],
    ['A2-GRA-05', 'A2', 'GRA', 'I can choose a suitable modal for advice, possibility, or obligation.'],
    ['A2-FLU-03', 'A2', 'FLU', 'I can develop and defend a simple opinion in conversation.'],
    ['A2-VOC-05', 'A2', 'VOC', 'I can use linking expressions to show addition, contrast, or result.'],
    ['A2-GRA-06', 'A2', 'GRA', 'I can use a relative clause to identify or describe something more precisely.'],
    ['A2-FLU-04', 'A2', 'FLU', 'I can organise an extended response so the main line is easy to follow.'],
    ['A2-FLU-05', 'A2', 'FLU', 'I can return to my main point after a clarification question.'],
    ['A2-VOC-06', 'A2', 'VOC', 'I can adjust familiar wording for a more casual or formal situation.'],
    ['A2-GRA-07', 'A2', 'GRA', 'I can maintain understandable tense control across a story or explanation.'],
    ['A2-FLU-06', 'A2', 'FLU', 'I can respond to a related topic shift without losing the main thread.'],
    ['A2-FLU-07', 'A2', 'FLU', 'I can enter a simulated group discussion with a relevant contribution.'],
    ['B1-VOC-01', 'B1', 'VOC', 'I can replace vague wording with a more precise expression while preserving meaning.'],
    ['B1-VOC-02', 'B1', 'VOC', 'I can use common collocations appropriately in spontaneous speech.'],
    ['B1-GRA-01', 'B1', 'GRA', 'I can use a second conditional to explore an unreal or unlikely situation.'],
    ['B1-FLU-01', 'B1', 'FLU', 'I can explain a complex familiar idea without removing important qualifications.'],
    ['B1-VOC-03', 'B1', 'VOC', 'I can choose language that shows an appropriate degree of certainty.'],
    ['B1-GRA-02', 'B1', 'GRA', 'I can use a third conditional to explain an unreal past cause and consequence.'],
    ['B1-GRA-03', 'B1', 'GRA', 'I can report a statement or question while preserving its meaning.'],
    ['B1-FLU-02', 'B1', 'FLU', 'I can use complex sentences while keeping the main point clear.'],
    ['B1-VOC-04', 'B1', 'VOC', 'I can use conversational markers to open, redirect, resume, or close a point.'],
    ['B1-GRA-04', 'B1', 'GRA', 'I can choose active or passive voice according to what I want to emphasise.'],
    ['B1-FLU-03', 'B1', 'FLU', 'I can sustain a structured response across connected turns and follow-up questions.'],
    ['B1-FLU-04', 'B1', 'FLU', 'I can keep a clear main thread when the conversation moves to a related topic.'],
    ['B1-VOC-05', 'B1', 'VOC', 'I can use language for claims, evidence, and counterarguments in a discussion.'],
    ['B1-GRA-05', 'B1', 'GRA', 'I can use linking or emphasis structures to make an argument easier to follow.'],
    ['B1-FLU-05', 'B1', 'FLU', 'I can support a position and address an opposing point.'],
    ['B1-FLU-06', 'B1', 'FLU', 'I can challenge an idea respectfully and respond to the reply.'],
    ['B1-VOC-06', 'B1', 'VOC', 'I can adapt my wording for casual, formal, or persuasive speaking.'],
    ['B1-GRA-06', 'B1', 'GRA', 'I can maintain generally reliable control of B2 grammar across spontaneous tasks.'],
    ['B1-FLU-07', 'B1', 'FLU', 'I can respond spontaneously to familiar and moderately abstract questions.'],
    ['B1-FLU-08', 'B1', 'FLU', 'I can convey a personal stance and appropriate humour or emphasis while remaining clear.'],
    ['B2-VOC-01', 'B2', 'VOC', 'I can choose words for precise meaning, connotation, and context.'],
    ['B2-VOC-02', 'B2', 'VOC', 'I can explain an abstract concept and distinguish it from a related concept.'],
    ['B2-GRA-01', 'B2', 'GRA', 'I can use an emphasis structure when it suits the spoken purpose.'],
    ['B2-FLU-01', 'B2', 'FLU', 'I can express a nuanced position with its qualifications and implications intact.'],
    ['B2-VOC-03', 'B2', 'VOC', 'I can express a complex idea concisely and unpack it when clarification is needed.'],
    ['B2-GRA-02', 'B2', 'GRA', 'I can use modal-perfect forms to evaluate or speculate about past actions.'],
    ['B2-GRA-03', 'B2', 'GRA', 'I can use layered clauses while keeping the sentence understandable.'],
    ['B2-FLU-02', 'B2', 'FLU', 'I can reformulate a complex answer for a listener without losing its meaning.'],
    ['B2-VOC-04', 'B2', 'VOC', 'I can use discourse markers to signal consequence, concession, movement, or conclusion.'],
    ['B2-GRA-04', 'B2', 'GRA', 'I can use reference and substitution to maintain cohesion without confusing repetition.'],
    ['B2-FLU-03', 'B2', 'FLU', 'I can sustain and organise a complex discussion across connected turns.'],
    ['B2-FLU-04', 'B2', 'FLU', 'I can contribute effectively to an academic or professional discussion.'],
    ['B2-VOC-05', 'B2', 'VOC', 'I can adapt vocabulary and register when the audience, relationship, or purpose changes.'],
    ['B2-GRA-05', 'B2', 'GRA', 'I can choose among neutral, emphatic, and elliptical structures according to purpose.'],
    ['B2-FLU-05', 'B2', 'FLU', 'I can shift speaking style when the audience or purpose changes.'],
    ['B2-VOC-06', 'B2', 'VOC', 'I can convey attitude, irony, or humour in a way that makes my intended stance clear.'],
    ['B2-GRA-06', 'B2', 'GRA', 'I can maintain high grammatical control and self-correct without disrupting the exchange.'],
    ['B2-FLU-06', 'B2', 'FLU', 'I can present a complex idea, respond to challenge, and refine it for the listener.'],
    ['B2-FLU-07', 'B2', 'FLU', 'I can handle an unfamiliar high-level speaking task by clarifying and structuring my response.'],
    ['C1-VOC-01', 'C1', 'VOC', 'I can select words for precision, connotation, and rhetorical effect.'],
    ['C1-VOC-02', 'C1', 'VOC', 'I can adapt language sensitively to audience, relationship, and purpose.'],
    ['C1-GRA-01', 'C1', 'GRA', 'I can use formal or literary-style structures selectively when they suit the occasion.'],
    ['C1-FLU-01', 'C1', 'FLU', 'I can communicate complex, emotional, abstract, or creative content and clarify it when challenged.'],
    ['C1-VOC-03', 'C1', 'VOC', 'I can create and interpret figurative language that fits the conversational context.'],
    ['C1-GRA-02', 'C1', 'GRA', 'I can use syntax, rhythm, emphasis, and contrast deliberately to shape a spoken message.'],
    ['C1-GRA-03', 'C1', 'GRA', 'I can draw on a very wide grammatical repertoire without making marked forms sound inappropriate.'],
    ['C1-FLU-02', 'C1', 'FLU', 'I can produce an extended, well-structured response to an unseen complex prompt.'],
    ['C1-VOC-04', 'C1', 'VOC', 'I can infer and discuss an unfamiliar allusion or historically marked expression when context is provided.'],
    ['C1-GRA-04', 'C1', 'GRA', 'I can flexibly report, hypothesise, and shift emphasis across an extended exchange.'],
    ['C1-FLU-03', 'C1', 'FLU', 'I can engage with proficient speakers who use varied speaking styles and clarify when necessary.'],
    ['C1-FLU-04', 'C1', 'FLU', 'I can enter, hold, yield, and regain the floor in a simulated multiparty discussion.'],
    ['C1-VOC-05', 'C1', 'VOC', 'I can retrieve, replace, and reformulate precise vocabulary under conversational pressure.'],
    ['C1-GRA-05', 'C1', 'GRA', 'I can maintain grammatical control while planning, responding to challenge, and changing register.'],
    ['C1-FLU-05', 'C1', 'FLU', 'I can repair a rare language problem unobtrusively while preserving the flow.'],
    ['C1-FLU-06', 'C1', 'FLU', 'I can sustain a recognisable personal voice across different speaking purposes.'],
    ['C1-VOC-06', 'C1', 'VOC', 'I can use exceptionally precise and flexible vocabulary across demanding speaking contexts.'],
    ['C1-GRA-06', 'C1', 'GRA', 'I can use a very broad grammatical repertoire accurately and appropriately across contexts.'],
    ['C1-FLU-07', 'C1', 'FLU', 'I can deliberately vary warmth, authority, creativity, and restraint while remaining precise.'],
    ['C1-FLU-08', 'C1', 'FLU', 'I can adapt to unfamiliar, complex speaking purposes without losing precision.'],
]

# Transition Step-by-Step Curriculum
UNITS = {
    'A0': [
        {
            'step': '1',
            'name': 'First words',
            'focus': 'Naming the things I can see.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can name familiar objects, animals, or colours when they come up in conversation.', 'needs': ['naming'], 'name': 'Name objects and colours', 'label': 'Name objects and colours'},
                {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can use basic numbers when they come up in a simple conversation.', 'needs': ['naming'], 'name': 'Use numbers in conversation', 'label': 'Use numbers in conversation'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use a, an, or the when naming a familiar object.', 'needs': ['any'], 'name': 'Use a, an, the', 'label': 'Use a, an, the'},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can respond to a simple question with a familiar word or short phrase.', 'needs': ['any'], 'name': 'Answer a simple question', 'label': 'Answer a simple question'},
            ]
        },
        {
            'step': '2',
            'name': 'I am and I have got',
            'focus': 'Saying who I am and what I have.',
            'skills': [
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can give a simple introduction with a name and age.', 'needs': ['naming', 'describing'], 'name': 'Say your name and age', 'label': 'Say your name and age'},
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can say who someone is in a family.', 'needs': ['naming', 'describing'], 'name': 'Name people in your family', 'label': 'Name people in your family'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use I am or I am not to describe myself or a character.', 'needs': ['describing'], 'name': "Use I am, I'm not", 'label': "Use I am, I'm not"},
                {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can say what I or another person has.', 'needs': ['describing'], 'name': 'Say what you have', 'label': 'Say what you have'},
            ]
        },
        {
            'step': '3',
            'name': "I like and I don't like",
            'focus': "Saying what I enjoy — and what I don't.",
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar food, activity, animal, or colour words when they come up in conversation.', 'needs': ['naming', 'preference'], 'name': 'Use familiar everyday words', 'label': 'Use familiar everyday words'},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': "I can use I like or I don't like to express a preference.", 'needs': ['preference'], 'name': "Use like and don't like", 'label': "Use like and don't like"},
                {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': 'I can use and to add another word or idea.', 'needs': ['any'], 'name': 'Join ideas using and', 'label': 'Join ideas using and'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can take part in a simple conversation about likes and dislikes.', 'needs': ['preference'], 'name': 'Talk about your likes', 'label': 'Talk about your likes'},
            ]
        },
        {
            'step': '4',
            'name': 'I can',
            'focus': 'Saying what I am able to do.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar action or position words when describing a simple situation.', 'needs': ['describing', 'present_action'], 'name': 'Use action and place words', 'label': 'Use action and place words'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': "I can use can or can't to talk about ability.", 'needs': ['describing'], 'name': "Use can and can't", 'label': "Use can and can't"},
                {'id': 'U4-GRA-02', 'strand': 'GRA', 'text': 'I can use a simple location sentence to say where something is.', 'needs': ['describing'], 'name': 'Say where things are', 'label': 'Say where things are'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can take part in a simple exchange about abilities or locations.', 'needs': ['describing'], 'name': 'Talk about your abilities', 'label': 'Talk about your abilities'},
            ]
        },
        {
            'step': '5',
            'name': 'What is happening?',
            'focus': 'Using present continuous and putting it all together in a short exchange.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar action words when talking about what someone is doing.', 'needs': ['present_action'], 'name': 'Use words for doing things', 'label': 'Use words for doing things'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use the present continuous to say what is happening now.', 'needs': ['present_action', 'describing'], 'name': 'Say what is happening now', 'label': 'Say what is happening now'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can take part in a short exchange about a current activity.', 'needs': ['present_action'], 'name': 'Keep a short talk going', 'label': 'Keep a short talk going'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can ask for repetition when I do not understand.', 'needs': ['any'], 'name': 'Ask to hear it again', 'label': 'Ask to hear it again'},
            ]
        },
    ],
    'A1': [
        {
            'step': '1',
            'name': 'Describing the world',
            'focus': 'Moving from naming things to describing them.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can use simple adjectives to describe how a person looks or feels.', 'needs': ['describing'], 'name': 'Describe people and feelings', 'label': 'Describe people and feelings'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use the present continuous throughout a brief description of a scene.', 'needs': ['describing'], 'name': "Say what's happening now", 'label': "Say what's happening now"},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can give a short, connected description of a person, place, or scene.', 'needs': ['describing'], 'name': 'Describe a place or scene', 'label': 'Describe a place or scene'},
                {'id': 'U1-FLU-02', 'strand': 'FLU', 'text': 'I can answer a follow-up question by adding a relevant detail.', 'needs': ['any'], 'name': 'Add detail when asked', 'label': 'Add detail when asked'},
            ]
        },
        {
            'step': '2',
            'name': 'Talking about the past',
            'focus': 'Starting to use past tense to share what happened.',
            'skills': [
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar past-time words when talking about an event.', 'needs': ['past_event'], 'name': 'Use yesterday, last week', 'label': 'Use yesterday, last week'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use common past-simple verbs to talk about completed actions.', 'needs': ['past_event'], 'name': 'Use common past tense verbs', 'label': 'Use common past tense verbs'},
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can recount a short event in a clear order.', 'needs': ['past_event', 'narrative'], 'name': 'Tell a short event clearly', 'label': 'Tell a short event clearly'},
                {'id': 'U2-FLU-02', 'strand': 'FLU', 'text': 'I can answer a simple question about a short spoken story.', 'needs': ['past_event', 'narrative'], 'name': 'Answer questions about stories', 'label': 'Answer questions about stories'},
            ]
        },
        {
            'step': '3',
            'name': 'Giving opinions and reasons',
            'focus': 'Beginning to say what I think and why.',
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar phrases to introduce an opinion.', 'needs': ['opinion', 'preference'], 'name': 'Use I think, I feel', 'label': 'Use I think, I feel'},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use because to connect an opinion to a reason.', 'needs': ['opinion', 'preference'], 'name': 'Give reasons with because', 'label': 'Give reasons with because'},
                {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': 'I can use but to contrast two simple ideas.', 'needs': ['preference', 'comparison'], 'name': 'Show contrast using but', 'label': 'Show contrast using but'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can explain a simple opinion and respond to a related follow-up.', 'needs': ['opinion'], 'name': 'Give your opinion and why', 'label': 'Give your opinion and why'},
            ]
        },
        {
            'step': '4',
            'name': 'Talking about plans',
            'focus': 'Extending into the future — making and sharing plans.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use familiar time words when talking about routines or plans.', 'needs': ['routine', 'future_plan'], 'name': 'Use time and frequency words', 'label': 'Use time and frequency words'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use going to to talk about a plan.', 'needs': ['future_plan'], 'name': 'Use going to for plans', 'label': 'Use going to for plans'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can discuss a simple plan and respond to a question about it.', 'needs': ['future_plan'], 'name': 'Share your plans and why', 'label': 'Share your plans and why'},
            ]
        },
        {
            'step': '5',
            'name': 'Holding a real conversation',
            'focus': 'Using everything together in a real back-and-forth.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use simple sequence words to organise what I say.', 'needs': ['narrative'], 'name': 'Use first, then, after that', 'label': 'Use first, then, after that'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can move between present and past forms when the meaning requires it.', 'needs': ['any'], 'name': 'Mix past and present', 'label': 'Mix past and present'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can stay in a familiar-topic conversation as it develops.', 'needs': ['any'], 'name': 'Keep the conversation flowing', 'label': 'Keep the conversation flowing'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can ask for repetition or say something another way after a communication problem.', 'needs': ['any'], 'name': 'Ask or try another way', 'label': 'Ask or try another way'},
            ]
        },
    ],
    'A2': [
        {
            'step': '1',
            'name': 'Finding better words',
            'focus': 'Moving from words that work to words that feel right.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can replace a general word with a more precise descriptive word.', 'needs': ['describing'], 'name': 'Choose more precise words', 'label': 'Choose more precise words'},
                {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can use a familiar fixed expression appropriately in conversation.', 'needs': ['any'], 'name': 'Use common fixed phrases', 'label': 'Use common fixed phrases'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use the present perfect when a past experience or continuing situation is connected to now.', 'needs': ['past_event', 'narrative'], 'name': 'Use the present perfect', 'label': 'Use the present perfect'},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can explain an idea another way when a word is missing.', 'needs': ['any'], 'name': 'Explain it a different way', 'label': 'Explain it a different way'},
            ]
        },
        {
            'step': '2',
            'name': 'Talking about the past with more precision',
            'focus': 'Describing not just what happened, but what was happening and what used to be.',
            'skills': [
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can use contrast words to connect differing ideas.', 'needs': ['narrative', 'comparison'], 'name': 'Use contrast and linking words', 'label': 'Use contrast and linking words'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can combine past continuous background with a past-simple event.', 'needs': ['past_event', 'narrative'], 'name': 'Combine background and event', 'label': 'Combine background and event'},
                {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use used to to contrast a past habit or state with the present.', 'needs': ['past_event', 'routine'], 'name': 'Use used to for habits', 'label': 'Use used to for habits'},
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can tell a past story with background, a main event, and a clear ending.', 'needs': ['narrative', 'past_event'], 'name': 'Tell a full, clear story', 'label': 'Tell a full, clear story'},
            ]
        },
        {
            'step': '3',
            'name': 'Expressing opinions with depth',
            'focus': 'Moving from simple opinions to supported arguments.',
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use stance phrases to show that a claim is my opinion.', 'needs': ['opinion'], 'name': "Show it's your opinion", 'label': "Show it's your opinion"},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use a first conditional to explain a realistic consequence.', 'needs': ['hypothetical'], 'name': 'Use if for consequences', 'label': 'Use if for consequences'},
                {'id': 'U3-GRA-02', 'strand': 'GRA', 'text': 'I can choose a suitable modal for advice, possibility, or obligation.', 'needs': ['opinion', 'hypothetical'], 'name': 'Use should, could, might', 'label': 'Use should, could, might'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can develop and defend a simple opinion in conversation.', 'needs': ['opinion', 'explanation'], 'name': 'Defend your opinion clearly', 'label': 'Defend your opinion clearly'},
            ]
        },
        {
            'step': '4',
            'name': 'Speaking for longer without losing the thread',
            'focus': 'Building up to a full minute of organised, connected speech.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use linking expressions to show addition, contrast, or result.', 'needs': ['explanation', 'narrative'], 'name': 'Link ideas with also, however', 'label': 'Link ideas with also, however'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use a relative clause to identify or describe something more precisely.', 'needs': ['any'], 'name': 'Add detail with who, that', 'label': 'Add detail with who, that'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can organise an extended response so the main line is easy to follow.', 'needs': ['any'], 'name': 'Speak longer, stay organised', 'label': 'Speak longer, stay organised'},
                {'id': 'U4-FLU-02', 'strand': 'FLU', 'text': 'I can return to my main point after a clarification question.', 'needs': ['any'], 'name': 'Get back to your point', 'label': 'Get back to your point'},
            ]
        },
        {
            'step': '5',
            'name': 'Handling unpredictable conversations',
            'focus': 'Communicating flexibly in varied situations.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can adjust familiar wording for a more casual or formal situation.', 'needs': ['any'], 'name': 'Adjust words for the situation', 'label': 'Adjust words for the situation'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can maintain understandable tense control across a story or explanation.', 'needs': ['narrative', 'past_event'], 'name': 'Control tenses across a story', 'label': 'Control tenses across a story'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can respond to a related topic shift without losing the main thread.', 'needs': ['any'], 'name': 'Follow a topic change smoothly', 'label': 'Follow a topic change smoothly'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can enter a simulated group discussion with a relevant contribution.', 'needs': ['any'], 'name': 'Jump into a group discussion', 'label': 'Jump into a group discussion'},
            ]
        },
    ],
    'B1': [
        {
            'step': '1',
            'name': 'Precision in vocabulary',
            'focus': 'Choosing more exact and sophisticated words.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can replace vague wording with a more precise expression while preserving meaning.', 'needs': ['any'], 'name': 'Replace vague with precise words', 'label': 'Replace vague with precise words'},
                {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can use common collocations appropriately in spontaneous speech.', 'needs': ['any'], 'name': 'Use natural word combinations', 'label': 'Use natural word combinations'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use a second conditional to explore an unreal or unlikely situation.', 'needs': ['hypothetical'], 'name': 'Explore what if situations', 'label': 'Explore what if situations'},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can explain a complex familiar idea without removing important qualifications.', 'needs': ['abstract', 'opinion'], 'name': 'Explain complex ideas fully', 'label': 'Explain complex ideas fully'},
            ]
        },
        {
            'step': '2',
            'name': 'Using complex grammar naturally',
            'focus': 'Using third conditional, reported speech, and hedging language with confidence.',
            'skills': [
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can choose language that shows an appropriate degree of certainty.', 'needs': ['opinion', 'argumentation'], 'name': 'Show how certain you are', 'label': 'Show how certain you are'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use a third conditional to explain an unreal past cause and consequence.', 'needs': ['hypothetical', 'past_event'], 'name': 'Discuss unreal past events', 'label': 'Discuss unreal past events'},
                {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can report a statement or question while preserving its meaning.', 'needs': ['narrative', 'past_event'], 'name': 'Report what someone said', 'label': 'Report what someone said'},
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can use complex sentences while keeping the main point clear.', 'needs': ['any'], 'name': 'Keep complex sentences clear', 'label': 'Keep complex sentences clear'},
            ]
        },
        {
            'step': '3',
            'name': 'Speaking at length with coherence',
            'focus': 'Building extended, well-organised spoken responses.',
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use conversational markers to open, redirect, resume, or close a point.', 'needs': ['any'], 'name': 'Guide speech with signal words', 'label': 'Guide speech with signal words'},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can choose active or passive voice according to what I want to emphasise.', 'needs': ['explanation'], 'name': 'Choose active or passive voice', 'label': 'Choose active or passive voice'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can sustain a structured response across connected turns and follow-up questions.', 'needs': ['any'], 'name': 'Speak at length with structure', 'label': 'Speak at length with structure'},
                {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can keep a clear main thread when the conversation moves to a related topic.', 'needs': ['any'], 'name': 'Hold your thread through shifts', 'label': 'Hold your thread through shifts'},
            ]
        },
        {
            'step': '4',
            'name': 'Arguing and persuading',
            'focus': 'Moving from sharing opinions to defending and challenging ideas.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can use language for claims, evidence, and counterarguments in a discussion.', 'needs': ['argumentation'], 'name': 'Use claim and evidence language', 'label': 'Use claim and evidence language'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can use linking or emphasis structures to make an argument easier to follow.', 'needs': ['argumentation', 'opinion'], 'name': 'Emphasise points with structure', 'label': 'Emphasise points with structure'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can support a position and address an opposing point.', 'needs': ['argumentation', 'opinion'], 'name': 'Support and defend a position', 'label': 'Support and defend a position'},
                {'id': 'U4-FLU-02', 'strand': 'FLU', 'text': 'I can challenge an idea respectfully and respond to the reply.', 'needs': ['argumentation', 'opinion'], 'name': 'Challenge ideas respectfully', 'label': 'Challenge ideas respectfully'},
            ]
        },
        {
            'step': '5',
            'name': 'Natural, spontaneous fluency',
            'focus': 'Speaking without noticeable effort on a wide range of topics.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can adapt my wording for casual, formal, or persuasive speaking.', 'needs': ['any'], 'name': 'Adapt words to any setting', 'label': 'Adapt words to any setting'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can maintain generally reliable control of B2 grammar across spontaneous tasks.', 'needs': ['any'], 'name': 'Use grammar reliably throughout', 'label': 'Use grammar reliably throughout'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can respond spontaneously to familiar and moderately abstract questions.', 'needs': ['any'], 'name': 'Respond to anything spontaneously', 'label': 'Respond to anything spontaneously'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can convey a personal stance and appropriate humour or emphasis while remaining clear.', 'needs': ['any'], 'name': 'Show personality while staying clear', 'label': 'Show personality while staying clear'},
            ]
        },
    ],
    'B2': [
        {
            'step': '1',
            'name': 'Choosing words with more precision and feeling',
            'focus': 'Moving from a large vocabulary to a sensitive one — words chosen for effect, not just meaning.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can choose words for precise meaning, connotation, and context.', 'needs': ['any'], 'name': 'Choose words for effect', 'label': 'Choose words for effect'},
                {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can explain an abstract concept and distinguish it from a related concept.', 'needs': ['abstract'], 'name': 'Explain and compare abstract ideas', 'label': 'Explain and compare abstract ideas'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use an emphasis structure when it suits the spoken purpose.', 'needs': ['any'], 'name': 'Emphasise with word order', 'label': 'Emphasise with word order'},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can express a nuanced position with its qualifications and implications intact.', 'needs': ['abstract', 'opinion'], 'name': 'Express subtle, nuanced ideas', 'label': 'Express subtle, nuanced ideas'},
            ]
        },
        {
            'step': '2',
            'name': 'Complex grammar with ease',
            'focus': 'Using advanced grammar without effort or hesitation.',
            'skills': [
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can express a complex idea concisely and unpack it when clarification is needed.', 'needs': ['abstract', 'explanation'], 'name': 'Compress and unpack ideas', 'label': 'Compress and unpack ideas'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use modal-perfect forms to evaluate or speculate about past actions.', 'needs': ['hypothetical', 'past_event'], 'name': 'Use should have, could have', 'label': 'Use should have, could have'},
                {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can use layered clauses while keeping the sentence understandable.', 'needs': ['any'], 'name': 'Layer clauses and stay clear', 'label': 'Layer clauses and stay clear'},
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can reformulate a complex answer for a listener without losing its meaning.', 'needs': ['any'], 'name': 'Rephrase for your listener', 'label': 'Rephrase for your listener'},
            ]
        },
        {
            'step': '3',
            'name': 'Sustained, coherent discourse',
            'focus': 'Holding the floor for extended periods.',
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can use discourse markers to signal consequence, concession, movement, or conclusion.', 'needs': ['any'], 'name': 'Steer speech with signal words', 'label': 'Steer speech with signal words'},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can use reference and substitution to maintain cohesion without confusing repetition.', 'needs': ['any'], 'name': 'Avoid repetition skilfully', 'label': 'Avoid repetition skilfully'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can sustain and organise a complex discussion across connected turns.', 'needs': ['any'], 'name': 'Sustain a complex discussion', 'label': 'Sustain a complex discussion'},
                {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can contribute effectively to an academic or professional discussion.', 'needs': ['any'], 'name': 'Join professional discussions confidently', 'label': 'Join professional discussions confidently'},
            ]
        },
        {
            'step': '4',
            'name': 'Register flexibility',
            'focus': 'Adapting instantly to any speaking context or audience.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can adapt vocabulary and register when the audience, relationship, or purpose changes.', 'needs': ['any'], 'name': 'Adapt language to your audience', 'label': 'Adapt language to your audience'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can choose among neutral, emphatic, and elliptical structures according to purpose.', 'needs': ['any'], 'name': 'Choose emphatic or subtle structures', 'label': 'Choose emphatic or subtle structures'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can shift speaking style when the audience or purpose changes.', 'needs': ['any'], 'name': 'Shift style to fit context', 'label': 'Shift style to fit context'},
            ]
        },
        {
            'step': '5',
            'name': 'Speaking with real precision and effect',
            'focus': 'Language that creates the exact effect the student intends — in any situation.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can convey attitude, irony, or humour in a way that makes my intended stance clear.', 'needs': ['any'], 'name': 'Carry irony, humour, attitude', 'label': 'Carry irony, humour, attitude'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can maintain high grammatical control and self-correct without disrupting the exchange.', 'needs': ['any'], 'name': 'Catch and fix rare errors', 'label': 'Catch and fix rare errors'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can present a complex idea, respond to challenge, and refine it for the listener.', 'needs': ['argumentation', 'abstract'], 'name': 'Present, defend, and refine ideas', 'label': 'Present, defend, and refine ideas'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can handle an unfamiliar high-level speaking task by clarifying and structuring my response.', 'needs': ['any'], 'name': 'Handle any unfamiliar task', 'label': 'Handle any unfamiliar task'},
            ]
        },
    ],
    'C1': [
        {
            'step': '1',
            'name': 'Mastery of vocabulary',
            'focus': 'Moving towards native-level vocabulary range and sensitivity.',
            'skills': [
                {'id': 'U1-VOC-01', 'strand': 'VOC', 'text': 'I can select words for precision, connotation, and rhetorical effect.', 'needs': ['any'], 'name': 'Choose words for rhetorical effect', 'label': 'Choose words for rhetorical effect'},
                {'id': 'U1-VOC-02', 'strand': 'VOC', 'text': 'I can adapt language sensitively to audience, relationship, and purpose.', 'needs': ['any'], 'name': 'Adapt language to any audience', 'label': 'Adapt language to any audience'},
                {'id': 'U1-GRA-01', 'strand': 'GRA', 'text': 'I can use formal or literary-style structures selectively when they suit the occasion.', 'needs': ['any'], 'name': 'Use literary structures selectively', 'label': 'Use literary structures selectively'},
                {'id': 'U1-FLU-01', 'strand': 'FLU', 'text': 'I can communicate complex, emotional, abstract, or creative content and clarify it when challenged.', 'needs': ['abstract'], 'name': 'Express and defend any idea', 'label': 'Express and defend any idea'},
            ]
        },
        {
            'step': '2',
            'name': 'Grammar as craft',
            'focus': 'Using grammar not just accurately but artistically.',
            'skills': [
                {'id': 'U2-VOC-01', 'strand': 'VOC', 'text': 'I can create and interpret figurative language that fits the conversational context.', 'needs': ['abstract'], 'name': 'Create and read figurative language', 'label': 'Create and read figurative language'},
                {'id': 'U2-GRA-01', 'strand': 'GRA', 'text': 'I can use syntax, rhythm, emphasis, and contrast deliberately to shape a spoken message.', 'needs': ['any'], 'name': 'Use rhythm, emphasis, contrast', 'label': 'Use rhythm, emphasis, contrast'},
                {'id': 'U2-GRA-02', 'strand': 'GRA', 'text': 'I can draw on a very wide grammatical repertoire without making marked forms sound inappropriate.', 'needs': ['any'], 'name': 'Use the full grammar range', 'label': 'Use the full grammar range'},
                {'id': 'U2-FLU-01', 'strand': 'FLU', 'text': 'I can produce an extended, well-structured response to an unseen complex prompt.', 'needs': ['any'], 'name': 'Respond to unseen complex prompts', 'label': 'Respond to unseen complex prompts'},
            ]
        },
        {
            'step': '3',
            'name': 'Full communicative range',
            'focus': 'Handling any conversation, audience, or register effortlessly.',
            'skills': [
                {'id': 'U3-VOC-01', 'strand': 'VOC', 'text': 'I can infer and discuss an unfamiliar allusion or historically marked expression when context is provided.', 'needs': ['abstract'], 'name': 'Discuss unfamiliar references in context', 'label': 'Discuss unfamiliar references in context'},
                {'id': 'U3-GRA-01', 'strand': 'GRA', 'text': 'I can flexibly report, hypothesise, and shift emphasis across an extended exchange.', 'needs': ['any'], 'name': 'Report, hypothesise, shift emphasis', 'label': 'Report, hypothesise, shift emphasis'},
                {'id': 'U3-FLU-01', 'strand': 'FLU', 'text': 'I can engage with proficient speakers who use varied speaking styles and clarify when necessary.', 'needs': ['any'], 'name': 'Engage with varied speaker styles', 'label': 'Engage with varied speaker styles'},
                {'id': 'U3-FLU-02', 'strand': 'FLU', 'text': 'I can enter, hold, yield, and regain the floor in a simulated multiparty discussion.', 'needs': ['any'], 'name': 'Manage the floor in discussion', 'label': 'Manage the floor in discussion'},
            ]
        },
        {
            'step': '4',
            'name': 'Language as identity',
            'focus': 'English feels like yours — not a language you learned, but one you live in.',
            'skills': [
                {'id': 'U4-VOC-01', 'strand': 'VOC', 'text': 'I can retrieve, replace, and reformulate precise vocabulary under conversational pressure.', 'needs': ['any'], 'name': 'Find words fast under pressure', 'label': 'Find words fast under pressure'},
                {'id': 'U4-GRA-01', 'strand': 'GRA', 'text': 'I can maintain grammatical control while planning, responding to challenge, and changing register.', 'needs': ['any'], 'name': 'Keep grammar steady under load', 'label': 'Keep grammar steady under load'},
                {'id': 'U4-FLU-01', 'strand': 'FLU', 'text': 'I can repair a rare language problem unobtrusively while preserving the flow.', 'needs': ['any'], 'name': 'Fix problems without breaking flow', 'label': 'Fix problems without breaking flow'},
                {'id': 'U4-FLU-02', 'strand': 'FLU', 'text': 'I can sustain a recognisable personal voice across different speaking purposes.', 'needs': ['any'], 'name': 'Sustain your personal voice', 'label': 'Sustain your personal voice'},
            ]
        },
        {
            'step': '5',
            'name': 'Full mastery',
            'focus': 'Arriving at the highest level of English proficiency.',
            'skills': [
                {'id': 'U5-VOC-01', 'strand': 'VOC', 'text': 'I can use exceptionally precise and flexible vocabulary across demanding speaking contexts.', 'needs': ['any'], 'name': 'Master vocabulary across contexts', 'label': 'Master vocabulary across contexts'},
                {'id': 'U5-GRA-01', 'strand': 'GRA', 'text': 'I can use a very broad grammatical repertoire accurately and appropriately across contexts.', 'needs': ['any'], 'name': 'Command grammar in all styles', 'label': 'Command grammar in all styles'},
                {'id': 'U5-FLU-01', 'strand': 'FLU', 'text': 'I can deliberately vary warmth, authority, creativity, and restraint while remaining precise.', 'needs': ['any'], 'name': 'Vary warmth, authority, creativity', 'label': 'Vary warmth, authority, creativity'},
                {'id': 'U5-FLU-02', 'strand': 'FLU', 'text': 'I can adapt to unfamiliar, complex speaking purposes without losing precision.', 'needs': ['any'], 'name': 'Adapt to any speaking purpose', 'label': 'Adapt to any speaking purpose'},
            ]
        },
    ],
}

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
                "preference",
                "present_action"
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
                "preference",
                "present_action"
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
                "routine",
                "past_event",
                "future_plan"
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
                "describing",
                "past_event",
                "future_plan"
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
                "comparison",
                "opinion"
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
                "routine",
                "opinion"
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
                "describing",
                "future_plan"
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
                "comparison",
                "future_plan",
                "narrative"
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
                "explanation",
                "past_event",
                "hypothetical"
            ]
        },
        {
            "id": "a2_4",
            "name": "Social media and technology",
            "shortName": "Social Media",
            "affordances": [
                "opinion",
                "comparison",
                "explanation",
                "hypothetical"
            ]
        },
        {
            "id": "a2_5",
            "name": "City life vs. village life",
            "shortName": "City vs Village",
            "affordances": [
                "comparison",
                "opinion",
                "describing",
                "past_event"
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
                "abstract",
                "hypothetical"
            ]
        },
        {
            "id": "a2_8",
            "name": "Health and lifestyle",
            "shortName": "Health",
            "affordances": [
                "opinion",
                "comparison",
                "explanation",
                "past_event",
                "hypothetical"
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
                "narrative",
                "describing"
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
                "abstract",
                "explanation"
            ]
        },
        {
            "id": "b1_3",
            "name": "Education and success",
            "shortName": "Success",
            "affordances": [
                "opinion",
                "abstract",
                "comparison",
                "hypothetical"
            ]
        },
        {
            "id": "b1_4",
            "name": "AI and the future of work",
            "shortName": "AI & Work",
            "affordances": [
                "abstract",
                "opinion",
                "hypothetical",
                "explanation",
                "argumentation"
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
                "opinion",
                "hypothetical",
                "argumentation"
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
                "opinion",
                "explanation"
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
                "narrative",
                "hypothetical"
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
                "narrative",
                "hypothetical"
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
                "comparison",
                "hypothetical"
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
                "narrative",
                "hypothetical"
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
                "needs": s.get("needs", ["any"]),
                "step": u["step"],
                "step_name": u["name"],
                "level": lvl
            }
            UNIT_SKILLS_BY_LEVEL[(lvl, s["id"])] = metadata
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

# Populate SKILL_AFFORDANCES dynamically from UNITS skills
SKILL_AFFORDANCES = {}
for lvl, u_list in UNITS.items():
    for u in u_list:
        for s in u["skills"]:
            SKILL_AFFORDANCES[f"{lvl}:{s['id']}"] = s.get("needs", ["any"])
            SKILL_AFFORDANCES[s['id']] = s.get("needs", ["any"])

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
