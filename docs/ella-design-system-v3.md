# Ella Design System — v3.0
**Vivid Gouache · NavGurukul · Voice-first English Learning · Android-first**
*Compiled April 2026 — share with engineers and contributors*

---

## Design DNA

Ella v3.0 is a full replacement of the earlier chalked/muted v2.1 palette. The direction is **Vivid Gouache** — the energy of Indian festival colours rendered through the rounded, friendly geometry of a children's storybook. Vibrancy is a functional decision, not merely aesthetic: budget Android screens under outdoor ambient light wash out muted tones. Full-saturation colours survive that environment. Rounded geometry signals safety and approachability to the 10–18 age range.

**Five principles that govern every decision:**

1. **Voice-first, screen-secondary.** The mic button is always the dominant element. No screen should require more than two taps to reach the mic.
2. **Bilingual always.** Every scaffold chip, Ella annotation, and key instruction must have a Hindi equivalent. Baloo 2 must always be present in the font stack.
3. **Colour carries meaning.** Orange = action/speaking. Blue = academics/Ella. Lime = reward/growth. Rose = interests/energy. Grape = rare/bonus moments. Never break this mapping.
4. **Brand colours are not system colours.** Rose ≠ Error. Lime ≠ Warning. Grape is never used for feedback states.
5. **Stamp shadow = tactile.** The hard offset shadow on buttons makes them feel pressable. It is the single signature interaction mechanic — maintain it consistently.

---

## 1. Colour Tokens

Five brand families + neutral + three semantic families. Each brand family has six named stops. Token names are semantic, not numeric — they describe role, not position.

### Stop Naming Convention

| Stop name | Role | Typical usage |
|---|---|---|
| `lightest` | Very light fill | Screen backgrounds, hover fills, toast backgrounds |
| `light` | Light fill | Chip backgrounds, bubble fills, subtle accents |
| `main` | Primary | Buttons, card fills, badges, active icons |
| `dark` | Deep shade | Pressed states, borders on coloured fills, shadow complement |
| `deepest` | Darkest | Body text on light fills, dark-mode fills |
| `on-main` | Foreground on main | Legible text/icon colour placed directly on `main` |

---

### Mango — CTAs · Mic · Speaking · User speech bubbles

| Stop | Token | Hex |
|---|---|---|
| Lightest | `mango-lightest` | `#FFF3E0` |
| Light | `mango-light` | `#FFD699` |
| Main | `mango-main` | `#FF9500` |
| Dark | `mango-dark` | `#C87000` |
| Deepest | `mango-deepest` | `#7A4400` |
| On main | `mango-on-main` | `#FFFFFF` |

Mango is the primary action colour. It owns the primary CTA button, the mic button, and all user-generated speech output surfaces. Whenever a student is speaking or about to speak, the UI shifts toward Mango.

---

### Sky — Ella's voice · Academics · Trust · Conversation context

| Stop | Token | Hex |
|---|---|---|
| Lightest | `sky-lightest` | `#E8F4FF` |
| Light | `sky-light` | `#B8DCFF` |
| Main | `sky-main` | `#3B9EFF` |
| Dark | `sky-dark` | `#1A6CC8` |
| Deepest | `sky-deepest` | `#0A3870` |
| On main | `sky-on-main` | `#FFFFFF` |

Sky is Ella's colour. Ella's speech bubbles, the conversation screen background, academic content cards, and trust signals all use Sky. When the app is "listening" or "thinking", the context remains Sky.

---

### Lime — Rewards · Growth · Streaks · Completion · Progress

| Stop | Token | Hex |
|---|---|---|
| Lightest | `lime-lightest` | `#F0FBE8` |
| Light | `lime-light` | `#C4F08A` |
| Main | `lime-main` | `#72CC14` |
| Dark | `lime-dark` | `#4E9A00` |
| Deepest | `lime-deepest` | `#2A5800` |
| On main | `lime-on-main` | `#FFFFFF` |

Lime signals positive progress. Progress bars, streak counts, level-up moments, and completion badges live in Lime. Do not use Lime for warning or system feedback — it will be confused with the success semantic colour.

---

### Rose — Interests · Energy · Celebration · Topic selection

