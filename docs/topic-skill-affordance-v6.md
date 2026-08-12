# ZoSpeak — Topic & Skill Affordance Reference (v6 — Widened Topic Tags)

Compact data reference for the topic–skill compatibility layer. Skill labels match the canonical set in `skill-labels-icons-v2.md` — both documents are generated from the same source data. **v6 change: 30 tag additions across 23 topics, verified against every skill's compatible-topic-pool size so no skill falls below the floor of 7.** No skill IDs, labels, statements, or icon decisions were touched — this is a topic-tags-only update.

**Affordance tags:** `naming` `describing` `routine` `preference` `past_event` `present_action` `future_plan` `opinion` `narrative` `comparison` `hypothetical` `abstract` `explanation` `argumentation` `any`

**Display rule:** floor 7 / ceiling 12 topics shown per session, universal across all levels. Zoe's Pick and the display set both draw from the same recency-aware pool (excludes the student's last 2 sessions on that skill) — if excluding those would drop the pool below 7, the exclusion is skipped and both fall back to the full pool. Floor always wins over freshness.

**Pool size:** 16 at A1–A2, 18 at B1, 20 at B2–C2. The extra topics at B1+ are marked *(comfort)* — lighter, familiar topics (Sports, Music, Family, Food) added alongside the existing heavier/abstract topics so students aren't limited to intellectually demanding options every session, even at high levels. Affordance tags scale with level — e.g. "Sports" needs only `preference, describing` at A1 but supports `opinion, hypothetical, argumentation` by C2, since the depth comes from the student's language capacity, not the topic's framing.

**Comfort topic icons:** the same label repeats across levels (Sports/Music/Family/Food at B2/C1/C2, Family/Food also at B1) — only 4 icon decisions total, not one per occurrence.

| Comfort concept | Icon | Notes |
|---|---|---|
| My Family | Reuse — A1 #2 "My Family" | Same icon at every level |
| Food | Reuse — A1 #4 "Food" | Same icon at every level |
| Sports | Reuse — A1 #10 "Sports" | Use A1's generic sports icon, not B1's existing "Cricket & Sport" icon (cricket-specific) |
| Music | New / adapted | No standalone icon exists. B1's "Cinema & Music" icon is fused film+music, likely film-led — a starting point to strip down, not a drop-in |

**Skill structure:** Every skill has a formal ID (`A0A1-S1-01`), a strand (V = Vocabulary, G = Grammar, F = Fluency), a student-facing label (3–5 words, matches the skill card), and an icon decision (see skill-labels-icons-v2.md for full icon guidance). Each unit has 4 skills except A1→A2 Unit 4, B2→C1 Unit 4 (3 each).

---

## A1 Topics (→ A0→A1)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | My name and where I'm from | My Name | naming, describing |
| 2 | My family | My Family | naming, describing, preference |
| 3 | My school | School | describing, routine, preference, present_action |
| 4 | Food I like | Food | naming, preference, describing |
| 5 | My daily routine | Routine | routine, describing, present_action |
| 6 | Things I like and don't like | Liking | preference |
| 7 | Animals | Animals | naming, describing, preference |
| 8 | Colours, numbers, and shapes | Colours | naming |
| 9 | My home | Home | naming, describing, present_action |
| 10 | Sports and games | Sports | preference, present_action, describing |
| 11 | Festivals I celebrate | Festivals | describing, preference, naming |
| 12 | My favourite film, show, or cartoon | Favourite Show | preference, describing, naming |
| 13 | Games we play at break time | Break Time | present_action, describing, preference |
| 14 | My birthday | Birthday | describing, preference, naming |
| 15 | Things I can do | Things I Can Do | describing, preference, present_action |
| 16 | My bag and what is inside it | My Bag | naming, describing, present_action |

