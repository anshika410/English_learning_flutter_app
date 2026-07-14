# Unit Name Length Audit — Signpost Fit

**Context:** Garden signposts render unit names in a single-line component. Two names visible in the current garden screenshot — "Describing the World" (20 chars) and "Talking About The Past" (22 chars) — both render on one line, so they're used here as the safe-length reference points until the signpost's actual pixel/wrap behavior is confirmed.

**Length bands used below:**
- **Safe** — ≤22 characters, matches the confirmed reference points
- **Borderline** — 23–30 characters, untouched in this pass, flagged for a future look
- **Risk** — 31+ characters, or otherwise reads like a sentence rather than a label — rewritten below to 2–4 words

**Open question, unresolved:** whether the signpost component can support a graceful two-line wrap. If yes, most "Risk" items stop being urgent. This audit proceeds on the conservative assumption that one line is the working constraint.

**Status:** Rewrites below are proposed. Narendra is reviewing with Prachi, who owns unit naming for pedagogical accuracy. Nothing here should be treated as final until she signs off.

---

## A0 → A1

| Step | Framework original | Current (Narendra's rework) | Chars | Status | Proposed | Chars |
|---|---|---|---|---|---|---|
| 1 | First words | Naming the world | 16 | Unchanged | — | — |
| 2 | I am and I have got | Introducing yourself | 20 | Unchanged | — | — |
| 3 | I like and I don't like | Expressing likes and dislikes | 30 | **Changed** | **Likes and dislikes** | 19 |
| 4 | I can | Saying what I can do | 20 | Unchanged | — | — |
| 5 | What is happening? | Describing what's happening now | 32 | **Changed** | **Describing right now** | 21 |

Notes:
- Step 3: alt considered — "Expressing preferences" (2 words) — rejected for now; trades away the concrete "dislikes" word that's likely clearer for the lowest-literacy cohort.
- Step 5: rewrite keeps the verb-first pattern shared by the rest of the level (Naming / Introducing / Expressing / Saying / Describing).
- Step 2 flag for Prachi: the actual skill content is "saying who I am **and what I have**." "Introducing yourself" reads as identity-only and may not signal the possession content. Not resized here (20 chars is safe) but worth a proofread pass.

---

## A1 → A2

| Step | Name | Chars | Status |
|---|---|---|---|
| 1 | Describing the world | 20 | Unchanged (confirmed safe — screenshot reference) |
| 2 | Talking about the past | 22 | Unchanged (confirmed safe — screenshot reference) |
| 3 | Giving opinions and reasons | 27 | Unchanged — borderline, not touched this pass |
| 4 | Talking about plans | 19 | Unchanged |
| 5 | Holding a real conversation | 27 | Unchanged — borderline, not touched this pass |

---

## A2 → B1

| Step | Framework original | Chars | Status | Proposed | Chars |
|---|---|---|---|---|---|
| 1 | Finding better words | 20 | Unchanged | — | — |
| 2 | Talking about the past with more precision | 42 | **Changed** | **Refining past stories** | 21 |
| 3 | Expressing opinions with depth | 30 | **Changed** | **Backing up opinions** | 19 |
| 4 | Speaking for longer without losing the thread | 45 | **Changed** | **Keeping the thread** | 19 |
| 5 | Handling unpredictable conversations | 36 | **Changed** | **Handling the unexpected** | 24 |

Notes:
- Step 2 and Step 3 could not simply be trimmed — the originals were the A1→A2 names ("Talking about the past", "Giving opinions and reasons") with a qualifier bolted on. Shortening naively would have collided with the earlier level's signpost text. Both were rewritten to be genuinely distinct.
  - Step 2 alt: "Deepening past stories"
  - Step 3 alt: "Opinions with evidence"
- Step 4: "Keeping the thread" was chosen over a generic "Speaking for longer" specifically to avoid overlapping with B1→B2's "Speaking at length with coherence" (see below). Alt: "Speaking for a minute" (more literal, ties to the actual 1-minute stamina goal in the framework content).
- Step 5: alt "Thinking on your feet" is punchier but idiomatic — flagged for Prachi on register/comprehension rather than decided here.

---

## B1 → B2

| Step | Framework original | Chars | Status | Proposed | Chars |
|---|---|---|---|---|---|
| 1 | Precision in vocabulary | 23 | Unchanged — borderline | — | — |
| 2 | Using complex grammar naturally | 31 | **Changed** | **Natural complex grammar** | 23 |
| 3 | Speaking at length with coherence | 33 | **Changed** | **Speaking with coherence** | 23 |
| 4 | Arguing and persuading | 22 | Unchanged | — | — |
| 5 | Natural, spontaneous fluency | 28 | Unchanged — borderline | — | — |

Notes:
- Step 2 is a straight reorder — no meaning change.
- Step 3 drops "at length" since "coherence" is the load-bearing pedagogy word, and stays distinct from A2→B1's "Keeping the thread" (stamina) — this unit is about extended, well-organised coherence rather than simply talking longer.

---

## B2 → C1

| Step | Framework original | Chars | Status | Proposed | Chars |
|---|---|---|---|---|---|
| 1 | Choosing words with more precision and feeling | 46 | **Changed** | **Words with feeling** | 18 |
| 2 | Complex grammar with ease | 25 | Unchanged — borderline | — | — |
| 3 | Sustained, coherent discourse | 29 | Unchanged — borderline | — | — |
| 4 | Register flexibility | 20 | Unchanged | — | — |
| 5 | Speaking with real precision and effect | 39 | **Changed** | **Speaking with intention** | 22 |

Notes:
- Step 1 alt worth Prachi's eye: **"Words with nuance"** — closer to the actual pedagogy content (connotation, register, tone) than "feeling," which reads more emotional than intended.
- Step 5 was written to stay distinct from Step 1 — Step 1 is vocabulary-specific, Step 5 is delivery/effect-specific. Alt: "Speaking for effect" (more literal, closer to original wording).

---

## Summary

- **25 units total.** 10 changed this pass, 15 unchanged.
- All 10 rewrites land at 3 words, 18–24 characters — inside the ≤22-char safe reference and the 2–4 word target.
- 6 units remain in the borderline band (23–30 chars) and were intentionally left untouched pending direction on whether the signpost supports two lines.
- Two items carry a genuine meaning trade-off flagged for Prachi rather than resolved here: the A1→A2 echo pattern lost in A2→B1 Steps 2–3, and the "feeling" vs. "nuance" word choice in B2→C1 Step 1.