| Stop | Token | Hex |
|---|---|---|
| Lightest | `rose-lightest` | `#FFF0F3` |
| Light | `rose-light` | `#FFB8C8` |
| Main | `rose-main` | `#FF4878` |
| Dark | `rose-dark` | `#C82050` |
| Deepest | `rose-deepest` | `#780030` |
| On main | `rose-on-main` | `#FFFFFF` |

Rose belongs to interests, topics, and celebratory energy. The topic selection screen and interest-path cards use Rose. Do not use Rose for error states — its hue is close but its semantic role is entirely different.

---

### Grape — Rare rewards · Bonus moments · Premium milestones

| Stop | Token | Hex |
|---|---|---|
| Lightest | `grape-lightest` | `#F5F0FF` |
| Light | `grape-light` | `#D4BFFF` |
| Main | `grape-main` | `#8B5CF6` |
| Dark | `grape-dark` | `#6030C8` |
| Deepest | `grape-deepest` | `#320078` |
| On main | `grape-on-main` | `#FFFFFF` |

Grape is reserved for rare and special moments — a first challenge completed, an unexpected streak, a bonus reward. Its scarcity is its power. Overuse destroys the signal. Never use Grape for navigation elements or everyday UI.

---

### Neutral — Backgrounds · Text · Borders · Structural surfaces

| Stop | Token | Hex | Usage |
|---|---|---|---|
| Background | `neutral-bg` | `#FFFDF8` | App default background (warm off-white) |
| Surface | `neutral-surface` | `#FFF7EC` | Card surfaces, elevated panels, input fills |
| Border | `neutral-border` | `#F0E4CC` | Dividers, subtle card strokes, inactive borders |
| Muted | `neutral-muted` | `#C0A880` | Placeholder text, metadata, disabled labels |
| Secondary | `neutral-secondary` | `#6B5740` | Secondary body text, captions, supporting copy |
| Primary | `neutral-primary` | `#2C1E0F` | Primary body text — all readable content |

Neutral-primary is a warm dark brown, not pure black. This is intentional — it is easier on the eye and warmer in tone for the age group.

---

### Semantic: Success

| Stop | Token | Hex |
|---|---|---|
| Lightest | `success-lightest` | `#F0FBE8` |
| Light | `success-light` | `#C4F08A` |
| Main | `success-main` | `#72CC14` |
| Deep | `success-deep` | `#2A5800` |

Success maps directly to the Lime family in hue but is semantically distinct. Use Success only for system feedback — correct answers, successful submissions, task completions. Do not use Lime-main in place of success-main for feedback states.

---

### Semantic: Error

| Stop | Token | Hex |
|---|---|---|
| Lightest | `error-lightest` | `#FFF0F3` |
| Light | `error-light` | `#FFB8C8` |
| Main | `error-main` | `#E0103C` |
| Deep | `error-deep` | `#780020` |

Error-main is a vivid red distinct from Rose-main. If a student's speech is unrecognised or a network call fails, use Error. Never use Rose-main for error states.

---

### Semantic: Warning

| Stop | Token | Hex |
|---|---|---|
| Lightest | `warning-lightest` | `#FFF8E0` |
| Light | `warning-light` | `#FFE080` |
| Main | `warning-main` | `#FFAA00` |
| Deep | `warning-deep` | `#7A5000` |

Warning is for time limits, content moderation flags, and caution states. It is distinct from Mango — Mango is brand/action, Warning is system/alert.

---

### Special Tokens

| Token | Hex | Usage |
|---|---|---|
| `ink` | `#1A1220` | **Reserved exclusively** for: primary CTA button border + shadow, and the avatar border ring. No other use permitted. |
| `bg-home` | `#FFFDF8` | Home screen background |
| `bg-conversation` | `#EFF7FF` | Conversation / lesson screen background |
| `bg-academics` | `#E8F4FF` | Academics path, chapter-list screens |
| `bg-summary` | `#F5FBE8` | Post-session summary screen |
| `bg-interests` | `#FFF0F3` | Topic selection / interests path screen |

The `ink` rule is strict. It is what makes the primary CTA visually dominant. If Ink appears on secondary elements, the hierarchy collapses.

---

## 2. Typography

Four typefaces. Each has a clearly defined role. Do not mix roles.

### Typeface Stack

