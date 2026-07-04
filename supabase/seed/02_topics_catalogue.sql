-- ============================================================
-- ELLA — topics_catalogue seed
-- ~11-12 topics per level × 6 CEFR levels
-- Source: ella_app/lib/core/topic_data.dart (authoritative)
-- Run AFTER 001_schema.sql.
-- ============================================================

truncate topics_catalogue restart identity cascade;

-- ── A1 (11 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('A1','Self','My name and where I''m from','• What is your name? / • How old are you? / • Where are you from? / • Do you have brothers or sisters?'),
('A1','Self','My family','• How many people are in your family? / • What does your mother/father do? / • Do you have a pet?'),
('A1','Daily life','My school','• What subjects do you study? / • What is your favourite subject? / • What time does school start?'),
('A1','Daily life','Food I like','• What is your favourite food? / • Do you like rice or roti? / • What do you eat for breakfast?'),
('A1','Daily life','My daily routine','• What time do you wake up? / • What do you do after school? / • Do you watch TV in the evening?'),
('A1','Self','Things I like and don''t like','• Do you like cricket? / • What is your favourite colour? / • Do you like dogs or cats?'),
('A1','World around me','Animals','• What is your favourite animal? / • Is a tiger big or small? / • Do you have a pet at home?'),
('A1','World around me','Colours, numbers, and shapes','• What colour is your bag? / • How many chairs are in the room? / • What shape is a cricket ball?'),
('A1','World around me','My home','• How many rooms are in your house? / • What is in your bedroom? / • Where do you eat?'),
('A1','World around me','Sports and games','• Do you play cricket? / • What games do you play with friends? / • Do you like sports?'),
('A1','Festivals and culture','Festivals I celebrate','• What festivals do you celebrate? / • What do you eat during Diwali/Eid/Christmas? / • Do you like festivals?');

-- ── A2 (12 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('A2','Self','My hobbies and free time','• What do you like to do after school? / • Do you prefer indoor or outdoor activities? / • How often do you play/read/watch...?'),
('A2','Self','My friends','• Tell me about your best friend. / • What do you and your friends do together? / • Where did you meet your best friend?'),
('A2','Daily life','A typical week','• What do you usually do on weekends? / • Is Monday your busiest day? / • What do you do on Sunday mornings?'),
('A2','Daily life','Shopping and markets','• Where do you go shopping? / • What did you buy last time? / • Is shopping online better than going to a market?'),
('A2','Daily life','Food and restaurants','• What is the best meal you have ever eaten? / • Do you prefer home food or restaurant food? / • Have you ever tried food from another country?'),
('A2','World around me','My city or town','• What is good about your city? / • How do you get to school? / • What would you change about where you live?'),
('A2','World around me','Weather and seasons','• What is the weather like today? / • What is your favourite season? / • What do you do when it rains?'),
('A2','World around me','Transport and travel','• How do you travel to school? / • Have you ever been on a train? / • Where did you go on your last trip?'),
('A2','Experiences','A trip or holiday','• Where did you go on your last holiday? / • What did you do there? / • Would you like to go back?'),
('A2','Experiences','Films and TV shows','• What is your favourite film or show? / • What kind of films do you like? / • Who is your favourite actor?'),
('A2','Experiences','Celebrations and special days','• What did you do on your last birthday? / • What is the biggest celebration in your family? / • Tell me about a festival you enjoyed.'),
('A2','Opinions','School subjects — likes and dislikes','• What is your favourite subject and why? / • Is there a subject you find difficult? / • Do you think English is important?');

-- ── B1 (12 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('B1','Self and identity','My ambitions and future plans','• What do you want to do after school? / • If you could have any job, what would it be? / • What are you studying to become?'),
('B1','Self and identity','My personality and values','• How would your best friend describe you? / • What is something you are proud of? / • What is most important to you in a friend?'),
('B1','Society','Education in India','• Do you think exams are the best way to test students? / • Is there too much pressure on students in India? / • Should school be more practical?'),
('B1','Society','Social media and technology','• How much time do you spend on social media? / • Do you think social media is good or bad for teenagers? / • What would you do without your phone for a week?'),
('B1','Society','City life vs. village life','• Would you prefer to live in a city or a village? / • What are the biggest differences between city and village life? / • Is it better to grow up in a city?'),
('B1','Culture and society','Festivals and traditions','• Why do you think festivals are important? / • Has the way your family celebrates changed over the years? / • Which festival means most to you and why?'),
('B1','Environment','The environment and pollution','• Is pollution a serious problem where you live? / • What do you do to help the environment? / • Should the government do more to reduce pollution?'),
('B1','Health','Health and lifestyle','• Do you think you lead a healthy lifestyle? / • What is the biggest health problem for young people today? / • Should schools teach more about health?'),
('B1','Culture','Indian cinema and music','• What kind of music do you listen to? / • Do you prefer Bollywood or Hollywood films? / • Has Indian cinema changed in recent years?'),
('B1','Relationships','Friendship and trust','• What makes someone a good friend? / • Have you ever had an argument with a friend? / • Is it better to have many friends or a few close ones?'),
('B1','Media','News and current events','• Do you follow the news? / • What is a news story you remember recently? / • Do you trust everything you read online?'),
('B1','Sport','Cricket and sport in India','• Why is cricket so popular in India? / • Who is your favourite cricketer and why? / • Should students be encouraged to pursue sport as a career?');

-- ── B2 (12 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('B2','Identity','Culture and identity','• How much has your culture shaped who you are? / • Do you feel more Indian or more of your city/state? / • Can you belong to two cultures at once?'),
('B2','Society','Gender equality in India','• Do you think men and women have equal opportunities in India today? / • How have gender roles changed in your family across generations? / • What more needs to change?'),
('B2','Society','Education and success','• Is a university degree still the best path to success? / • Does the Indian education system prepare you for real life? / • What does success mean to you?'),
('B2','Technology','Artificial intelligence and the future of work','• Will AI take away more jobs than it creates? / • What jobs do you think are safe from AI? / • Should schools teach students to work with AI?'),
('B2','Technology','Social media, mental health, and young people','• Does social media make young people more anxious? / • Should there be age limits on social media? / • Can social media ever be genuinely good for mental health?'),
('B2','Environment','Climate change and India''s responsibility','• Should developing countries like India sacrifice growth to protect the climate? / • What changes have you noticed in the environment in your lifetime? / • Who should pay?'),
('B2','Society','Migration and opportunity','• Why do so many young Indians move abroad to study or work? / • What do people gain and lose when they migrate? / • Would you ever leave India permanently?'),
('B2','Values','Tradition vs. modernity','• Are traditional values a strength or a limitation? / • Have your values changed from your parents'' generation? / • Can a society modernise without losing its identity?'),
('B2','Media','Fake news and media literacy','• How do you decide whether a news story is true? / • Why is fake news so easy to spread in India? / • Who is responsible for stopping misinformation?'),
('B2','Work and ambition','Entrepreneurship and startups','• Would you rather work for a company or start your own? / • Why has India become a major startup hub? / • Is entrepreneurship about luck or skill?'),
('B2','Arts and culture','Indian literature and storytelling','• Have you read an Indian author writing in English? / • Why are stories important to a culture? / • Is reading becoming less popular among young people?'),
('B2','Values','Privilege and opportunity','• Do you think where you are born determines your future? / • What privileges have helped you that others don''t have? / • What should governments do to create more equal opportunity?');

-- ── C1 (12 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('C1','Identity and society','What does it mean to be Indian today?','• Is there one Indian identity or many? / • How has the idea of being Indian changed across generations? / • Can you be deeply rooted in your culture and still be a global citizen?'),
('C1','Ethics','Moral dilemmas in everyday life','• If you found a wallet full of money, what would you do? / • Is it ever right to lie to protect someone? / • Should you report a friend if they did something wrong?'),
('C1','Technology and humanity','The ethics of artificial intelligence','• Should AI systems be allowed to make decisions that affect people''s lives? / • Can a machine ever be truly ethical? / • Who is responsible when an AI makes a mistake?'),
('C1','Society','Caste, class, and social mobility','• Has caste become less important in your generation than your parents''? / • What does social mobility look like in India today? / • Is economic class replacing caste?'),
('C1','Environment','Sustainability and lifestyle choices','• Can individual choices really make a difference to climate change? / • Is it fair to ask ordinary people to change their lifestyle when corporations pollute far more? / • What would you give up for the planet?'),
('C1','Psychology','Mental health and stigma','• Why is there still stigma around mental health in India? / • Has the conversation about mental health changed in your generation? / • Should mental health education be compulsory in schools?'),
('C1','Power and politics','Democracy and young people','• Do young people in India feel represented by politicians? / • Should voting be compulsory? / • Can social media strengthen or weaken democracy?'),
('C1','Language','English in India — opportunity or inequality?','• Does speaking English well give you an unfair advantage in India? / • Should English be replaced by Hindi as the national language? / • What is lost when a language dies?'),
('C1','Arts and meaning','Art, music, and what they say about a society','• What does Bollywood tell us about what Indian society values? / • Can art change minds? / • Is there such a thing as art that is purely entertainment with no social meaning?'),
('C1','Philosophy','Success, happiness, and meaning','• Is it possible to be successful but unhappy? / • What does a meaningful life look like to you? / • Has your idea of success changed as you have grown up?'),
('C1','Global issues','India''s role in the world','• Is India doing enough to use its influence for good in the world? / • How is India''s relationship with its neighbours shaping its global role? / • What does India owe to less powerful countries?'),
('C1','Science and society','Science, superstition, and belief in modern India','• How do you explain that India can launch missions to the moon and still have widespread superstition? / • Is it possible to be both deeply religious and rigorously scientific?');

-- ── C2 (12 topics) ──────────────────────────────────────────────────────────
insert into topics_catalogue (level, theme, topic, starters) values
('C2','Philosophy of language','Does language shape thought?','• Do you think in English or in your mother tongue? / • Are there ideas in your first language that simply don''t exist in English? / • Does speaking multiple languages change who you are?'),
('C2','Ethics','Justice, fairness, and what we owe each other','• Is justice about punishment or rehabilitation? / • What do the privileged owe those who are not? / • Can a system be unjust even if no individual in it acts badly?'),
('C2','Knowledge and truth','How do we know what we know?','• Is there such a thing as objective truth? / • How much of what you believe is based on evidence rather than feeling? / • Can two people disagree about facts — not just values?'),
('C2','Technology and humanity','What makes us human in an age of machines?','• Is creativity uniquely human? / • If a machine could feel pain, would it deserve rights? / • What do you think you can do that no machine ever will?'),
('C2','Society','Power, privilege, and who gets to tell the story','• Who gets to decide which stories are important? / • Has India''s history been told fairly — by Indians and by others? / • Why does representation in media and politics matter?'),
('C2','Global future','The future of democracy','• Is democracy in crisis globally? / • Are there circumstances under which democracy might need to be suspended? / • Can democracy survive the internet?'),
('C2','Science and ethics','The ethics of genetic technology','• Should parents be allowed to choose the genetic traits of their children? / • Who owns your genetic data? / • Where is the line between treating disease and engineering humans?'),
('C2','Arts and culture','What is art for?','• Does art have a responsibility to be political? / • Is there a difference between art and entertainment? / • Can something be great art even if almost no one understands it?'),
('C2','Identity','The self — fixed or fluid?','• Are you the same person you were ten years ago? / • Do you present different versions of yourself in different contexts — or is one of them the real you? / • What would it take to fundamentally change who you are?'),
('C2','Global issues','The limits of globalisation','• Has globalisation made India stronger or more dependent? / • What has India gained and lost from opening up to the world? / • Is globalisation reversing — and is that good?'),
('C2','Philosophy','Freedom — how much is too much?','• Should people be free to do anything that doesn''t harm others? / • Is freedom of speech absolute? / • Can a society be too free?'),
('C2','Legacy and meaning','What do we owe future generations?','• Are we living in a way that is fair to people who will be born in 100 years? / • What is the most important thing your generation must do? / • Can you have obligations to people who do not yet exist?');

-- ── Row-count assertion ──────────────────────────────────────────────────────
do $$
declare total int;
begin
  select count(*) into total from topics_catalogue;
  if total < 60 then
    raise exception 'SEED FAIL: expected >=60 topics, got %', total;
  end if;
  raise notice 'topics_catalogue OK: % topics seeded', total;
end;
$$;