### A0→A1 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | A0A1-S1-01 | V | Name objects and colours | I can name familiar objects, animals, or colours when they come up in conversation. | naming |
| 1 | A0A1-S1-02 | V | Use numbers in conversation | I can use basic numbers when they come up in a simple conversation. | naming |
| 1 | A0A1-S1-03 | G | Use a, an, the | I can use a, an, or the when naming a familiar object. | any |
| 1 | A0A1-S1-04 | F | Answer a simple question | I can respond to a simple question with a familiar word or short phrase. | any |
| 2 | A0A1-S2-01 | F | Say your name and age | I can give a simple introduction with a name and age. | naming, describing |
| 2 | A0A1-S2-02 | V | Name people in your family | I can say who someone is in a family. | naming, describing |
| 2 | A0A1-S2-03 | G | Use I am, I'm not | I can use I am or I am not to describe myself or a character. | describing |
| 2 | A0A1-S2-04 | G | Say what you have | I can say what I or another person has. | describing |
| 3 | A0A1-S3-01 | V | Use familiar everyday words | I can use familiar food, activity, animal, or colour words when they come up in conversation. | naming, preference |
| 3 | A0A1-S3-02 | G | Use like and don't like | I can use I like or I don't like to express a preference. | preference |
| 3 | A0A1-S3-03 | G | Join ideas using and | I can use and to add another word or idea. | any |
| 3 | A0A1-S3-04 | F | Talk about your likes | I can take part in a simple conversation about likes and dislikes. | preference |
| 4 | A0A1-S4-01 | V | Use action and place words | I can use familiar action or position words when describing a simple situation. | describing, present_action |
| 4 | A0A1-S4-02 | G | Use can and can't | I can use can or can't to talk about ability. | describing |
| 4 | A0A1-S4-03 | G | Say where things are | I can use a simple location sentence to say where something is. | describing |
| 4 | A0A1-S4-04 | F | Talk about your abilities | I can take part in a simple exchange about abilities or locations. | describing |
| 5 | A0A1-S5-01 | V | Use words for doing things | I can use familiar action words when talking about what someone is doing. | present_action |
| 5 | A0A1-S5-02 | G | Say what is happening now | I can use the present continuous to say what is happening now. | present_action, describing |
| 5 | A0A1-S5-03 | F | Keep a short talk going | I can take part in a short exchange about a current activity. | present_action |
| 5 | A0A1-S5-04 | F | Ask to hear it again | I can ask for repetition when I do not understand. | any |

---

## A2 Topics (→ A1→A2)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | My hobbies and free time | Hobbies | preference, describing, routine, past_event, future_plan |
| 2 | My friends | Friends | describing, past_event, narrative, preference |
| 3 | A typical week | My Week | routine, describing, past_event, future_plan |
| 4 | Shopping and markets | Shopping | describing, preference, past_event |
| 5 | Food and restaurants | Eating Out | preference, describing, comparison, opinion |
| 6 | My city or town | My City | describing, comparison, opinion |
| 7 | Weather and seasons | Weather | describing, comparison, routine, opinion |
| 8 | Transport and travel | Travel | describing, preference, past_event |
| 9 | A trip or holiday | Trips | past_event, narrative, describing, future_plan |
| 10 | Films and TV shows | Films & TV | preference, opinion, narrative, describing |
| 11 | Celebrations and special days | Celebrations | past_event, narrative, describing |
| 12 | School subjects — likes and dislikes | Subjects | preference, opinion, comparison, future_plan, narrative |
| 13 | My plans for the holidays | Holiday Plans | future_plan, preference, narrative |
| 14 | A place I want to visit one day | Dream Place | future_plan, describing, preference |
| 15 | What I want to learn next | Learning Next | future_plan, preference, opinion |
| 16 | A person I look up to | Someone I Admire | describing, opinion, narrative |