| Typeface | Role | Weights used |
|---|---|---|
| **Fredoka** | Display / Headings / App title | 400, 500, 600, 700 |
| **Baloo 2** | Body text / Buttons / Hindi (Devanagari) | 400, 500, 600, 700, 800 |
| **Kalam** | Ella's voice / Handwritten annotations / Hindi-compatible | 400, 700 |
| **Inconsolata** | Eyebrows / Spec labels / Monospace metadata | 400, 700 |

**Critical note — Hindi support:** Baloo 2 is the only typeface in the stack with quality Devanagari support on Google Fonts. It must always be present in font stacks for any surface that may display Hindi text. Kalam also supports Hindi script and is used specifically for Ella's handwritten voice. Caveat was considered and rejected — it has no Devanagari support.

---

### Type Scale

Base: **16px**. All sizes are absolute px, not relative units, to ensure consistent rendering across budget Android devices.

| Role | Size | Typeface | Weight | Line Height | Usage |
|---|---|---|---|---|---|
| Display XL | 64px | Fredoka | 700 | 1.05 | Splash screens, celebration full-screen moments |
| Display L | 56px | Fredoka | 700 | 1.08 | Hero section titles, level-up screens |
| Display M | 42px | Fredoka | 600 | 1.1 | Screen titles, section hero headings |
| Display S | 32px | Fredoka | 600 | 1.15 | Card titles, modal headings |
| Title | 24px | Fredoka | 600 | 1.2 | Sub-section titles, card headers |
| Heading | 20px | Baloo 2 | 800 | 1.3 | Navigation labels, bold UI headings |
| Body Large | 16px | Baloo 2 | 600 | 1.5 | Primary body text, button labels, chip labels |
| Body | 14px | Baloo 2 | 500 | 1.5 | Secondary body text, supporting copy |
| Caption | 12px | Baloo 2 | 600 | 1.4 | Badge labels, metadata, timestamps |

**Ella's voice — Kalam**

| Role | Size | Typeface | Weight | Line Height | Usage |
|---|---|---|---|---|---|
| Ella voice large | 22px | Kalam | 700 | 1.4 | Speech bubble main text, prominent annotations |
| Ella voice | 17px | Kalam | 400 | 1.5 | Inline hints, Hindi whisper-text, sidebar notes |

**Specs and labels — Inconsolata**

| Role | Size | Typeface | Weight | Usage |
|---|---|---|---|---|
| Eyebrow / label | 11px | Inconsolata | 700 | Section labels, pill metadata, CEFR spec labels |
| Monospace body | 13px | Inconsolata | 400 | Code snippets, token references in developer docs |

**Hindi text rules:** All Hindi text uses Baloo 2 at the same size as its English equivalent or one step smaller. Hindi headings use SemiBold 600. Hindi body uses Medium 500. Hindi text always appears with a visual separator (dashed border-top) when following English text in the same container, so the code-switching is legible and intentional.

---

## 3. Spacing Scale

Eight named spacing steps. All values are multiples of 4px. Use token names in implementation — never hardcode px values.

| Token | Value | Usage |
|---|---|---|
| `space-1` | 4px | Icon-to-label gaps, micro padding inside badges |
| `space-2` | 8px | Internal chip padding (vertical), tight stacks |
| `space-3` | 12px | Internal chip padding (horizontal), small card padding |
| `space-4` | 16px | Standard internal padding for cards and bubbles, list item gaps |
| `space-5` | 20px | Section sub-heading margins, comfortable padding |
| `space-6` | 24px | Card padding (standard), modal internal padding |
| `space-8` | 32px | Section gaps, margin above major headings |
| `space-12` | 48px | Screen-level section separation, bottom nav clearance |

Gaps between cards in a grid: 16px. Screen horizontal gutters: 16px on mobile, 24px on tablet. Safe area from bottom of content to bottom nav: 48px minimum.

---

## 4. Border Radius Scale

Five named radius values. Pill geometry is the dominant shape language — only structural and very small elements use small radii.

| Token | Value | Usage |
|---|---|---|
| `radius-sharp` | 0px | Never used on interactive elements. Structural dividers only. |
| `radius-badge` | 8px | Small status badges, CEFR level pills |
| `radius-card` | 20px | All cards, modals, speech bubbles, avatar containers |
| `radius-button` | 24px | All buttons — primary, secondary, ghost, small |
| `radius-chip` | 20px | All chips — scaffold, topic, selected states |
| `radius-full` | 9999px | Pill shapes, mic button circle, avatar ring |

