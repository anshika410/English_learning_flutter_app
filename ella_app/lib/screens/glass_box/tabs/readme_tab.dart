// Glass Box → Read me tab
// Port of the simulator's ReadmeView. Read-first orientation for new viewers.

import 'package:flutter/material.dart';

class ReadMeTab extends StatelessWidget {
  const ReadMeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'ELLA Loop Simulator — read me first',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F1B16),
          ),
        ),
        SizedBox(height: 8),
        _Para(
          'This is a glass box. The Zoe tab is what a learner sees. The Glass Box '
          'tab exposes everything normally hidden — prompts, scoring, memory, progression. '
          'The point is to watch the learning loop work and decide if it\'s right.',
        ),
        _H('The loop, in one breath'),
        _Para(
          'A learner talks to Zoe → after the chat a judge scores which skills were shown → '
          'deterministic code updates the memory object → that decides what the next chat aims at. '
          'Round and round. LLMs produce signals (Zoe talks, judge scores); plain code makes the decisions '
          '(what\'s owned, what\'s next). An LLM never decides state.',
        ),
        _H('How to drive it'),
        _Bullet(
          '1. Pick a mode in the Zoe tab\'s top right: micro-skill or units.',
        ),
        _Bullet(
          '2. Tap 🤖 auto, then Next turn — a simulated learner talks to Zoe.',
        ),
        _Bullet(
          '3. Tap End ⚖️ to score the chat. Watch the Memory / Judge / Both tabs update.',
        ),
        _Bullet(
          '4. Tap Next → to start the next chat. Repeat 5–10 times to see the arc.',
        ),
        _Bullet(
          '5. Voice input works too — switch to Voice in the input dock.',
        ),
        _H('What each Glass Box tab shows'),
        _Bullet(
          '🧠 Memory — the learner\'s full state, live. Changed fields are highlighted.',
        ),
        _Bullet(
          '⚖️ Judge — raw per-skill scores from the last chat with evidence quotes.',
        ),
        _Bullet(
          '⚖️⚖️ Both — same transcript scored under BOTH framings side by side.',
        ),
        _Bullet('📜 Session — the immutable per-chat record (accumulates).'),
        _Bullet('🎯 due_next — what the next chat will aim at, and why.'),
        _Bullet('📝 Prompt — the exact prompt Zoe is running right now.'),
        _Bullet(
          '✏️ Prompts — edit any prompt live; the next chat uses your edits.',
        ),
        _Bullet('🌱 Skills / 🪜 Units — the curriculum and what\'s owned.'),
        _Bullet('📊 History — one row per chat: aimed vs hit.'),
        _Bullet('⚙️ LLM — provider info (Android uses the Supabase proxy).'),
        _H('How a skill becomes "owned"'),
        _Para(
          'Three states: locked → emerging → owned. A skill enters emerging on first real evidence. '
          'It becomes owned when shown well enough, enough times: the OWN_BAR scales with level '
          '(A1=0.55, B1=0.68…); a skill needs ≥2 qualifying sightings; A1/A2 also have an effort path '
          'where 3 honest attempts can own a skill even without a peak score. No demotion (decay deferred).',
        ),
        _H('Units mode — communicate-to-advance'),
        _Para(
          'A unit completes when fluency + vocabulary skills are owned AND grammar is at least emerging. '
          'Grammar is allowed to keep maturing in later units. This stops a beginner being walled by '
          'one hard grammar skill, and keeps the gate aligned with "reward effort."',
        ),
        _H('What to look at to judge if it works'),
        _Bullet(
          'Does Zoe actually steer to the primary skill in due_next? Compare against the chat.',
        ),
        _Bullet(
          'aimed vs hit — of the skills we aimed at, how many actually showed up?',
        ),
        _Bullet('Do the judge confidences match what the learner really did?'),
        _Bullet(
          'Does memory evolve believably across chats? Watch snapshots in the Memory tab.',
        ),
        SizedBox(height: 16),
        Text(
          'Honest limits: this proves the loop and the prompts. STT/TTS quality and pedagogical claims '
          'are not what this is testing. Treat behaviour as directional.',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF7A5A13),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFFB8472F),
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Color(0xFF3A352E),
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4, left: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.45,
        color: Color(0xFF3A352E),
      ),
    ),
  );
}