### A1→A2 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | A1A2-S1-01 | V | Describe people and feelings | I can use simple adjectives to describe how a person looks or feels. | describing |
| 1 | A1A2-S1-02 | G | Say what's happening now | I can use the present continuous throughout a brief description of a scene. | describing |
| 1 | A1A2-S1-03 | F | Describe a place or scene | I can give a short, connected description of a person, place, or scene. | describing |
| 1 | A1A2-S1-04 | F | Add detail when asked | I can answer a follow-up question by adding a relevant detail. | any |
| 2 | A1A2-S2-01 | V | Use yesterday, last week | I can use familiar past-time words when talking about an event. | past_event |
| 2 | A1A2-S2-02 | G | Use common past tense verbs | I can use common past-simple verbs to talk about completed actions. | past_event |
| 2 | A1A2-S2-03 | F | Tell a short event clearly | I can recount a short event in a clear order. | past_event, narrative |
| 2 | A1A2-S2-04 | F | Answer questions about stories | I can answer a simple question about a short spoken story. | past_event, narrative |
| 3 | A1A2-S3-01 | V | Use I think, I feel | I can use familiar phrases to introduce an opinion. | opinion, preference |
| 3 | A1A2-S3-02 | G | Give reasons with because | I can use because to connect an opinion to a reason. | opinion, preference |
| 3 | A1A2-S3-03 | G | Show contrast using but | I can use but to contrast two simple ideas. | preference, comparison |
| 3 | A1A2-S3-04 | F | Give your opinion and why | I can explain a simple opinion and respond to a related follow-up. | opinion |
| 4 | A1A2-S4-01 | V | Use time and frequency words | I can use familiar time words when talking about routines or plans. | routine, future_plan |
| 4 | A1A2-S4-02 | G | Use going to for plans | I can use going to to talk about a plan. | future_plan |
| 4 | A1A2-S4-03 | F | Share your plans and why | I can discuss a simple plan and respond to a question about it. | future_plan |
| 5 | A1A2-S5-01 | V | Use first, then, after that | I can use simple sequence words to organise what I say. | narrative |
| 5 | A1A2-S5-02 | G | Mix past and present | I can move between present and past forms when the meaning requires it. | any |
| 5 | A1A2-S5-03 | F | Keep the conversation flowing | I can stay in a familiar-topic conversation as it develops. | any |
| 5 | A1A2-S5-04 | F | Ask or try another way | I can ask for repetition or say something another way after a communication problem. | any |

---

## B1 Topics (→ A2→B1)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | My ambitions and future plans | Ambitions | future_plan, opinion, hypothetical |
| 2 | My personality and values | Who I Am | describing, opinion, abstract |
| 3 | Education in India | Education | opinion, comparison, explanation, past_event, hypothetical |
| 4 | Social media and technology | Social Media | opinion, comparison, explanation, hypothetical |
| 5 | City life vs. village life | City vs Village | comparison, opinion, describing, past_event |
| 6 | Festivals and traditions | Traditions | narrative, describing, past_event |
| 7 | The environment and pollution | Environment | opinion, explanation, abstract, hypothetical |
| 8 | Health and lifestyle | Health | opinion, comparison, explanation, past_event, hypothetical |
| 9 | Indian cinema and music | Cinema & Music | preference, opinion, narrative, describing |
| 10 | Friendship and trust | Friendship | abstract, opinion, narrative |
| 11 | News and current events | The News | opinion, explanation, narrative, describing |
| 12 | Cricket and sport in India | Cricket & Sport | preference, narrative, opinion, comparison |
| 13 | How my life has changed since I was younger | Growing Up | past_event, routine, narrative, comparison |
| 14 | A time I had to make a difficult choice | Hard Choices | past_event, narrative, opinion, hypothetical |
| 15 | Rules I would change if I were in charge | My Rules | hypothetical, opinion, argumentation |
| 16 | A misunderstanding that taught me something | Mix-Ups | past_event, narrative, explanation |
| 17 | My family *(comfort)* | My Family | describing, narrative, opinion |
| 18 | Food and cooking *(comfort)* | Food | preference, describing, narrative |