**Shape B — Diagonal corner pair (locked decision):** The system-wide button geometry uses paired diagonal corners: `border-radius: 4px 20px 4px 20px` for primary/CTA buttons. Ghost/secondary buttons paired opposite: `border-radius: 20px 4px 20px 4px`. This creates intentional visual opposition in paired layouts. This is a locked decision — do not normalise buttons to uniform radius.

---

## 5. Shadow System

Three shadow types. Each has a defined context.

| Token | Value | Context |
|---|---|---|
| `shadow-stamp` | `3px 3px 0 var(--ink)` | Primary CTA buttons — default/idle state |
| `shadow-stamp-hover` | `4px 4px 0 var(--ink)` | Primary CTA buttons — hover/focus state |
| `shadow-stamp-active` | `1px 1px 0 var(--ink)` | Primary CTA buttons — pressed state |
| `shadow-soft` | `0 4px 16px rgba(0,0,0,0.08)` | Floating modals, toasts, overlay cards |
| `shadow-card` | `0 2px 8px rgba(0,0,0,0.06)` | Content cards on white/surface backgrounds |

**Press-depth mechanic:** When a primary button is pressed, the shadow collapses from 3px to 1px AND the button translates `translateY(4px)` simultaneously. This creates the illusion of physical depth. Transition duration: 120ms ease. The shadow offset and the translate must always change together — one without the other breaks the tactile illusion.

The stamp shadow uses `var(--ink)` exclusively. Using any brand colour for a button shadow is not permitted — it breaks the visual hierarchy rule that Ink signals "the most important action."

---

## 6. Screen Backgrounds

Each major screen context has a unique background treatment. All are CSS-generated — zero image assets. Texture opacity is 3–5% to remain visible but non-intrusive.

| Screen | Token | Base colour | Texture description |
|---|---|---|---|
| Home | `bg-home` | `#FFFDF8` | Multi-colour confetti dots (Mango, Sky, Lime) at irregular grid spacing |
| Conversation / Lesson | `bg-conversation` | `#EFF7FF` | Horizontal ruled lines in Sky at 5% opacity, 28px spacing — mimics a notepad |
| Summary | `bg-summary` | `#F5FBE8` | Lime + Mango confetti dots at smaller scale |
| Interests | `bg-interests` | `#FFF0F3` | 45° diagonal hatching in Rose at 3% opacity |

The conversation background's ruled-line texture is intentional and meaningful — it signals "we are in learning mode" and references the notebook/study context without being literal.

---

## 7. Components

All component descriptions below are implementation instructions. No code is included — implementation is in Flutter.

---

### 7.1 Primary Button (CTA)

The primary button is the most important interactive element in the system. Every screen should have at most one primary button visible at a time.

**Anatomy:** Full-width or fixed-width pill with diagonal corner pair. Icon optional (leading). Label in Baloo 2 Bold 16px. Hard Ink border 2.5px. Stamp shadow with press-depth mechanic.

**Default colour:** Mango-main fill, white label. Variants available in all five brand colours — use the brand colour appropriate to the screen context (e.g. Sky on an Ella-led screen, Lime on a completion screen).

**Sizes:** Large (padding 12px 28px, font 15px) is the default. Small (padding 8px 18px, font 12px) for inline or secondary-context CTAs.

**States:** Idle → shadow at 3px offset. Hover/focus → shadow grows to 4px, button lifts 1px. Pressed → shadow collapses to 1px, button drops 4px. Disabled → 40% opacity, no shadow, no press mechanic.

**Corner shape:** `border-radius: 4px 20px 4px 20px` — top-left and bottom-right are sharp (4px), top-right and bottom-left are rounded (20px). This diagonal pair is the system-wide CTA signature.

---

### 7.2 Secondary Button

Used for secondary actions that share a screen with a primary CTA. Never more prominent than the primary.

**Anatomy:** Same pill geometry as primary. White fill. Neutral-border stroke 2px. Neutral-primary label. No stamp shadow.

**Hover state:** Border upgrades to Mango-main. Label upgrades to Mango-dark. Background upgrades to Mango-lightest.

**Corner shape:** `border-radius: 20px 4px 20px 4px` — the opposite diagonal to the primary button. When a primary and secondary button appear together (e.g. "Start" / "Not now"), the opposing diagonals create visual tension and hierarchy without size difference.

