# zoSpeak garden card copy audit

## Scope

Reviewed the supplied v0.0.5 garden experience with the app's local preview
fixtures. The preview used a fictional learner named Maya and local garden
data; it did not require a learner login or learner records.

The review covers:

1. Opening the garden.
2. Seeing a plant grow after a chat.
3. Tapping a plant.
4. Tapping a garden section.
5. Tapping a goal inside the garden-section card.

`Preview` and `Preview conversation` in the screenshots are fixture text, not
recommended production copy.

## Overall verdict

The garden metaphor is clear and appealing, but the cards explain the learning
model too literally. Words such as **skill**, **session**, **mastery**,
**Vocabulary**, and **Grammar** make the child translate the curriculum before
they can understand what happened.

Keep those terms in code, analytics, APIs, and educator tools. Remove them from
the learner-facing layer. The child usually needs only:

- what grew;
- what they can now do;
- something good they said;
- what to do next.

## Step 1 — Open the garden

![Garden overview](screenshots/01-garden.png)

**Health: Good.** The garden itself communicates progress without explanation.
Large plants, small sprouts, and named areas make the model visible.

The stone labels are long, however, and read like lesson titles. Prefer shorter
names such as `Better Words`, `Short Stories`, and `Good Questions`.

## Step 2 — A plant grows

![Growth reveal](screenshots/06-growth-reveal.png)

**Health: Needs simplification.** The spotlight, animation, mascot, and large
button make the event feel rewarding. The card then repeats the model in four
ways: “skill,” the goal name, Seed → Sprout, and the evidence heading.

### Recommended copy

| Current | Recommended |
|---|---|
| A new skill is sprouting | **Look—it grew!** |
| Use a more precise word | **Choose a stronger word** |
| Seed → Sprout | Keep only if stage names matter; use **Seed → Sprout** |
| What You Said | **You said** |
| Explore Garden | **See my garden** |

For later stages:

- `This skill just grew stronger` → **It grew again!**
- `This skill is in full bloom!` → **It’s blooming!**
- `You practiced this skill with Zoe` → **You practiced this with Zoe**

## Step 3 — Tap a plant

![Long plant card](screenshots/02-skill-card.png)

**Health: Too dense.** The first line is useful: `Describe a place clearly`.
Most of the remaining height is curriculum labelling and repeated history.
Three evidence cards make this feel like a report rather than a reward.

### Recommended structure

1. Short area name: **Better Words**
2. Goal: **Describe a place clearly**
3. Optional garden state: **In bloom**
4. One best or most recent quote under **You said**
5. A collapsed link: **See 2 more**

### Recommended copy

| Current | Recommended |
|---|---|
| Finding Better Words | **Better Words** |
| Vocabulary | Hide; if essential, use **Words** |
| Bloomed | **In bloom** |
| What You Said | **You said** |
| Talking about … • 16 days ago | Show only **16 days ago**, or omit for children |
| Talk with Zoe to start growing this skill | **Talk with Zoe to help this grow** |

Add a visible close button. At present, dismissal depends on tapping outside the
card or using Back, which is not obvious to every child.

## Step 4 — Tap a garden section

![Garden-section card](screenshots/03-unit-card.png)

**Health: Understandable list, adult wording.** The rows and icons are easy to
scan, but `On Mastery, You Will Be Able To` is formal, abstract, and longer than
the content it introduces.

### Recommended copy

| Current | Recommended |
|---|---|
| Finding Better Words | **Better Words** |
| Long section description | One short line: **Practice choosing clearer words.** |
| On Mastery, You Will Be Able To | **You’re practicing** |
| Use a more precise word | **Choose a stronger word** |
| Use simple past tense | **Talk about something that happened** |
| Vocabulary | Hide; or **Words** |
| Grammar | Hide; or **Sentences** |
| Fluency | Hide; or **Speaking** |
| Show more | **Show all 4** |

The word `unit` does not need to appear at all. Internally it can remain a unit;
to the learner it is simply one named part of their garden.

## Step 5 — Tap a goal inside the section

![Section goal opens the plant card](screenshots/07-unit-to-skill.png)

**Health: Functionally clear, structurally repetitive.** Tapping a row closes
the section card and opens the same plant-detail card. This is predictable, but
the destination repeats the section name, goal, category, stage, heading, quote,
topic, and date.

Keep the transition, but use the shorter plant-card structure from Step 3.

## Learner-facing language system

| Internal term | Learner-facing language |
|---|---|
| session | **chat** or **talk** |
| skill | Usually remove the noun; show the action, such as **Tell a short story** |
| unit | Do not label; optionally **garden patch** if a noun is required |
| mastery | Remove; use **You’re practicing** or **When these bloom** |
| evidence | **You said** |
| strand | Hide; optionally **Words**, **Sentences**, **Speaking** |
| seed / sprout / budding / bloomed | **Seed / Sprout / Bud / Bloom** |

On the home screen, `Next Session` should become **Next chat** or disappear.
The CTA can simply be **Talk about me**, avoiding `Let’s Talk About About me`.

## Strengths

- The garden itself explains growth visually.
- Growth is celebrated with a clear spotlight and a large next action.
- Goal names are mostly short, concrete, and verb-led.
- Plant and section tap targets are visually generous.

## UX and accessibility risks

- Long cards create high reading load, especially for younger readers and
  people using larger text.
- Curriculum labels compete with the goal and quote instead of helping the
  learner act.
- Repeated topic and date metadata makes evidence harder to scan.
- The detail dialogs have no visible close control.
- Major text looks strong in the screenshots, but muted brown metadata and
  borders still need measured contrast checks.
- Screenshots cannot confirm screen-reader labels, focus order, switch access,
  animation reduction, or large-text reflow.

## Priority

1. Remove `skill`, `session`, and `mastery` from learner-facing copy.
2. Reduce the plant card to one quote, with older quotes collapsed.
3. Hide curriculum strands or rename them in plain language.
4. Shorten section names and descriptions.
5. Add a visible close button to both detail cards.