### A2→B1 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | A2B1-S1-01 | V | Choose more precise words | I can replace a general word with a more precise descriptive word. | describing |
| 1 | A2B1-S1-02 | V | Use common fixed phrases | I can use a familiar fixed expression appropriately in conversation. | any |
| 1 | A2B1-S1-03 | G | Use the present perfect | I can use the present perfect when a past experience or continuing situation is connected to now. | past_event, narrative |
| 1 | A2B1-S1-04 | F | Explain it a different way | I can explain an idea another way when a word is missing. | any |
| 2 | A2B1-S2-01 | V | Use contrast and linking words | I can use contrast words to connect differing ideas. | narrative, comparison |
| 2 | A2B1-S2-02 | G | Combine background and event | I can combine past continuous background with a past-simple event. | past_event, narrative |
| 2 | A2B1-S2-03 | G | Use used to for habits | I can use used to to contrast a past habit or state with the present. | past_event, routine |
| 2 | A2B1-S2-04 | F | Tell a full, clear story | I can tell a past story with background, a main event, and a clear ending. | narrative, past_event |
| 3 | A2B1-S3-01 | V | Show it's your opinion | I can use stance phrases to show that a claim is my opinion. | opinion |
| 3 | A2B1-S3-02 | G | Use if for consequences | I can use a first conditional to explain a realistic consequence. | hypothetical |
| 3 | A2B1-S3-03 | G | Use should, could, might | I can choose a suitable modal for advice, possibility, or obligation. | opinion, hypothetical |
| 3 | A2B1-S3-04 | F | Defend your opinion clearly | I can develop and defend a simple opinion in conversation. | opinion, explanation |
| 4 | A2B1-S4-01 | V | Link ideas with also, however | I can use linking expressions to show addition, contrast, or result. | explanation, narrative |
| 4 | A2B1-S4-02 | G | Add detail with who, that | I can use a relative clause to identify or describe something more precisely. | any |
| 4 | A2B1-S4-03 | F | Speak longer, stay organised | I can organise an extended response so the main line is easy to follow. | any |
| 4 | A2B1-S4-04 | F | Get back to your point | I can return to my main point after a clarification question. | any |
| 5 | A2B1-S5-01 | V | Adjust words for the situation | I can adjust familiar wording for a more casual or formal situation. | any |
| 5 | A2B1-S5-02 | G | Control tenses across a story | I can maintain understandable tense control across a story or explanation. | narrative, past_event |
| 5 | A2B1-S5-03 | F | Follow a topic change smoothly | I can respond to a related topic shift without losing the main thread. | any |
| 5 | A2B1-S5-04 | F | Jump into a group discussion | I can enter a simulated group discussion with a relevant contribution. | any |

---

## B2 Topics (→ B1→B2)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | Culture and identity | Culture | abstract, opinion, narrative |
| 2 | Gender equality in India | Gender Equality | opinion, argumentation, abstract, explanation |
| 3 | Education and success | Success | opinion, abstract, comparison, hypothetical |
| 4 | AI and the future of work | AI & Work | abstract, opinion, hypothetical, explanation, argumentation |
| 5 | Social media, mental health, and young people | Youth & Mind | opinion, explanation, abstract |
| 6 | Climate change and India's responsibility | Climate & India | argumentation, explanation, abstract |
| 7 | Migration and opportunity | Migration | abstract, opinion, narrative |
| 8 | Tradition vs. modernity | Old vs New | comparison, abstract, opinion, hypothetical, argumentation |
| 9 | Fake news and media literacy | Fake News | opinion, explanation, argumentation |
| 10 | Entrepreneurship and startups | Startups | narrative, opinion, explanation |
| 11 | Indian literature and storytelling | Indian Stories | abstract, narrative, opinion |
| 12 | Privilege and opportunity | Privilege | abstract, argumentation, opinion, explanation |
| 13 | A belief I changed my mind about | Changed My Mind | narrative, past_event, opinion, abstract |
| 14 | What would India look like in 50 years? | India 2075 | hypothetical, abstract, opinion |
| 15 | Is it ever OK to break a rule? | Breaking Rules | hypothetical, argumentation, abstract |
| 16 | A decision that changed someone's life | Big Decisions | past_event, narrative, hypothetical, opinion |
| 17 | Sports and games I follow and play *(comfort)* | Sports | opinion, narrative, comparison, hypothetical |
| 18 | Music and entertainment I enjoy *(comfort)* | Music | preference, opinion, narrative |
| 19 | My family and the people close to me *(comfort)* | My Family | describing, narrative, opinion, abstract |
| 20 | Food, cooking, and what it means to me *(comfort)* | Food | preference, narrative, opinion, comparison |