---

### 7.3 Ghost Button

Used for tertiary actions — links within lessons, "skip" options, low-priority choices.

**Anatomy:** Transparent fill. Mango-main border 2px. Mango-dark label. Pill radius same as primary.

**Hover state:** Mango-lightest background fills in. No shadow at any state.

---

### 7.4 Mic Button

The single most important button in the app. Always visible on conversation/lesson screens.

**Anatomy:** Perfect circle, 64px diameter. Mango-main fill. Ink border 2.5px. Stamp shadow (same mechanic as primary CTA). Microphone icon centred, 26px, white. No label.

**States:** Idle → standard stamp shadow. Listening (recording) → animated pulse ring expands outward from the circle edge (see Avatar Pulse Ring for the ring mechanic). Pressed → press-depth shadow collapse same as primary CTA. Disabled → 40% opacity.

**Placement rule:** The mic button must always be the most visually prominent element on any screen where it appears. It is never grouped with equal-weight buttons. Minimum clear space around mic button: 16px on all sides.

---

### 7.5 Scaffold Chips (Sentence Starters)

Sentence-starter chips are permanent scaffolding — they do not disappear as learners advance. Their content and complexity adapts by CEFR level, but they are always present. They function as speaking prompts, not crutches to be removed.

**Anatomy:** Full pill shape (radius-chip 20px). Baloo 2 Bold 14px label. Optional leading emoji icon. Two-level shadow: border + 2px bottom shadow in the border colour.

**Default / unselected:** White fill. Neutral-border stroke. Neutral-primary text. Bottom shadow in Neutral-border.

**Hover:** Border upgrades to Sky-main. Text upgrades to Sky-dark. Bottom shadow upgrades to Sky-main.

**Selected states (per context colour):**
- Mango selected: Mango-lightest fill, Mango-dark text, Mango-main border + shadow
- Sky selected: Sky-lightest fill, Sky-dark text, Sky-main border + shadow
- Lime selected: Lime-lightest fill, Lime-dark text, Lime-main border + shadow
- Rose selected: Rose-lightest fill, Rose-dark text, Rose-main border + shadow

**Chip rows:** Chips wrap horizontally and scroll if they overflow a single row. Never truncate chip text — chips are short by design (max 4–5 words).

---

### 7.6 Topic Chips (Category Tags)

Used for topic/interest selection and for content category labelling. Always filled, always with stamp shadow.

**Anatomy:** Same pill shape as scaffold chips. Solid brand-colour fill. White label. Ink border 2px. Hard stamp shadow 2px 2px at Ink — no Ink border reservation rule exception needed here, as these are topic labels not primary CTAs.

**Variants:** Mango, Sky, Lime, Rose, Grape fills — one per topic category. The colour assignment is consistent across sessions.

---

### 7.7 Ella Speech Bubble

Ella's utterances are displayed in a speech bubble that visually distinguishes her voice from the student's.

**Anatomy:** Sky-lightest fill. Sky-light border 2px. Unique corner: top-left is sharp (4px), all other corners are rounded (18px) — this creates the "tail" direction pointing to Ella's avatar. Maximum width 85% of screen width.

**Content structure:** Ella's English text in Baloo 2 SemiBold 14px, Sky-deepest colour. When a Hindi translation or scaffold is present, it appears below the English text separated by a dashed Sky-light horizontal rule. Hindi text in Baloo 2 Medium 13px, Sky-dark colour.

**Kalam annotations:** If Ella is adding a correction, encouragement, or aside, this text appears in Kalam 17px at Sky-dark. It should be clearly visually distinct from the main bubble text — slightly smaller, different typeface.

---

### 7.8 User Speech Bubble

The student's spoken responses appear as bubbles on the right side of the conversation.

**Anatomy:** Mango-main fill. Ink border 2px. Hard stamp shadow 2px 2px at Ink. Unique corner: top-right is sharp (4px), all other corners are rounded (18px) — mirrored from Ella's bubble. Text in Baloo 2 SemiBold 14px, white.

**Positioning:** Always aligned to the right edge of the conversation container. Ella's bubbles are left-aligned. They should never overlap.

**Transcript display:** The student never types — they speak. The bubble displays the speech-to-text transcript of what they said. This text is displayed as-is, including any hesitations or corrections Ella may annotate. Do not auto-correct the transcript — accurate reflection builds self-awareness.

