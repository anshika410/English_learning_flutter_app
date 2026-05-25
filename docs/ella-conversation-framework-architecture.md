Ella — Conversation Framework Architecture


OVERVIEW

This document covers the database design, storage strategy, and client/server split for the Ella conversation framework — the system that drives what Zoe talks about, how she coaches, and how student progress is tracked.


WHAT THE FRAMEWORK IS

The Ella Framework is a structured CEFR-aligned conversation curriculum with 6 levels (A1 to C2). For each level it defines:

I can statements — what the student should be able to do (Vocabulary, Grammar, Fluency)
Topics — conversation topics Zoe picks from, with starters and pedagogical context
Transitions — 5-step bridges between levels that guide Zoe on when and how to push a student forward

The framework drives every conversation Zoe has. It is not just assessment — it is the curriculum.


HOW ZOE USES THE FRAMEWORK AT RUNTIME

1. Load user — get current level from server
2. Pick topic — select from framework topics for this level, exclude topics already done
3. Get coaching context — load I can statements for this level, know which ones are already mastered
4. During conversation — detect when student demonstrates a statement, send celebration signal to client, record mastery on server
5. After session — check if enough statements mastered, if yes move user into transition steps
6. Transition — 5 steps, each with its own I can statements, when all 5 complete advance to next level


DATABASE DESIGN

Static Framework Tables (seed data, never changes)

framework_levels
  id — A1, A2, B1, B2, C1, C2
  headline — e.g. "I can talk about myself and things around me."
  order_index — 1 to 6

framework_categories
  id
  level_id — links to framework_levels
  name — vocabulary, grammar, or fluency
  cefr_context — full CEFR context paragraph for this category
  order_index

framework_statements (I can statements)
  id
  category_id — links to framework_categories
  level_id — denormalized for fast query
  statement — e.g. "I can say my name, age, and where I'm from."
  order_index

framework_transitions
  id
  from_level_id — e.g. A1
  to_level_id — e.g. A2
  overview — transition overview paragraph
  transition_context — e.g. "Shift: labelling to describing..."
  order_index — 1 to 5

framework_transition_steps
  id
  transition_id — links to framework_transitions
  step_number — 1 to 5
  step_name — e.g. "Describing the world"
  focus — e.g. "Moving from naming things to describing them."
  combined_context — full step context paragraph for Zoe's prompt

framework_transition_statements
  id
  step_id — links to framework_transition_steps
  category — vocabulary, grammar, or fluency
  statement
  order_index

framework_topics
  id
  level_id — links to framework_levels
  topic_number — 1 to 12
  theme — e.g. Self, Daily life, Society
  title — e.g. "My name and where I'm from"
  description
  why_it_works
  order_index

framework_topic_starters
  id
  topic_id — links to framework_topics
  starter — e.g. "What is your name?"
  order_index — 1 to 3


User Progress Tables (grows with usage)

user_framework_progress (one row per user)
  id
  user_id — links to users
  current_level_id — links to framework_levels
  in_transition — true or false
  transition_id — which transition they are in (nullable)
  transition_step — which of the 5 steps (nullable)
  updated_at

user_statement_progress (which I can statements demonstrated)
  id
  user_id
  statement_id — links to framework_statements
  demonstrated_at
  conversation_id — which session it was shown in

user_topic_history (which topics done at which level)
  id
  user_id
  topic_id — links to framework_topics
  conversation_id
  completed
  created_at


CLIENT VS SERVER STORAGE SPLIT

The Rule
Client handles the moment. Server handles the memory.

What lives on the server:
  I can statement mastery — needed across devices, sessions, and by Zoe in future conversations
  Topic history — Zoe must not repeat topics, needs to know what has been done
  Current level and transition state — drives all of Zoe's behaviour, must be consistent
  Conversation messages — analytics, transcript viewer, admin dashboard
  Placement results — permanent record of assessment

What lives on the client:
  Auth token — needed for every API call
  Current level and name — offline display only, cached copy
  Focus settings (grammar, vocab, fluency) — user preference, low stakes
  Celebration animation state — ephemeral UI moment, no need to persist

Why not client for progress:
  Device switch — user gets a new phone, all progress gone
  Reinstall — app cleared, progress gone
  Zoe needs it — cannot personalise future sessions without server-side history
  Admin dashboard — cannot show mastery data if it is on the device
  Transition logic — level advancement must be server-authoritative


STORAGE SIZE ESTIMATES

Static framework data (seed, one-time): approximately 500 KB, negligible

Per user per year (realistic usage: 20 minutes per day):
  Conversations: 3.6 KB
  Messages (turns): 54 KB
  Statement progress: 3.6 KB
  Topic history: 1.8 KB
  Total per user per year: approximately 63 KB

At scale:
  1,000 users — 63 MB per year
  10,000 users — 630 MB per year
  1,00,000 users — 6.3 GB per year
  1,00,00,000 users (1 crore) — 630 GB per year

A single PostgreSQL instance handles up to approximately 1 lakh active users comfortably. Beyond that, add read replicas and archive old messages to cold storage.


NEXT STEPS

1. Seed the framework data — write a migration that populates all static tables from the Excel framework
2. Add progress endpoints — POST /progress/statement-demonstrated and GET /progress/summary
3. Wire Zoe's prompt — inject relevant I can statements and topic context into the LLM system prompt
4. Celebration trigger — backend returns statements_demonstrated in conversation turn response, client shows animation
5. Transition check — after each session, backend checks mastery count and updates user_framework_progress