### B1→B2 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | B1B2-S1-01 | V | Replace vague with precise words | I can replace vague wording with a more precise expression while preserving meaning. | any |
| 1 | B1B2-S1-02 | V | Use natural word combinations | I can use common collocations appropriately in spontaneous speech. | any |
| 1 | B1B2-S1-03 | G | Explore what if situations | I can use a second conditional to explore an unreal or unlikely situation. | hypothetical |
| 1 | B1B2-S1-04 | F | Explain complex ideas fully | I can explain a complex familiar idea without removing important qualifications. | abstract, opinion |
| 2 | B1B2-S2-01 | V | Show how certain you are | I can choose language that shows an appropriate degree of certainty. | opinion, argumentation |
| 2 | B1B2-S2-02 | G | Discuss unreal past events | I can use a third conditional to explain an unreal past cause and consequence. | hypothetical, past_event |
| 2 | B1B2-S2-03 | G | Report what someone said | I can report a statement or question while preserving its meaning. | narrative, past_event |
| 2 | B1B2-S2-04 | F | Keep complex sentences clear | I can use complex sentences while keeping the main point clear. | any |
| 3 | B1B2-S3-01 | V | Guide speech with signal words | I can use conversational markers to open, redirect, resume, or close a point. | any |
| 3 | B1B2-S3-02 | G | Choose active or passive voice | I can choose active or passive voice according to what I want to emphasise. | explanation |
| 3 | B1B2-S3-03 | F | Speak at length with structure | I can sustain a structured response across connected turns and follow-up questions. | any |
| 3 | B1B2-S3-04 | F | Hold your thread through shifts | I can keep a clear main thread when the conversation moves to a related topic. | any |
| 4 | B1B2-S4-01 | V | Use claim and evidence language | I can use language for claims, evidence, and counterarguments in a discussion. | argumentation |
| 4 | B1B2-S4-02 | G | Emphasise points with structure | I can use linking or emphasis structures to make an argument easier to follow. | argumentation, opinion |
| 4 | B1B2-S4-03 | F | Support and defend a position | I can support a position and address an opposing point. | argumentation, opinion |
| 4 | B1B2-S4-04 | F | Challenge ideas respectfully | I can challenge an idea respectfully and respond to the reply. | argumentation, opinion |
| 5 | B1B2-S5-01 | V | Adapt words to any setting | I can adapt my wording for casual, formal, or persuasive speaking. | any |
| 5 | B1B2-S5-02 | G | Use grammar reliably throughout | I can maintain generally reliable control of B2 grammar across spontaneous tasks. | any |
| 5 | B1B2-S5-03 | F | Respond to anything spontaneously | I can respond spontaneously to familiar and moderately abstract questions. | any |
| 5 | B1B2-S5-04 | F | Show personality while staying clear | I can convey a personal stance and appropriate humour or emphasis while remaining clear. | any |

---

## C1 Topics (→ B2→C1)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | What does it mean to be Indian today? | Being Indian | abstract, opinion, narrative, hypothetical |
| 2 | Moral dilemmas in everyday life | Moral Dilemmas | hypothetical, argumentation, abstract |
| 3 | The ethics of AI | AI Ethics | abstract, argumentation, hypothetical |
| 4 | Caste, class, and social mobility | Caste & Class | abstract, argumentation, opinion |
| 5 | Sustainability and lifestyle choices | Sustainability | argumentation, comparison, abstract |
| 6 | Mental health and stigma | Mental Health | abstract, opinion, explanation |
| 7 | Democracy and young people | Youth & Democracy | abstract, argumentation, opinion |
| 8 | English in India — opportunity or inequality? | English in India | abstract, argumentation, opinion |
| 9 | Art, music, and what they say about a society | Art & Society | abstract, opinion, explanation |
| 10 | Success, happiness, and meaning | What Is Success? | abstract, opinion, narrative, hypothetical |
| 11 | India's role in the world | India & World | abstract, argumentation, explanation |
| 12 | Science, superstition, and belief | Science vs Belief | abstract, argumentation, opinion |
| 13 | Is creativity learned or innate? | Creativity | abstract, opinion, explanation |
| 14 | Should history be taught differently? | Rethink History | argumentation, abstract, comparison, hypothetical |
| 15 | Privacy vs. security | Privacy vs Safety | argumentation, abstract, hypothetical |
| 16 | What does "home" really mean? | Meaning of Home | abstract, opinion, narrative, hypothetical |
| 17 | Sport and what it means to me *(comfort)* | Sports | opinion, narrative, abstract, argumentation |
| 18 | Music and its role in my life *(comfort)* | Music | opinion, abstract, narrative |
| 19 | Family, relationships, and what shapes us *(comfort)* | My Family | abstract, narrative, opinion |
| 20 | Food, culture, and identity *(comfort)* | Food | abstract, opinion, narrative, comparison |