---

### 7.9 Challenge Card

Challenge cards are the primary milestone mechanism. They appear when a real-life speaking challenge is unlocked.

**Anatomy:** Rounded card, radius-card 20px. Brand-colour fill appropriate to the challenge category (Sky for academic challenges, Rose for interests-based challenges, Mango for speaking output challenges). Ink border 2.5px. Full stamp shadow 3px 3px at Ink.

**Content structure (top to bottom):**
- Eyebrow label: Inconsolata 11px uppercase, at ~70% opacity of the on-colour text — e.g. "Challenge · Level 2"
- Title: Fredoka SemiBold 24px, on-colour white
- Description: Baloo 2 Medium 14px, on-colour at 80% opacity
- Action button: Small CTA in contrasting colour at the bottom

**States:** Locked → card is desaturated to neutral tones, lock icon visible, interaction disabled. Unlocked/available → full colour, full shadow, tap to open. Active/in-progress → a Lime-main progress indicator bar appears at the base of the card. Completed → success check badge at top-right, slight desaturation of the main fill.

**Phrase items within a challenge:** When a challenge card expands to show practice phrases, each phrase item sits on either a Neutral-surface (#FFF7EC) or white background — use Neutral-surface for better separation from the outer card background. This is an open decision to be tested in prototype.

---

### 7.10 Ella Avatar + Pulse Ring

The Ella avatar is the persistent identity of the AI tutor. It appears in the conversation header and in the lesson screen.

**Anatomy:** Circular avatar image container. Ink border ring 2.5px — this is one of the two reserved uses of Ink. Avatar diameter: 48px in conversation header, 80px in lesson screen hero.

**Pulse ring:** An animated ring that pulses outward from the avatar border when Ella is speaking or the app is processing speech. The ring uses Sky-main colour at decreasing opacity as it expands. Three rings animate sequentially with a 200ms stagger. Each ring starts at the avatar diameter and expands to 1.5× the avatar diameter while fading from 60% to 0% opacity over 800ms. The animation loops while the speaking state is active.

**Status badge:** A small circular badge at the bottom-right of the avatar indicates state — Sky for "listening", Mango for "student speaking", Lime for "success/complete". The badge is 16px diameter with a white border 2px. Whether the badge is needed at small (48px) sizes or whether the pulse ring alone is sufficient is an open question for prototype testing.

---

### 7.11 Level / CEFR Badges

CEFR level codes (A1, A2, B1, B2, C1) are never shown to students. The student-facing level names and their brand-colour pairings are:

| Internal CEFR | Student label | Brand colour |
|---|---|---|
| A1 | First Words | Sky |
| A2 | Finding My Voice | Mango |
| B1 | Speaking Freely | Lime |
| B2 | Almost Fluent | Rose |
| C1 | Fluent | Grape |

**Badge anatomy:** Pill shape, radius-badge 8px. Level name in Fredoka SemiBold 14px. `lightest` fill from the level colour, `deepest` text, `light` border 2px.

---

### 7.12 Progress Bar

**Anatomy:** Full-width track, 10px height, radius-full pill. Neutral-border fill for the track. Gradient fill for the progress: left-anchor Lime-main transitioning to Mango-main. Track has a subtle inner border: 1.5px at rgba(0,0,0,0.06).

**Animation:** Width transition on value change: 400ms ease. No bounce, no spring — smooth and continuous. Never display exact percentages to students — the bar is sufficient. Percentages may appear in teacher-facing dashboards.

---

### 7.13 Path Cards (Navigation)

Path cards appear on the home screen and route students to their three content paths.

**Anatomy:** Rounded card, radius-card 20px. Solid brand-colour fill (Mango, Sky, Lime, or Rose depending on path). Ink border 2.5px. Stamp shadow 3px 3px at Ink. Minimum height 120px.

**Content structure:** Large emoji or icon at top (36px). Path title in Fredoka SemiBold 20px, white. Short descriptor in Baloo 2 SemiBold 12px, white at 75% opacity. Optional progress indicator at the bottom edge of the card.

**Tap state:** Shadow collapses to 1px + translateY(4px) on press (same press-depth mechanic as all CTA elements).

---

### 7.14 Input Transcript Line

The real-time display of what the student is saying as they speak — before the bubble is committed.

**Anatomy:** Appears in the conversation screen, above the mic button, full-width. Background: Sky-lightest. Left border accent: 3px Mango-main (signals that this is the student's live input). Text: Baloo 2 Medium 16px, Neutral-secondary, with a blinking cursor at the live insertion point.

**Behaviour:** Appears the moment recording begins. Fades out and collapses to the committed user bubble on recording end. If nothing was said, it disappears with no bubble committed (zero-state is not possible — but silence produces no summary output).

---

### 7.15 Session Summary Screen

Shown after a completed session, only if the student produced speech output during the session. If the student did not speak, no summary screen is shown.

**Anatomy:** Full-screen, bg-summary background with Lime + Mango confetti texture. Header: Ella avatar (large, 80px) + congratulatory Kalam annotation. Content: one to three progress highlights shown as Lime-tinted stat cards. Footer: two buttons — primary CTA ("Keep going" or "Try a Challenge") and a ghost button ("I'm done for now").

**No gamification manipulation:** The summary screen shows only genuine progress data. It does not show streaks, daily targets, or retention-pressure messaging. It may show a challenge unlock if one was earned.

---

## 8. Colour-Role Reference (Quick Lookup)

| UI context | Colour to use | Notes |
|---|---|---|
| Primary CTA | Mango-main | Always with Ink border + stamp shadow |
| Mic button | Mango-main | Circle, Ink border, stamp shadow |
| User speech bubble | Mango-main | Ink border, stamp shadow |
| Ella speech bubble | Sky-lightest fill + Sky-light border | Kalam for annotations |
| Conversation screen background | bg-conversation | Ruled-line texture |
| Academic content cards | Sky family | |
| Topic/interest selection | Rose family | |
| Rewards, streaks, progress | Lime family | |
| Rare rewards, bonus moments | Grape family | |
| Level-up screens | Lime-main + Mango-main | Gradient |
| Correct answer / completion | Success family | Not Lime-main |
| Network error, speech unrecognised | Error family | Not Rose-main |
| Time limits, moderation | Warning family | Not Mango-main |
| Structural borders, card strokes | Neutral-border | |
| Body text | Neutral-primary | Warm dark brown, not pure black |
| Ink (border + shadow) | ONLY: primary CTA + avatar ring | No other use |

---

## 9. Accessibility and Platform Notes

**Minimum touch target:** 44×44px on all interactive elements. This applies even if the visible element is smaller — add invisible hit area padding as needed.

**Minimum font size:** 12px. Nothing smaller, even in metadata or badge labels.

**Contrast:** On Mango-main backgrounds (buttons, user bubbles), white text satisfies WCAG AA contrast. On Sky-main, white text satisfies AA. On Lime-main, white text satisfies AA. Always verify on-main text colours when adding new coloured surfaces.

**Android low-DPI consideration:** The design is validated on 360px-wide screens at 1x DPI (the common budget Android baseline). Full-saturation colours are required for this environment — do not introduce muted or desaturated variants without testing on physical low-DPI devices.

**Font loading:** All four typefaces are Google Fonts. Baloo 2 is the heaviest file due to Devanagari glyph count — use `font-display: swap` and consider subsetting to Latin + Devanagari ranges only to reduce load time.

**Single-hand use:** The mic button must always be reachable with a thumb in single-hand hold. Bottom-centre of the screen is the required placement for the mic on all conversation screens.

---

## 10. What Not To Do

These are explicit prohibitions, not suggestions:

- Do not use Rose, Lime, or Grape for success/error/warning states — they are brand colours with fixed semantic roles.
- Do not use Ink on any element except the primary CTA button and the avatar border ring.
- Do not remove Baloo 2 from any screen that may display Hindi text.
- Do not use Caveat for any text in this version — Caveat was removed from v3.0 due to missing Devanagari support. Kalam replaces it.
- Do not show CEFR codes (A1–C1) on any student-facing surface.
- Do not add a session summary screen when the student did not speak.
- Do not normalise button corners to uniform radius — the diagonal corner pair is a locked design decision.
- Do not swap Mango and Sky between the user channel and Ella's channel.
- Do not use the progress bar to show exact percentages to students.

---

*Ella Design System v3.0 · NavGurukul · April 2026*
*Contact: Narendra (Product Design)*
