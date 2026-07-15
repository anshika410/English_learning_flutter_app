// API-free topic fixtures for the installed GARDEN_PREVIEW build.
//
// Generated from backend/app/core/curriculum_data.py LEVEL_TOPICS and
// backend/app/routers/users.py TOPIC_ICON_MAP. Keep those sources in sync when
// the curriculum changes; production topic suggestions still come from the
// memory API.

import '../models/child_memory.dart';

const Map<String, List<TopicChoice>> topicPreviewCatalog = {
  'A0': [
    TopicChoice(
      name: "My name and where I'm from",
      label: 'About me',
      icon: 'a1-01-my-name',
    ),
    TopicChoice(name: 'My family', label: 'Family', icon: 'a1-02-my-family'),
    TopicChoice(name: 'My school', label: 'School', icon: 'a1-03-my-school'),
    TopicChoice(name: 'Food I like', label: 'Food', icon: 'a1-04-food-i-like'),
    TopicChoice(
      name: 'My daily routine',
      label: 'Routine',
      icon: 'a1-05-my-daily-routine',
    ),
    TopicChoice(
      name: "Things I like and don't like",
      label: 'Likes',
      icon: 'a1-06-likes-dontlikes',
    ),
    TopicChoice(name: 'Animals', label: 'Animals', icon: 'a1-07-animals'),
    TopicChoice(
      name: 'Colours, numbers, and shapes',
      label: 'Colours',
      icon: 'a1-08-colours-numbers-shapes',
    ),
    TopicChoice(name: 'My home', label: 'Home', icon: 'a1-09-my-home'),
    TopicChoice(
      name: 'Sports and games',
      label: 'Sports',
      icon: 'a1-10-sports-and-games',
    ),
    TopicChoice(
      name: 'Festivals I celebrate',
      label: 'Festivals',
      icon: 'a1-11-festivals',
    ),
  ],
  'A1': [
    TopicChoice(
      name: 'My hobbies and free time',
      label: 'Hobbies',
      icon: 'a2-01-hobbies-free-time',
    ),
    TopicChoice(name: 'My friends', label: 'Friends', icon: 'a2-02-my-friends'),
    TopicChoice(
      name: 'A typical week',
      label: 'My week',
      icon: 'a2-03-typical-week',
    ),
    TopicChoice(
      name: 'Shopping and markets',
      label: 'Shopping',
      icon: 'a2-04-shopping-and-markets',
    ),
    TopicChoice(
      name: 'Food and restaurants',
      label: 'Eating out',
      icon: 'a2-05-food-and-restaurants',
    ),
    TopicChoice(
      name: 'My city or town',
      label: 'My city',
      icon: 'a2-06-my-city-or-town',
    ),
    TopicChoice(
      name: 'Weather and seasons',
      label: 'Weather',
      icon: 'a2-07-weather-and-seasons',
    ),
    TopicChoice(
      name: 'Transport and travel',
      label: 'Transport',
      icon: 'a2-08-transport-and-travel',
    ),
    TopicChoice(
      name: 'A trip or holiday',
      label: 'Holidays',
      icon: 'a2-09-a-trip-or-holiday',
    ),
    TopicChoice(
      name: 'Films and TV shows',
      label: 'Films',
      icon: 'a2-10-films-and-tv-shows',
    ),
    TopicChoice(
      name: 'Celebrations and special days',
      label: 'Celebrations',
      icon: 'a2-11-celebrations',
    ),
    TopicChoice(
      name: 'School subjects — likes and dislikes',
      label: 'Subjects',
      icon: 'a2-12-school-subjects',
    ),
  ],
  'A2': [
    TopicChoice(
      name: 'My ambitions and future plans',
      label: 'Ambitions',
      icon: 'b1-01-ambitions-future-plans',
    ),
    TopicChoice(
      name: 'My personality and values',
      label: 'Personality',
      icon: 'b1-02-personality-and-values',
    ),
    TopicChoice(
      name: 'Education in India',
      label: 'Education',
      icon: 'b1-03-education-in-india',
    ),
    TopicChoice(
      name: 'Social media and technology',
      label: 'Social media',
      icon: 'b1-04-social-media-technology',
    ),
    TopicChoice(
      name: 'City life vs. village life',
      label: 'City vs village',
      icon: 'b1-05-city-vs-village',
    ),
    TopicChoice(
      name: 'Festivals and traditions',
      label: 'Traditions',
      icon: 'b1-06-festivals-and-traditions',
    ),
    TopicChoice(
      name: 'The environment and pollution',
      label: 'Environment',
      icon: 'b1-07-environment-pollution',
    ),
    TopicChoice(
      name: 'Health and lifestyle',
      label: 'Health',
      icon: 'b1-08-health-and-lifestyle',
    ),
    TopicChoice(
      name: 'Indian cinema and music',
      label: 'Cinema',
      icon: 'b1-09-indian-cinema-music',
    ),
    TopicChoice(
      name: 'Friendship and trust',
      label: 'Friendship',
      icon: 'b1-10-friendship-and-trust',
    ),
    TopicChoice(
      name: 'News and current events',
      label: 'News',
      icon: 'b1-11-news-current-events',
    ),
    TopicChoice(
      name: 'Cricket and sport in India',
      label: 'Cricket',
      icon: 'b1-12-cricket-and-sport',
    ),
  ],
  'B1': [
    TopicChoice(
      name: 'Culture and identity',
      label: 'Culture',
      icon: 'b2-01-culture-and-identity',
    ),
    TopicChoice(
      name: 'Gender equality in India',
      label: 'Gender',
      icon: 'b2-02-gender-equality',
    ),
    TopicChoice(
      name: 'Education and success',
      label: 'Success',
      icon: 'b2-03-education-and-success',
    ),
    TopicChoice(
      name: 'Artificial intelligence and the future of work',
      label: 'AI and work',
      icon: 'b2-04-ai-future-of-work',
    ),
    TopicChoice(
      name: 'Social media, mental health, and young people',
      label: 'Mental health',
      icon: 'b2-05-social-media-mental-health',
    ),
    TopicChoice(
      name: "Climate change and India's responsibility",
      label: 'Climate',
      icon: 'b2-06-climate-change-india',
    ),
    TopicChoice(
      name: 'Migration and opportunity',
      label: 'Migration',
      icon: 'b2-07-migration-and-opportunity',
    ),
    TopicChoice(
      name: 'Tradition vs. modernity',
      label: 'Old vs new',
      icon: 'b2-08-tradition-vs-modernity',
    ),
    TopicChoice(
      name: 'Fake news and media literacy',
      label: 'Fake news',
      icon: 'b2-09-fake-news-media-literacy',
    ),
    TopicChoice(
      name: 'Entrepreneurship and startups',
      label: 'Startups',
      icon: 'b2-10-entrepreneurship-startups',
    ),
    TopicChoice(
      name: 'Indian literature and storytelling',
      label: 'Literature',
      icon: 'b2-11-indian-literature-storytelling',
    ),
    TopicChoice(
      name: 'Privilege and opportunity',
      label: 'Privilege',
      icon: 'b2-12-privilege-and-opportunity',
    ),
  ],
  'B2': [
    TopicChoice(
      name: 'What does it mean to be Indian today?',
      label: 'Being Indian',
      icon: 'c1-01-what-does-it-mean-indian',
    ),
    TopicChoice(
      name: 'Moral dilemmas in everyday life',
      label: 'Moral dilemmas',
      icon: 'c1-02-moral-dilemmas',
    ),
    TopicChoice(
      name: 'The ethics of artificial intelligence',
      label: 'AI ethics',
      icon: 'c1-03-ethics-of-ai',
    ),
    TopicChoice(
      name: 'Caste, class, and social mobility',
      label: 'Caste',
      icon: 'c1-04-caste-class-social-mobility',
    ),
    TopicChoice(
      name: 'Sustainability and lifestyle choices',
      label: 'Sustainability',
      icon: 'c1-05-sustainability-lifestyle',
    ),
    TopicChoice(
      name: 'Mental health and stigma',
      label: 'Stigma',
      icon: 'c1-06-mental-health-stigma',
    ),
    TopicChoice(
      name: 'Democracy and young people',
      label: 'Democracy',
      icon: 'c1-07-democracy-young-people',
    ),
    TopicChoice(
      name: 'English in India — opportunity or inequality?',
      label: 'English',
      icon: 'c1-08-english-in-india',
    ),
    TopicChoice(
      name: 'Art, music, and what they say about a society',
      label: 'Art and music',
      icon: 'c1-09-art-music-society',
    ),
    TopicChoice(
      name: 'Success, happiness, and meaning',
      label: 'Happiness',
      icon: 'c1-10-success-happiness-meaning',
    ),
    TopicChoice(
      name: "India's role in the world",
      label: "India's role",
      icon: 'c1-11-indias-role-in-world',
    ),
    TopicChoice(
      name: 'Science, superstition, and belief in modern India',
      label: 'Superstition',
      icon: 'c1-12-science-superstition-belief',
    ),
  ],
  'C1': [
    TopicChoice(
      name: 'Does language shape thought?',
      label: 'Language',
      icon: 'c2-01-language-shape-thought',
    ),
    TopicChoice(
      name: 'Justice, fairness, and what we owe each other',
      label: 'Justice',
      icon: 'c2-02-justice-fairness',
    ),
    TopicChoice(
      name: 'How do we know what we know?',
      label: 'Knowledge',
      icon: 'c2-03-how-do-we-know',
    ),
    TopicChoice(
      name: 'What makes us human in an age of machines?',
      label: 'Humanity',
      icon: 'c2-04-what-makes-us-human',
    ),
    TopicChoice(
      name: 'Power, privilege, and who gets to tell the story',
      label: 'Power',
      icon: 'c2-05-power-privilege-storytelling',
    ),
    TopicChoice(
      name: 'The future of democracy',
      label: 'Democracy',
      icon: 'c2-06-future-of-democracy',
    ),
    TopicChoice(
      name: 'The ethics of genetic technology',
      label: 'Gene ethics',
      icon: 'c2-07-ethics-genetic-technology',
    ),
    TopicChoice(
      name: 'What is art for?',
      label: 'Art',
      icon: 'c2-08-what-is-art-for',
    ),
    TopicChoice(
      name: 'The self — fixed or fluid?',
      label: 'The self',
      icon: 'c2-09-self-fixed-or-fluid',
    ),
    TopicChoice(
      name: 'The limits of globalisation',
      label: 'Globalisation',
      icon: 'c2-10-limits-of-globalisation',
    ),
    TopicChoice(
      name: 'Freedom — how much is too much?',
      label: 'Freedom',
      icon: 'c2-11-freedom-how-much',
    ),
    TopicChoice(
      name: 'What do we owe future generations?',
      label: 'Generations',
      icon: 'c2-12-what-do-we-owe-future',
    ),
  ],
};

List<TopicChoice> topicPreviewTopicsForLevel(String level) =>
    topicPreviewCatalog[level.trim().toUpperCase()] ??
    topicPreviewCatalog['A0']!;