### B2→C1 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | B2C1-S1-01 | V | Choose words for effect | I can choose words for precise meaning, connotation, and context. | any |
| 1 | B2C1-S1-02 | V | Explain and compare abstract ideas | I can explain an abstract concept and distinguish it from a related concept. | abstract |
| 1 | B2C1-S1-03 | G | Emphasise with word order | I can use an emphasis structure when it suits the spoken purpose. | any |
| 1 | B2C1-S1-04 | F | Express subtle, nuanced ideas | I can express a nuanced position with its qualifications and implications intact. | abstract, opinion |
| 2 | B2C1-S2-01 | V | Compress and unpack ideas | I can express a complex idea concisely and unpack it when clarification is needed. | abstract, explanation |
| 2 | B2C1-S2-02 | G | Use should have, could have | I can use modal-perfect forms to evaluate or speculate about past actions. | hypothetical, past_event |
| 2 | B2C1-S2-03 | G | Layer clauses and stay clear | I can use layered clauses while keeping the sentence understandable. | any |
| 2 | B2C1-S2-04 | F | Rephrase for your listener | I can reformulate a complex answer for a listener without losing its meaning. | any |
| 3 | B2C1-S3-01 | V | Steer speech with signal words | I can use discourse markers to signal consequence, concession, movement, or conclusion. | any |
| 3 | B2C1-S3-02 | G | Avoid repetition skilfully | I can use reference and substitution to maintain cohesion without confusing repetition. | any |
| 3 | B2C1-S3-03 | F | Sustain a complex discussion | I can sustain and organise a complex discussion across connected turns. | any |
| 3 | B2C1-S3-04 | F | Join professional discussions confidently | I can contribute effectively to an academic or professional discussion. | any |
| 4 | B2C1-S4-01 | V | Adapt language to your audience | I can adapt vocabulary and register when the audience, relationship, or purpose changes. | any |
| 4 | B2C1-S4-02 | G | Choose emphatic or subtle structures | I can choose among neutral, emphatic, and elliptical structures according to purpose. | any |
| 4 | B2C1-S4-03 | F | Shift style to fit context | I can shift speaking style when the audience or purpose changes. | any |
| 5 | B2C1-S5-01 | V | Carry irony, humour, attitude | I can convey attitude, irony, or humour in a way that makes my intended stance clear. | any |
| 5 | B2C1-S5-02 | G | Catch and fix rare errors | I can maintain high grammatical control and self-correct without disrupting the exchange. | any |
| 5 | B2C1-S5-03 | F | Present, defend, and refine ideas | I can present a complex idea, respond to challenge, and refine it for the listener. | argumentation, abstract |
| 5 | B2C1-S5-04 | F | Handle any unfamiliar task | I can handle an unfamiliar high-level speaking task by clarifying and structuring my response. | any |

---

## C2 Topics (→ C1→C2)

| # | Topic | Label | Affordances |
|---|---|---|---|
| 1 | Does language shape thought? | Language & Thought | abstract, explanation, opinion |
| 2 | Justice, fairness, and what we owe each other | Justice | abstract, argumentation, opinion |
| 3 | How do we know what we know? | Knowledge | abstract, explanation, opinion |
| 4 | What makes us human in an age of machines? | Being Human | abstract, argumentation, hypothetical |
| 5 | Power, privilege, and who gets to tell the story | Power & Story | abstract, argumentation, opinion |
| 6 | The future of democracy | Future Democracy | abstract, argumentation, hypothetical |
| 7 | The ethics of genetic technology | Gene Ethics | abstract, argumentation, hypothetical |
| 8 | What is art for? | Purpose of Art | abstract, opinion, explanation |
| 9 | The self — fixed or fluid? | The Self | abstract, opinion, explanation |
| 10 | The limits of globalisation | Globalisation | abstract, argumentation, comparison |
| 11 | Freedom — how much is too much? | Limits of Freedom | abstract, argumentation, hypothetical |
| 12 | What do we owe future generations? | Future Generations | abstract, argumentation, hypothetical |
| 13 | Is there such a thing as a universal moral truth? | Moral Truth | abstract, argumentation, opinion |
| 14 | The ethics of memory — choosing to forget | Right to Forget | abstract, hypothetical, opinion |
| 15 | Individual responsibility in a broken system | Broken Systems | abstract, argumentation, hypothetical |
| 16 | Can humour change the world? | Power of Humour | abstract, opinion, argumentation |
| 17 | Sport, competition, and what drives us *(comfort)* | Sports | abstract, opinion, argumentation |
| 18 | Music, art, and emotion *(comfort)* | Music | abstract, opinion, explanation |
| 19 | Family, belonging, and identity *(comfort)* | My Family | abstract, opinion, narrative |
| 20 | Food, culture, and memory *(comfort)* | Food | abstract, narrative, opinion |

