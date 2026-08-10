# Ella / zoSpeak — App Overview

> Product summary based on the current `ella_app` implementation, August 2026.

## What the app is

Ella, currently presented in the app as **zoSpeak**, is a conversation-based English learning app. The learner practises with an AI speaking companion named **Zoe** in short, low-pressure conversations.

The app is designed around learning by speaking rather than completing conventional lessons or quizzes. Zoe listens, responds aloud, adapts practice to the learner's level, and uses the learner's own conversation as evidence of progress.

The core loop is:

**Choose a topic → talk with Zoe → demonstrate English skills → grow the learning garden → return for the next conversation**

## Main features

### 1. Account access and learner profile

- Sign in with Google or a password-free email magic link.
- Create a learner profile by sharing a name and age.
- Edit the profile, control app sounds, sign out, or delete the account.
- Profile and learning data are connected to the learner's account so progress can persist across sessions.

### 2. Conversational placement

- New learners complete a short conversation with Zoe before entering the main experience.
- They can answer by speaking or typing.
- Zoe uses the conversation to assign an appropriate CEFR learning level.
- If the learner ends placement too early for a level to be assigned, the app keeps their first sprout and encourages them to try again.

### 3. Personalised conversation topics

- The home screen shows Zoe's recommended topic and alternative topics suitable for the learner's current level.
- The learner can browse the available topics and choose what they would like to discuss.
- Recently used topics are remembered so recommendations stay varied.
- A short recap from the previous conversation helps the learner reconnect before starting again.

### 4. Voice-first practice with a text fallback

- Zoe opens the conversation, speaks her replies aloud, and highlights words as they are spoken.
- The learner taps the microphone and answers naturally; live speech recognition shows what the app is hearing.
- The learner can interrupt Zoe, replay her latest line, or switch to typing when speaking is not practical.
- Only the latest exchange is shown, keeping the screen focused and reducing the feeling of a formal transcript or test.
- The learner can end a conversation at any time and is given a friendly exit flow.

### 5. A visual learning garden

- The garden turns curriculum progress into plants.
- Each garden represents a CEFR level, from **A0 to C1**, and each level contains five learning units.
- Each plant represents a specific vocabulary, grammar, or fluency skill.
- A bare plot becomes a seedling, then a young plant, and finally a bloom as the learner demonstrates the skill repeatedly.
- Learners can tap units and plants to inspect what a skill means and review examples from their own conversations.
- Completed earlier gardens remain available to revisit, while the next garden is shown as locked until the learner progresses.

### 6. Post-conversation progress feedback

- After a conversation, Zoe says goodbye and the learner returns to the garden while the session is assessed.
- A watering animation and growth reveal show which skill was practised or advanced.
- The reveal can show the exact sentence the learner used as evidence.
- Even when a short conversation does not grow a plant, the app acknowledges the practice without inventing progress.

### 7. Child-friendly and accessible interaction

- Zoe's mascot changes between listening, thinking, speaking, resting, and offline states.
- Spoken prompts have replay controls.
- Important actions use large touch targets, clear labels, and consistent visual cues.
- Reduced-motion device settings are respected.
- The app handles weak or missing connectivity with dedicated offline and retry states.

## What a learner can do

A learner can:

- sign in and manage their account;
- tell Zoe their name and age;
- complete a spoken English placement conversation;
- choose a level-appropriate topic;
- practise an open-ended conversation using voice;
- use typing as a fallback;
- listen to Zoe's replies and replay them;
- stop or leave a conversation when needed;
- see a recap of the previous session;
- view their current level, units, and skill plants;
- inspect the skill connected to each plant;
- review their own sentences as evidence of learning;
- watch plants grow after successful practice;
- revisit gardens from completed levels; and
- edit their profile, sound settings, or account.

## How learning works

### Placement establishes the starting point

The first conversation is an adaptive screening rather than a multiple-choice test. Zoe considers the learner's responses and places them at a suitable CEFR level. This determines the curriculum, topics, and garden the learner sees first.

### The curriculum defines practical speaking abilities

The curriculum runs from A0 to C1. Each level contains five units built around practical **“I can”** outcomes, divided into three strands:

- **Vocabulary:** the words and expressions the learner can use.
- **Grammar:** the structures the learner can use meaningfully.
- **Fluency:** how independently, clearly, and continuously the learner can communicate.

These outcomes progress from naming familiar things and producing short phrases to explaining ideas, telling stories, expressing opinions, adapting language, and speaking with greater precision.

### Topics provide the context; skills provide the learning goal

The learner chooses a topic because it is interesting and conversational. Behind the scenes, the app also selects a primary skill to practise and watches for other relevant skills the learner may use spontaneously. Zoe's questions create opportunities to demonstrate these abilities without turning the conversation into a visible drill.

### The learner improves through repeated, meaningful use

At the end of a session, the conversation is assessed against the targeted curriculum skills. A use counts only when the assessment is sufficiently confident. Progress is deliberately cumulative:

| Confident demonstrations | Learning state | Garden state |
|---:|---|---|
| 0 | Not yet demonstrated | Bare plot |
| 1 | Emerging | Seedling |
| 2 | Developing | Young plant |
| 3 or more | Owned | Bloom |

This means one successful sentence begins progress, but repeated use across conversations is needed to establish a skill.

### The learner's own words become evidence

When a skill is demonstrated, the app can store a short quote from the learner, along with the conversation topic and date. The garden then shows both the abstract skill and concrete evidence such as a sentence the learner actually said. This makes progress visible and personal.

### Memory personalises the next practice

The app remembers the learner's level, recent topics, demonstrated and emerging skills, practice count, and previous-session recap. It uses this memory to choose future targets and suggest fresh topics, so each conversation continues the learning journey instead of starting from zero.

## Typical learner journey

1. **Sign in** with Google or email.
2. **Meet Zoe** and provide a name and age.
3. **See the first plant** and begin placement.
4. **Talk with Zoe** until a level is assigned.
5. **Enter the level garden** and see the starting learning path.
6. **Choose a recommended or alternative topic.**
7. **Have a voice conversation**, with typing available when needed.
8. **End the session** and wait briefly while it is assessed.
9. **See the garden response**: watering, a skill-growth reveal, and evidence from the conversation.
10. **Return home** for a recap and the next suggested conversation.

## Current product boundaries

- The main learning loop requires an internet connection because conversations, assessment, memory, and garden progress use the Ella backend.
- Some cached profile and home information can still be shown offline, but offline conversations do not create verified skill progress.
- The primary learner experience is conversation and garden growth; it is not a course made of videos, reading lessons, worksheets, or traditional quizzes.
- Typing is available for access and convenience, but speaking remains the intended practice mode.

