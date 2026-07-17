# Ella Prompt Architecture

## Design principle

Ella's live conversation prompt is assembled from three independent layers:

1. **Base** — invariant identity, safety, truth, meaning-first interaction, and repair behavior.
2. **Level** — turn length, language complexity, question types, scaffolding depth, and correction policy.
3. **Unit** — the current communicative goal, target skills, learner memory, elicitation plan, turn number, and closing.

The layers have an explicit priority:

`safety → learner meaning/truth → natural conversation → unit target → language polish`

This prevents a generic teaching habit from overriding the needs of a particular level. For example, the base prompt cannot force an A0 learner to repeat a recast, because the A0 profile defines modelling as last-resort support.

## Live conversation assembly

```text
conversation-prompt.md
├── {{BASE_BLOCK}}  ← base-prompt.md
├── {{LEVEL_BLOCK}} ← profile-A0.md ... profile-C1.md
└── {{UNIT_BLOCK}}  ← rendered conv-unit-framing.md
    ├── unit name and focus
    ├── target skill IDs and statements
    ├── level-aware elicitation plan
    ├── student memory
    └── current turn
```

Assembly happens in `app/services/llm_service.py → send_conversation_turn()`.

The conversation shell contains only hierarchy and output rules. It does not duplicate the base or unit content.

## Prompt files

### `base-prompt.md`

Single source of truth for all conversation invariants:

- respond to meaning before form
- preserve truth and learner intent
- ask at most one question
- never re-ask answered information
- use the least support needed
- check uncertain speech instead of guessing
- understand code-switching without penalising it
- child safety and privacy

The base prompt deliberately does not define a universal correction or question strategy. Those belong to the level profiles.

### `profile-A0.md` through `profile-C1.md`

Each profile controls:

- Zoe's interaction role
- output length
- vocabulary and question complexity
- expected learner output
- scaffolding depth
- correction behavior
- how to increase challenge

Current roles:

| Level | Role | Core move |
|---|---|---|
| A0 | Meaning-Maker | Elicit truthful independent words and first sentences |
| A1 | Carrier | Sustain a simple exchange and invite one detail |
| A2 | Bridge-Builder | Connect short sentences into conversation |
| B1 | Space-Creator | Leave room for developed reasons and examples |
| B2 | Sparring Partner | Introduce positions, tensions, and trade-offs |
| C1 | Peer | Explore nuance, framing, and implications |

### `conv-unit-framing.md`

Controls the session-level teaching behavior:

- one primary target; later targets are watch-only
- one clear independent opportunity; at most one differently worded second opportunity when evidence is unclear
- no repeated wording after an answer
- learner language, not Zoe's model, is the evidence
- coherent topic threads
- memory use without invented assumptions
- turn-6 closing contract

### `conversation-prompt.md`

Thin runtime shell. It inserts the base, level, and rendered unit blocks and defines the spoken-output contract.

### `starter-prompt.md`

Generates the first line for a topic-based session. It receives both the base
prompt and active level profile, so safety, privacy, truth, and A0 elicitation
rules apply from the first spoken line.

Used by `generate_conversation_starter()`.

### `placement-check-prompt.md`

Standalone adaptive placement conversation:

- receives `base-prompt.md`, so the same safety, privacy, truth, and AI-identity rules apply
- six levels, A0 through C1
- minimum five and maximum nine learner turns
- concrete-to-complex adaptive probing
- meaning-first support ladder
- no correction or forced imitation
- accent and code-switching are not proficiency scores
- output includes level, confidence, evidence, interests, and next-session guidance

### `end-result-prompt.md`

Standalone post-session analysis and skill grader:

- receives the exact target-skill list
- records support as `spontaneous`, `open_question`, `choice`, `frame`, or `model`
- allows one-word A0 best moments
- caps imitation as partial A0 evidence unless independently adapted
- extracts only explicit, stable, non-sensitive memory facts
- returns one transcript note for every learner turn

Runtime validation rejects fabricated best-moment and score-evidence quotes,
and rebuilds transcript notes from the real learner turns.

### `correction-extraction-prompt.md`

Standalone focused correction selector. It returns `null` when:

- speech may be misrecognised
- the issue is accent, code-switching, or accepted Indian English
- the only differences are minor
- A0 language was copied from Zoe

Used by `extract_correction_highlight()`.

### `zoe-judge-prompt.md`

Simulator and QA audit prompt. It evaluates Zoe on:

- the injected base rules and active level profile
- meaning-first response
- truth and memory accuracy
- independent elicitation
- support fit
- question count
- forward conversational flow
- natural target steering
- level fit
- repair accuracy
- correction fit
- warmth without repetitive praise
- safety and privacy

## Elicitation planning

The sole elicitation planner lives in `app/core/elicitation.py`.

It derives a communicative function from the actual target skill text. It does **not** infer the function from unit step number because step numbers mean different things at different levels.

Examples:

- A0 Step 2 → self-introduction, `I am`, and possession
- A1 Step 2 → past events
- B1 Step 2 → hedging, conditionals, and reported speech

The old step-number mapper has been removed. It incorrectly treated every Step
2 as past tense, every Step 4 as future, and every Step 5 as sequencing.

Each generated plan contains:

- target skill text
- natural communicative move
- possible prompt
- fallback support
- definition of learner evidence

Unit IDs repeat across levels, so the planner resolves every unit skill with
both its ID and active level. Unknown or level-mismatched targets are discarded
instead of leaking a raw ID or another level's skill into the prompt.

Progress storage scopes repeated unit IDs internally, for example
`A0:U2-GRA-01`, while prompts and APIs continue to use the public ID
`U2-GRA-01`. Persisted `due_next` data also carries its level and is rejected
when stale or ambiguous.

## Runtime flow

```text
New session
└── starter-prompt.md
    ├── base-prompt.md
    └── active level profile

Each conversation turn
└── conversation-prompt.md
    ├── base-prompt.md
    ├── profile-{level}.md
    └── conv-unit-framing.md
        └── elicitation.py plan

Placement
└── placement-check-prompt.md
    └── base-prompt.md

Session completion
├── end-result-prompt.md
└── correction-extraction-prompt.md

QA sample
└── zoe-judge-prompt.md
    ├── base-prompt.md
    └── active level profile
```

## Source-of-truth and mirrors

Canonical prompt source:

`backend/app/prompts/`

The Flutter/simulator asset mirror is:

`frontend/assets/prompts/`

The two directories must remain byte-for-byte synchronized for files used by both environments.

The Flutter direct-LLM fallback assembles the same base + level + unit stack
from this mirror. Backend and direct fallbacks also enforce completion from
turn 6 even if the model omits the completion signal.
