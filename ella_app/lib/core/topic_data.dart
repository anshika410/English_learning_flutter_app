// Topic bank — matches the TOPICS object in ella-loop-sim-2.html exactly.
// ~11-12 topics per level across all 6 CEFR levels.

class Topic {
  final String level;
  final String theme;
  final String topic;
  final String starters;

  const Topic({
    required this.level,
    required this.theme,
    required this.topic,
    required this.starters,
  });
}

const Map<String, List<Topic>> kTopics = {
  'A1': [
    Topic(
      level: 'A1',
      theme: 'Self',
      topic: "My name and where I'm from",
      starters:
          '• What is your name? / • How old are you? / • Where are you from? / • Do you have brothers or sisters?',
    ),
    Topic(
      level: 'A1',
      theme: 'Self',
      topic: 'My family',
      starters:
          '• How many people are in your family? / • What does your mother/father do? / • Do you have a pet?',
    ),
    Topic(
      level: 'A1',
      theme: 'Daily life',
      topic: 'My school',
      starters:
          '• What subjects do you study? / • What is your favourite subject? / • What time does school start?',
    ),
    Topic(
      level: 'A1',
      theme: 'Daily life',
      topic: 'Food I like',
      starters:
          '• What is your favourite food? / • Do you like rice or roti? / • What do you eat for breakfast?',
    ),
    Topic(
      level: 'A1',
      theme: 'Daily life',
      topic: 'My daily routine',
      starters:
          '• What time do you wake up? / • What do you do after school? / • Do you watch TV in the evening?',
    ),
    Topic(
      level: 'A1',
      theme: 'Self',
      topic: "Things I like and don't like",
      starters:
          '• Do you like cricket? / • What is your favourite colour? / • Do you like dogs or cats?',
    ),
    Topic(
      level: 'A1',
      theme: 'World around me',
      topic: 'Animals',
      starters:
          '• What is your favourite animal? / • Is a tiger big or small? / • Do you have a pet at home?',
    ),
    Topic(
      level: 'A1',
      theme: 'World around me',
      topic: 'Colours, numbers, and shapes',
      starters:
          '• What colour is your bag? / • How many chairs are in the room? / • What shape is a cricket ball?',
    ),
    Topic(
      level: 'A1',
      theme: 'World around me',
      topic: 'My home',
      starters:
          '• How many rooms are in your house? / • What is in your bedroom? / • Where do you eat?',
    ),
    Topic(
      level: 'A1',
      theme: 'World around me',
      topic: 'Sports and games',
      starters:
          '• Do you play cricket? / • What games do you play with friends? / • Do you like sports?',
    ),
    Topic(
      level: 'A1',
      theme: 'Festivals and culture',
      topic: 'Festivals I celebrate',
      starters:
          '• What festivals do you celebrate? / • What do you eat during Diwali/Eid/Christmas? / • Do you like festivals?',
    ),
  ],
  'A2': [
    Topic(
      level: 'A2',
      theme: 'Self',
      topic: 'My hobbies and free time',
      starters:
          '• What do you like to do after school? / • Do you prefer indoor or outdoor activities? / • How often do you play/read/watch...?',
    ),
    Topic(
      level: 'A2',
      theme: 'Self',
      topic: 'My friends',
      starters:
          '• Tell me about your best friend. / • What do you and your friends do together? / • Where did you meet your best friend?',
    ),
    Topic(
      level: 'A2',
      theme: 'Daily life',
      topic: 'A typical week',
      starters:
          '• What do you usually do on weekends? / • Is Monday your busiest day? / • What do you do on Sunday mornings?',
    ),
    Topic(
      level: 'A2',
      theme: 'Daily life',
      topic: 'Shopping and markets',
      starters:
          '• Where do you go shopping? / • What did you buy last time? / • Is shopping online better than going to a market?',
    ),
    Topic(
      level: 'A2',
      theme: 'Daily life',
      topic: 'Food and restaurants',
      starters:
          '• What is the best meal you have ever eaten? / • Do you prefer home food or restaurant food? / • Have you ever tried food from another country?',
    ),
    Topic(
      level: 'A2',
      theme: 'World around me',
      topic: 'My city or town',
      starters:
          '• What is good about your city? / • How do you get to school? / • What would you change about where you live?',
    ),
    Topic(
      level: 'A2',
      theme: 'World around me',
      topic: 'Weather and seasons',
      starters:
          '• What is the weather like today? / • What is your favourite season? / • What do you do when it rains?',
    ),
    Topic(
      level: 'A2',
      theme: 'World around me',
      topic: 'Transport and travel',
      starters:
          '• How do you travel to school? / • Have you ever been on a train? / • Where did you go on your last trip?',
    ),
    Topic(
      level: 'A2',
      theme: 'Experiences',
      topic: 'A trip or holiday',
      starters:
          '• Where did you go on your last holiday? / • What did you do there? / • Would you like to go back?',
    ),
    Topic(
      level: 'A2',
      theme: 'Experiences',
      topic: 'Films and TV shows',
      starters:
          '• What is your favourite film or show? / • What kind of films do you like? / • Who is your favourite actor?',
    ),
    Topic(
      level: 'A2',
      theme: 'Experiences',
      topic: 'Celebrations and special days',
      starters:
          '• What did you do on your last birthday? / • What is the biggest celebration in your family? / • Tell me about a festival you enjoyed.',
    ),
    Topic(
      level: 'A2',
      theme: 'Opinions',
      topic: 'School subjects — likes and dislikes',
      starters:
          '• What is your favourite subject and why? / • Is there a subject you find difficult? / • Do you think English is important?',
    ),
  ],
  'B1': [
    Topic(
      level: 'B1',
      theme: 'Self and identity',
      topic: 'My ambitions and future plans',
      starters:
          '• What do you want to do after school? / • If you could have any job, what would it be? / • What are you studying to become?',
    ),
    Topic(
      level: 'B1',
      theme: 'Self and identity',
      topic: 'My personality and values',
      starters:
          '• How would your best friend describe you? / • What is something you are proud of? / • What is most important to you in a friend?',
    ),
    Topic(
      level: 'B1',
      theme: 'Society',
      topic: 'Education in India',
      starters:
          '• Do you think exams are the best way to test students? / • Is there too much pressure on students in India? / • Should school be more practical?',
    ),
    Topic(
      level: 'B1',
      theme: 'Society',
      topic: 'Social media and technology',
      starters:
          '• How much time do you spend on social media? / • Do you think social media is good or bad for teenagers? / • What would you do without your phone for a week?',
    ),
    Topic(
      level: 'B1',
      theme: 'Society',
      topic: 'City life vs. village life',
      starters:
          '• Would you prefer to live in a city or a village? / • What are the biggest differences between city and village life? / • Is it better to grow up in a city?',
    ),
    Topic(
      level: 'B1',
      theme: 'Culture and society',
      topic: 'Festivals and traditions',
      starters:
          '• Why do you think festivals are important? / • Has the way your family celebrates changed over the years? / • Which festival means most to you and why?',
    ),
    Topic(
      level: 'B1',
      theme: 'Environment',
      topic: 'The environment and pollution',
      starters:
          '• Is pollution a serious problem where you live? / • What do you do to help the environment? / • Should the government do more to reduce pollution?',
    ),
    Topic(
      level: 'B1',
      theme: 'Health',
      topic: 'Health and lifestyle',
      starters:
          '• Do you think you lead a healthy lifestyle? / • What is the biggest health problem for young people today? / • Should schools teach more about health?',
    ),
    Topic(
      level: 'B1',
      theme: 'Culture',
      topic: 'Indian cinema and music',
      starters:
          '• What kind of music do you listen to? / • Do you prefer Bollywood or Hollywood films? / • Has Indian cinema changed in recent years?',
    ),
    Topic(
      level: 'B1',
      theme: 'Relationships',
      topic: 'Friendship and trust',
      starters:
          '• What makes someone a good friend? / • Have you ever had an argument with a friend? / • Is it better to have many friends or a few close ones?',
    ),
    Topic(
      level: 'B1',
      theme: 'Media',
      topic: 'News and current events',
      starters:
          '• Do you follow the news? / • What is a news story you remember recently? / • Do you trust everything you read online?',
    ),
    Topic(
      level: 'B1',
      theme: 'Sport',
      topic: 'Cricket and sport in India',
      starters:
          '• Why is cricket so popular in India? / • Who is your favourite cricketer and why? / • Should students be encouraged to pursue sport as a career?',
    ),
  ],
  'B2': [
    Topic(
      level: 'B2',
      theme: 'Identity',
      topic: 'Culture and identity',
      starters:
          '• How much has your culture shaped who you are? / • Do you feel more Indian or more of your city/state? / • Can you belong to two cultures at once?',
    ),
    Topic(
      level: 'B2',
      theme: 'Society',
      topic: 'Gender equality in India',
      starters:
          '• Do you think men and women have equal opportunities in India today? / • How have gender roles changed in your family across generations? / • What more needs to change?',
    ),
    Topic(
      level: 'B2',
      theme: 'Society',
      topic: 'Education and success',
      starters:
          '• Is a university degree still the best path to success? / • Does the Indian education system prepare you for real life? / • What does success mean to you?',
    ),
    Topic(
      level: 'B2',
      theme: 'Technology',
      topic: 'Artificial intelligence and the future of work',
      starters:
          '• Will AI take away more jobs than it creates? / • What jobs do you think are safe from AI? / • Should schools teach students to work with AI?',
    ),
    Topic(
      level: 'B2',
      theme: 'Technology',
      topic: 'Social media, mental health, and young people',
      starters:
          '• Does social media make young people more anxious? / • Should there be age limits on social media? / • Can social media ever be genuinely good for mental health?',
    ),
    Topic(
      level: 'B2',
      theme: 'Environment',
      topic: "Climate change and India's responsibility",
      starters:
          "• Should developing countries like India sacrifice growth to protect the climate? / • What changes have you noticed in the environment in your lifetime? / • Who should pay?",
    ),
    Topic(
      level: 'B2',
      theme: 'Society',
      topic: 'Migration and opportunity',
      starters:
          '• Why do so many young Indians move abroad to study or work? / • What do people gain and lose when they migrate? / • Would you ever leave India permanently?',
    ),
    Topic(
      level: 'B2',
      theme: 'Values',
      topic: 'Tradition vs. modernity',
      starters:
          '• Are traditional values a strength or a limitation? / • Have your values changed from your parents\' generation? / • Can a society modernise without losing its identity?',
    ),
    Topic(
      level: 'B2',
      theme: 'Media',
      topic: 'Fake news and media literacy',
      starters:
          '• How do you decide whether a news story is true? / • Why is fake news so easy to spread in India? / • Who is responsible for stopping misinformation?',
    ),
    Topic(
      level: 'B2',
      theme: 'Work and ambition',
      topic: 'Entrepreneurship and startups',
      starters:
          '• Would you rather work for a company or start your own? / • Why has India become a major startup hub? / • Is entrepreneurship about luck or skill?',
    ),
    Topic(
      level: 'B2',
      theme: 'Arts and culture',
      topic: 'Indian literature and storytelling',
      starters:
          '• Have you read an Indian author writing in English? / • Why are stories important to a culture? / • Is reading becoming less popular among young people?',
    ),
    Topic(
      level: 'B2',
      theme: 'Values',
      topic: 'Privilege and opportunity',
      starters:
          "• Do you think where you are born determines your future? / • What privileges have helped you that others don't have? / • What should governments do to create more equal opportunity?",
    ),
  ],
  'C1': [
    Topic(
      level: 'C1',
      theme: 'Identity and society',
      topic: 'What does it mean to be Indian today?',
      starters:
          '• Is there one Indian identity or many? / • How has the idea of being Indian changed across generations? / • Can you be deeply rooted in your culture and still be a global citizen?',
    ),
    Topic(
      level: 'C1',
      theme: 'Ethics',
      topic: 'Moral dilemmas in everyday life',
      starters:
          '• If you found a wallet full of money, what would you do? / • Is it ever right to lie to protect someone? / • Should you report a friend if they did something wrong?',
    ),
    Topic(
      level: 'C1',
      theme: 'Technology and humanity',
      topic: 'The ethics of artificial intelligence',
      starters:
          "• Should AI systems be allowed to make decisions that affect people's lives? / • Can a machine ever be truly ethical? / • Who is responsible when an AI makes a mistake?",
    ),
    Topic(
      level: 'C1',
      theme: 'Society',
      topic: 'Caste, class, and social mobility',
      starters:
          "• Has caste become less important in your generation than your parents'? / • What does social mobility look like in India today? / • Is economic class replacing caste?",
    ),
    Topic(
      level: 'C1',
      theme: 'Environment',
      topic: 'Sustainability and lifestyle choices',
      starters:
          '• Can individual choices really make a difference to climate change? / • Is it fair to ask ordinary people to change their lifestyle when corporations pollute far more? / • What would you give up for the planet?',
    ),
    Topic(
      level: 'C1',
      theme: 'Psychology',
      topic: 'Mental health and stigma',
      starters:
          '• Why is there still stigma around mental health in India? / • Has the conversation about mental health changed in your generation? / • Should mental health education be compulsory in schools?',
    ),
    Topic(
      level: 'C1',
      theme: 'Power and politics',
      topic: 'Democracy and young people',
      starters:
          '• Do young people in India feel represented by politicians? / • Should voting be compulsory? / • Can social media strengthen or weaken democracy?',
    ),
    Topic(
      level: 'C1',
      theme: 'Language',
      topic: 'English in India — opportunity or inequality?',
      starters:
          '• Does speaking English well give you an unfair advantage in India? / • Should English be replaced by Hindi as the national language? / • What is lost when a language dies?',
    ),
    Topic(
      level: 'C1',
      theme: 'Arts and meaning',
      topic: 'Art, music, and what they say about a society',
      starters:
          '• What does Bollywood tell us about what Indian society values? / • Can art change minds? / • Is there such a thing as art that is purely entertainment with no social meaning?',
    ),
    Topic(
      level: 'C1',
      theme: 'Philosophy',
      topic: 'Success, happiness, and meaning',
      starters:
          '• Is it possible to be successful but unhappy? / • What does a meaningful life look like to you? / • Has your idea of success changed as you have grown up?',
    ),
    Topic(
      level: 'C1',
      theme: 'Global issues',
      topic: "India's role in the world",
      starters:
          "• Is India doing enough to use its influence for good in the world? / • How is India's relationship with its neighbours shaping its global role? / • What does India owe to less powerful countries?",
    ),
    Topic(
      level: 'C1',
      theme: 'Science and society',
      topic: 'Science, superstition, and belief in modern India',
      starters:
          '• How do you explain that India can launch missions to the moon and still have widespread superstition? / • Is it possible to be both deeply religious and rigorously scientific?',
    ),
  ],
  'C2': [
    Topic(
      level: 'C2',
      theme: 'Philosophy of language',
      topic: 'Does language shape thought?',
      starters:
          '• Do you think in English or in your mother tongue? / • Are there ideas in your first language that simply don\'t exist in English? / • Does speaking multiple languages change who you are?',
    ),
    Topic(
      level: 'C2',
      theme: 'Ethics',
      topic: 'Justice, fairness, and what we owe each other',
      starters:
          '• Is justice about punishment or rehabilitation? / • What do the privileged owe those who are not? / • Can a system be unjust even if no individual in it acts badly?',
    ),
    Topic(
      level: 'C2',
      theme: 'Knowledge and truth',
      topic: 'How do we know what we know?',
      starters:
          '• Is there such a thing as objective truth? / • How much of what you believe is based on evidence rather than feeling? / • Can two people disagree about facts — not just values?',
    ),
    Topic(
      level: 'C2',
      theme: 'Technology and humanity',
      topic: 'What makes us human in an age of machines?',
      starters:
          '• Is creativity uniquely human? / • If a machine could feel pain, would it deserve rights? / • What do you think you can do that no machine ever will?',
    ),
    Topic(
      level: 'C2',
      theme: 'Society',
      topic: 'Power, privilege, and who gets to tell the story',
      starters:
          "• Who gets to decide which stories are important? / • Has India's history been told fairly — by Indians and by others? / • Why does representation in media and politics matter?",
    ),
    Topic(
      level: 'C2',
      theme: 'Global future',
      topic: 'The future of democracy',
      starters:
          '• Is democracy in crisis globally? / • Are there circumstances under which democracy might need to be suspended? / • Can democracy survive the internet?',
    ),
    Topic(
      level: 'C2',
      theme: 'Science and ethics',
      topic: 'The ethics of genetic technology',
      starters:
          '• Should parents be allowed to choose the genetic traits of their children? / • Who owns your genetic data? / • Where is the line between treating disease and engineering humans?',
    ),
    Topic(
      level: 'C2',
      theme: 'Arts and culture',
      topic: 'What is art for?',
      starters:
          '• Does art have a responsibility to be political? / • Is there a difference between art and entertainment? / • Can something be great art even if almost no one understands it?',
    ),
    Topic(
      level: 'C2',
      theme: 'Identity',
      topic: 'The self — fixed or fluid?',
      starters:
          '• Are you the same person you were ten years ago? / • Do you present different versions of yourself in different contexts — or is one of them the real you? / • What would it take to fundamentally change who you are?',
    ),
    Topic(
      level: 'C2',
      theme: 'Global issues',
      topic: 'The limits of globalisation',
      starters:
          '• Has globalisation made India stronger or more dependent? / • What has India gained and lost from opening up to the world? / • Is globalisation reversing — and is that good?',
    ),
    Topic(
      level: 'C2',
      theme: 'Philosophy',
      topic: 'Freedom — how much is too much?',
      starters:
          "• Should people be free to do anything that doesn't harm others? / • Is freedom of speech absolute? / • Can a society be too free?",
    ),
    Topic(
      level: 'C2',
      theme: 'Legacy and meaning',
      topic: 'What do we owe future generations?',
      starters:
          '• Are we living in a way that is fair to people who will be born in 100 years? / • What is the most important thing your generation must do? / • Can you have obligations to people who do not yet exist?',
    ),
  ],
};