### C1→C2 Skills

| Unit | ID | Strand | Label | Skill Statement | Affordances |
|---|---|---|---|---|---|
| 1 | C1C2-S1-01 | V | Choose words for rhetorical effect | I can select words for precision, connotation, and rhetorical effect. | any |
| 1 | C1C2-S1-02 | V | Adapt language to any audience | I can adapt language sensitively to audience, relationship, and purpose. | any |
| 1 | C1C2-S1-03 | G | Use literary structures selectively | I can use formal or literary-style structures selectively when they suit the occasion. | any |
| 1 | C1C2-S1-04 | F | Express and defend any idea | I can communicate complex, emotional, abstract, or creative content and clarify it when challenged. | abstract |
| 2 | C1C2-S2-01 | V | Create and read figurative language | I can create and interpret figurative language that fits the conversational context. | abstract |
| 2 | C1C2-S2-02 | G | Use rhythm, emphasis, contrast | I can use syntax, rhythm, emphasis, and contrast deliberately to shape a spoken message. | any |
| 2 | C1C2-S2-03 | G | Use the full grammar range | I can draw on a very wide grammatical repertoire without making marked forms sound inappropriate. | any |
| 2 | C1C2-S2-04 | F | Respond to unseen complex prompts | I can produce an extended, well-structured response to an unseen complex prompt. | any |
| 3 | C1C2-S3-01 | V | Discuss unfamiliar references in context | I can infer and discuss an unfamiliar allusion or historically marked expression when context is provided. | abstract |
| 3 | C1C2-S3-02 | G | Report, hypothesise, shift emphasis | I can flexibly report, hypothesise, and shift emphasis across an extended exchange. | any |
| 3 | C1C2-S3-03 | F | Engage with varied speaker styles | I can engage with proficient speakers who use varied speaking styles and clarify when necessary. | any |
| 3 | C1C2-S3-04 | F | Manage the floor in discussion | I can enter, hold, yield, and regain the floor in a simulated multiparty discussion. | any |
| 4 | C1C2-S4-01 | V | Find words fast under pressure | I can retrieve, replace, and reformulate precise vocabulary under conversational pressure. | any |
| 4 | C1C2-S4-02 | G | Keep grammar steady under load | I can maintain grammatical control while planning, responding to challenge, and changing register. | any |
| 4 | C1C2-S4-03 | F | Fix problems without breaking flow | I can repair a rare language problem unobtrusively while preserving the flow. | any |
| 4 | C1C2-S4-04 | F | Sustain your personal voice | I can sustain a recognisable personal voice across different speaking purposes. | any |
| 5 | C1C2-S5-01 | V | Master vocabulary across contexts | I can use exceptionally precise and flexible vocabulary across demanding speaking contexts. | any |
| 5 | C1C2-S5-02 | G | Command grammar in all styles | I can use a very broad grammatical repertoire accurately and appropriately across contexts. | any |
| 5 | C1C2-S5-03 | F | Vary warmth, authority, creativity | I can deliberately vary warmth, authority, creativity, and restraint while remaining precise. | any |
| 5 | C1C2-S5-04 | F | Adapt to any speaking purpose | I can adapt to unfamiliar, complex speaking purposes without losing precision. | any |

---

## Mapping Logic

**How compatibility works:** A skill can be practised in a session only if at least one of the skill's affordance tags matches at least one of the topic's affordance tags. Skills tagged `any` are compatible with every topic.

**At B1+ the constraint loosens.** Most B1+ skills carry `any` because the skills are about *how* students speak (precision, control, register, argument structure), not *what* they talk about. The topic's tags constrain which *communicative purposes* the conversation naturally supports, but nearly any purpose lets a student demonstrate grammatical control, discourse management, or register flexibility. The affordance tags on B1+ skills are therefore primarily useful for the subset of skills that genuinely need a specific conversational mode — e.g., `hypothetical` for conditionals, `argumentation` for debate skills, `past_event` for past-tense narrative skills.

**Zoe's Pick logic:** Select from the topic pool using recency exclusion (last 2 sessions on that skill). If the pool drops below 7 after exclusion, skip exclusion. From the eligible pool, prefer topics whose affordance tags maximise overlap with the primary skill's tags — but floor always wins over tag-match quality.